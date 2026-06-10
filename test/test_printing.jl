@testset "print_experiments" begin
    buf = IOBuffer()
    print_experiments(Dict[]; io=buf)
    @test occursin("No experiments", String(take!(buf)))

    # Real API shape: entity `tags` is a pipe-joined string (nullable).
    experiments = [
        Dict("id" => 42, "title" => "Test experiment",
             "date" => "2026-02-09T12:00:00",
             "tags" => "ftir|nh4scn")
    ]
    buf = IOBuffer()
    print_experiments(experiments; io=buf)
    output = String(take!(buf))
    @test occursin("42", output)
    @test occursin("Test experiment", output)
    @test occursin("ftir", output)
    @test occursin("nh4scn", output)

    # Fresh entities have tags = null (JSON.parse → nothing)
    experiments = [
        Dict("id" => 43, "title" => "Untagged experiment",
             "date" => "2026-02-09T12:00:00",
             "tags" => nothing)
    ]
    buf = IOBuffer()
    print_experiments(experiments; io=buf)
    output = String(take!(buf))
    @test occursin("Untagged experiment", output)

    # Tag-object arrays (e.g. from list_experiment_tags) still work
    experiments = [
        Dict("id" => 44, "title" => "Array-tagged",
             "date" => "2026-02-09T12:00:00",
             "tags" => [Dict("tag" => "vsc")])
    ]
    buf = IOBuffer()
    print_experiments(experiments; io=buf)
    @test occursin("vsc", String(take!(buf)))
end

@testset "print_items" begin
    buf = IOBuffer()
    print_items(Dict[]; io=buf)
    @test occursin("No items", String(take!(buf)))

    items = [
        Dict("id" => 7, "title" => "MoS2 sample A",
             "category_title" => "Sample",
             "tags" => "mos2|tmdc")
    ]
    buf = IOBuffer()
    print_items(items; io=buf)
    output = String(take!(buf))
    @test occursin("7", output)
    @test occursin("MoS2 sample A", output)
    @test occursin("Sample", output)
    @test occursin("mos2", output)
    @test occursin("tmdc", output)

    # Null tags (fresh item) must not crash
    items = [
        Dict("id" => 8, "title" => "Fresh item",
             "category_title" => "Sample",
             "tags" => nothing)
    ]
    buf = IOBuffer()
    print_items(items; io=buf)
    @test occursin("Fresh item", String(take!(buf)))
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
