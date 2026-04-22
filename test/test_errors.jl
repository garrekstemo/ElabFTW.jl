@testset "HTTP layer hardening" begin
    saved_retries = ElabFTW._elabftw_config.max_retries
    saved_delay = ElabFTW._elabftw_config.retry_base_delay

    try
        # Tight timing for tests — not production defaults.
        ElabFTW._elabftw_config.max_retries = 2
        ElabFTW._elabftw_config.retry_base_delay = 0.01

        @testset "Typed HTTP errors" begin
            # NotFoundError: GET a nonexistent entity.
            @test_throws NotFoundError get_experiment(999999)

            # ElabFTWError supertype catches everything.
            try
                get_experiment(999999)
                @test false  # unreachable
            catch e
                @test e isa ElabFTWError
                @test e isa HTTPError
                @test e.url isa String
                @test occursin("999999", e.url)
            end
        end

        @testset "ParseError on bad Location" begin
            resp = HTTP.Response(201, "")
            push!(resp.headers, "Location" => "/api/v2/items/not-a-number")
            @test_throws ParseError ElabFTW._parse_id_from_response(resp)
        end

        @testset "_http_error mapping" begin
            @test ElabFTW._http_error(401, "u") isa AuthError
            @test ElabFTW._http_error(403, "u") isa PermissionError
            @test ElabFTW._http_error(404, "u") isa NotFoundError
            @test ElabFTW._http_error(429, "u") isa RateLimitError
            @test ElabFTW._http_error(422, "u", "body") isa ClientError
            @test ElabFTW._http_error(503, "u", "oops") isa ServerError
        end

        @testset "Retry on 5xx succeeds after retries" begin
            id = create_experiment(title="retry-5xx-target")

            # Next 2 GETs fail with 503, then a real GET succeeds.
            queue_failure!(mock.state, "/api/v2/experiments/$id", 503)
            queue_failure!(mock.state, "/api/v2/experiments/$id", 503)

            exp = get_experiment(id)
            @test exp["id"] == id
            @test isempty(mock.state.inject_failures)

            delete_experiment(id)
        end

        @testset "Retry exhausted surfaces ServerError" begin
            id = create_experiment(title="retry-exhausted")
            for _ in 1:(ElabFTW._elabftw_config.max_retries + 1)
                queue_failure!(mock.state, "/api/v2/experiments/$id", 500)
            end
            @test_throws ServerError get_experiment(id)
            # All injections consumed by the retry loop.
            @test isempty(mock.state.inject_failures)
            delete_experiment(id)
        end

        @testset "Retry on 429 honors Retry-After" begin
            id = create_experiment(title="retry-429")
            queue_failure!(mock.state, "/api/v2/experiments/$id", 429; retry_after=0)

            t0 = time()
            exp = get_experiment(id)
            elapsed = time() - t0

            @test exp["id"] == id
            @test elapsed < 1.0  # retry_after=0 → no artificial delay
            delete_experiment(id)
        end

        @testset "RateLimitError after exhaustion carries Retry-After" begin
            id = create_experiment(title="429-exhausted")
            for _ in 1:(ElabFTW._elabftw_config.max_retries + 1)
                queue_failure!(mock.state, "/api/v2/experiments/$id", 429; retry_after=0)
            end
            try
                get_experiment(id)
                @test false  # unreachable
            catch e
                @test e isa RateLimitError
                @test e.retry_after == 0
            end
            delete_experiment(id)
        end

        @testset "4xx errors do not retry" begin
            id = create_experiment(title="no-retry-4xx")
            # Two 422s queued; only the first call should consume one.
            queue_failure!(mock.state, "/api/v2/experiments/$id", 422)
            queue_failure!(mock.state, "/api/v2/experiments/$id", 422)
            @test_throws ClientError get_experiment(id)
            @test length(mock.state.inject_failures) == 1
            empty!(mock.state.inject_failures)
            delete_experiment(id)
        end

        @testset "elabftw_http escape hatch exposes headers" begin
            resp = elabftw_http("POST", "/api/v2/experiments";
                                body=Dict("title" => "escape-hatch"))
            @test resp.status == 201
            loc = HTTP.header(resp, "Location")
            @test !isempty(loc)
            new_id = parse(Int, last(split(loc, "/")))

            resp2 = elabftw_http("GET", "/api/v2/experiments/$new_id")
            @test resp2.status == 200
            body = JSON.parse(String(resp2.body))
            @test body["title"] == "escape-hatch"

            resp3 = elabftw_http("PATCH", "/api/v2/experiments/$new_id";
                                 body=Dict("title" => "updated"))
            @test resp3.status == 200

            resp4 = elabftw_http("DELETE", "/api/v2/experiments/$new_id")
            @test resp4.status in (200, 204)

            @test_throws ArgumentError elabftw_http("OPTIONS", "/api/v2/info")
        end

        @testset "elabftw_http query encoding" begin
            resp = elabftw_http("GET", "/api/v2/experiments";
                                query=Dict("limit" => 5, "offset" => 0))
            @test resp.status == 200
        end
    finally
        ElabFTW._elabftw_config.max_retries = saved_retries
        ElabFTW._elabftw_config.retry_base_delay = saved_delay
        empty!(mock.state.inject_failures)
    end
end
