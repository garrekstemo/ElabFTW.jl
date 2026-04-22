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
