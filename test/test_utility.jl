@testset "Utility" begin
    @testset "instance_info" begin
        info = instance_info()
        @test info isa AbstractDict
        @test haskey(info, "elabftw_version")
        @test info["elabftw_version"] == "5.0.0-mock"
    end

    @testset "test_connection" begin
        @test test_connection() === nothing
    end

    @testset "Favorite tags" begin
        favs = list_favorite_tags()
        @test favs isa Vector
        initial_count = length(favs)

        add_favorite_tag("alpha")
        favs = list_favorite_tags()
        @test length(favs) == initial_count + 1
        entry = only(filter(t -> t["tag"] == "alpha", favs))
        @test haskey(entry, "tags_id")

        remove_favorite_tag(entry["tags_id"])
        favs = list_favorite_tags()
        @test length(favs) == initial_count
        @test !any(t -> t["tag"] == "alpha", favs)
    end

    @testset "download_*_upload caches bytes" begin
        item_id = create_item(title="cache-dl-probe")
        tmpfile = tempname() * ".txt"
        write(tmpfile, "payload-bytes-xyz")
        upload_id = upload_to_item(item_id, tmpfile; comment="probe")

        # First call downloads. The mock serves the bytes we uploaded — so
        # the cached file must equal what we wrote.
        path1 = download_item_upload(item_id, upload_id; filename="probe.txt")
        @test read(path1, String) == "payload-bytes-xyz"

        # Cache hit: if the function skips the HTTP round-trip, a queued 503
        # on the upload URL shouldn't be consumed. After the second call the
        # failure should still be queued.
        queue_failure!(mock.state, "/api/v2/items/$item_id/uploads/$upload_id", 503)
        path2 = download_item_upload(item_id, upload_id; filename="probe.txt")
        @test path1 == path2
        @test !isempty(mock.state.inject_failures)
        empty!(mock.state.inject_failures)

        # Legacy alias
        path3 = download_elabftw_file(item_id, upload_id; filename="probe.txt")
        @test path3 == path1

        # Experiments branch serves its own bytes
        exp_id = create_experiment(title="cache-exp-probe")
        write(tmpfile, "experiment-payload")
        e_upload = upload_to_experiment(exp_id, tmpfile)
        p_exp = download_experiment_upload(exp_id, e_upload; filename="exp.txt")
        @test read(p_exp, String) == "experiment-payload"

        # Cache info reflects actual cached files
        info = elabftw_cache_info()
        @test info.files >= 2
        @test info.size_mb >= 0

        clear_elabftw_cache()
        info = elabftw_cache_info()
        @test info.files == 0
        # Cleared directory was recreated
        @test isdir(ElabFTW._elabftw_config.cache_dir)

        rm(tmpfile; force=true)
        delete_experiment(exp_id)
        delete_item(item_id)
    end

    @testset "create_export / download_export" begin
        id = create_experiment(title="export-probe")
        bytes = create_export(:experiments, id)
        @test bytes isa AbstractVector{UInt8}
        # Mock serves literal "mock export data". If the function ever mangled
        # the body (e.g. decoded as JSON, stringified the response object),
        # this byte-identity check would catch it.
        # NOTE: `String(bytes)` takes ownership and empties the Vector{UInt8}
        # in Julia — read the expected bytes from a snapshot so subsequent
        # assertions still see content.
        expected = copy(bytes)
        @test String(bytes) == "mock export data"

        tmp = tempname()
        returned = download_export(:experiments, id, tmp)
        @test returned == tmp
        @test read(tmp) == expected
        rm(tmp; force=true)

        delete_experiment(id)
    end

    @testset "import_file" begin
        tmpfile = tempname() * ".eln"
        write(tmpfile, "fake eln payload")
        id = import_file(tmpfile)
        @test id isa Int

        # Bad path → ArgumentError before any HTTP call
        @test_throws ArgumentError import_file("/nonexistent/path.eln")

        rm(tmpfile; force=true)
        delete_experiment(id)
    end

    @testset "search_extra_fields_keys" begin
        # Seed the mock state directly — the server auto-populates this from
        # real entity metadata, which the mock doesn't track.
        push!(mock.state.extra_fields_keys,
            Dict{String, Any}("extra_fields_key" => "concentration", "frequency" => 7))
        push!(mock.state.extra_fields_keys,
            Dict{String, Any}("extra_fields_key" => "temperature", "frequency" => 3))

        all_keys = search_extra_fields_keys()
        @test length(all_keys) >= 2

        filtered = search_extra_fields_keys(q="temp")
        @test length(filtered) == 1
        @test filtered[1]["extra_fields_key"] == "temperature"

        @test isempty(search_extra_fields_keys(q="xyz-no-match"))

        empty!(mock.state.extra_fields_keys)
    end
end
