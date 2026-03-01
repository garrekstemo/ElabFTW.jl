@testset "print_experiments" begin
    buf = IOBuffer()
    print_experiments(Dict[]; io=buf)
    @test occursin("No experiments", String(take!(buf)))

    experiments = [
        Dict("id" => 42, "title" => "Test experiment",
             "date" => "2026-02-09T12:00:00",
             "tags" => [Dict("tag" => "ftir")])
    ]
    buf = IOBuffer()
    print_experiments(experiments; io=buf)
    output = String(take!(buf))
    @test occursin("42", output)
    @test occursin("Test experiment", output)
    @test occursin("ftir", output)
end

@testset "print_items" begin
    buf = IOBuffer()
    print_items(Dict[]; io=buf)
    @test occursin("No items", String(take!(buf)))

    items = [
        Dict("id" => 7, "title" => "MoS2 sample A",
             "category_title" => "Sample",
             "tags" => [Dict("tag" => "mos2"), Dict("tag" => "tmdc")])
    ]
    buf = IOBuffer()
    print_items(items; io=buf)
    output = String(take!(buf))
    @test occursin("7", output)
    @test occursin("MoS2 sample A", output)
    @test occursin("Sample", output)
    @test occursin("mos2", output)
    @test occursin("tmdc", output)
end

@testset "print_tags" begin
    buf = IOBuffer()
    print_tags(Any[]; io=buf)
    @test occursin("No tags", String(take!(buf)))

    entity_tags = [
        Dict("tag" => "ftir", "tag_id" => 7, "is_favorite" => 0),
        Dict("tag" => "nh4scn", "tag_id" => 12, "is_favorite" => 0),
    ]
    buf = IOBuffer()
    print_tags(entity_tags; io=buf)
    output = String(take!(buf))
    @test occursin("7", output)
    @test occursin("ftir", output)
    @test occursin("nh4scn", output)

    team_tags = [
        Dict("id" => 3, "tag" => "raman", "item_count" => 5, "is_favorite" => 0, "team" => 1),
    ]
    buf = IOBuffer()
    print_tags(team_tags; io=buf)
    output = String(take!(buf))
    @test occursin("raman", output)
    @test occursin("5", output)
end
