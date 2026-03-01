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

        add_favorite_tag(99)
        favs = list_favorite_tags()
        @test length(favs) == initial_count + 1
        @test any(t -> t["id"] == 99, favs)

        remove_favorite_tag(99)
        favs = list_favorite_tags()
        @test length(favs) == initial_count
        @test !any(t -> t["id"] == 99, favs)
    end
end
