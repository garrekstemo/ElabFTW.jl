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
end
