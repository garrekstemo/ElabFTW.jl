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

    @testset "Category CRUD" begin
        for et in (:experiments, :items)
            id = create_category(et; title="jl-cat", color="aaaaaa", default=0)
            @test id isa Int

            cat = get_category(et, id)
            @test cat["title"] == "jl-cat"
            @test cat["color"] == "aaaaaa"

            updated = update_category(et, id; title="jl-cat-renamed", color="bbbbbb")
            @test updated["title"] == "jl-cat-renamed"
            @test updated["color"] == "bbbbbb"

            # DELETE soft-deletes — entry persists with state=3, not 404.
            delete_category(et, id)
            @test get_category(et, id)["state"] == 3
        end

        @test_throws ArgumentError update_category(:experiments, 1)
        @test_throws ArgumentError create_category(:bogus; title="x")
    end

    @testset "Status CRUD" begin
        for et in (:experiments, :items)
            @test list_status(et) isa Vector

            id = create_status(et; title="jl-status", color="123456", default=0)
            st = get_status(et, id)
            @test st["title"] == "jl-status"

            update_status(et, id; title="jl-status-2")
            @test get_status(et, id)["title"] == "jl-status-2"

            delete_status(et, id)
            @test get_status(et, id)["state"] == 3
        end
    end
end
