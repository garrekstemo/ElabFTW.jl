@testset "Team operations" begin
    @testset "Team tags" begin
        # Create an experiment and tag it so team tags get populated
        id = create_experiment(title="Team tag test")
        tag_experiment(id, "team-test-tag")

        tags = list_team_tags()
        @test tags isa Vector
        @test any(t -> t["tag"] == "team-test-tag", tags)

        # Find the tag and rename it
        tag_entry = first(filter(t -> t["tag"] == "team-test-tag", tags))
        rename_team_tag(tag_entry["id"], "renamed-tag")
        tags = list_team_tags()
        @test any(t -> t["tag"] == "renamed-tag", tags)

        # Delete team tag
        delete_team_tag(tag_entry["id"])
        tags = list_team_tags()
        @test !any(t -> t["id"] == tag_entry["id"], tags)

        delete_experiment(id)
    end

    @testset "Categories" begin
        exp_cats = list_experiments_categories()
        @test exp_cats isa Vector
        @test length(exp_cats) >= 1
        @test haskey(exp_cats[1], "title")

        item_cats = list_items_categories()
        @test item_cats isa Vector
        @test length(item_cats) >= 1
        @test haskey(item_cats[1], "title")
    end
end
