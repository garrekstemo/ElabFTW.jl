@testset "Batch operations" begin
    @testset "Input validation" begin
        @test_throws ErrorException delete_experiments()
        @test_throws ErrorException tag_experiments("tag")
        @test_throws ErrorException update_experiments(new_body="test")
        @test_throws ErrorException delete_items()
        @test_throws ErrorException tag_items("tag")
        @test_throws ErrorException update_items(new_body="test")
        @test_throws ErrorException update_experiments(query="q")  # no body specified
    end

    @testset "delete_experiments dry_run" begin
        id1 = create_experiment(title="batch-del-1")
        id2 = create_experiment(title="batch-del-2")

        ids = delete_experiments(query="batch-del"; dry_run=true)
        @test length(ids) >= 2
        @test id1 in ids
        @test id2 in ids

        # Experiments still exist after dry run
        @test get_experiment(id1)["title"] == "batch-del-1"
        @test get_experiment(id2)["title"] == "batch-del-2"

        # Clean up
        delete_experiment(id1)
        delete_experiment(id2)
    end

    @testset "tag_experiments" begin
        id = create_experiment(title="batch-tag-target")

        ids = tag_experiments("batch-added"; query="batch-tag")
        @test id in ids

        tags = list_tags(id)
        @test any(t -> t["tag"] == "batch-added", tags)

        # Vector form: add multiple tags to every match
        ids2 = tag_experiments(["multi-a", "multi-b"]; query="batch-tag")
        @test id in ids2
        tags = list_tags(id)
        @test any(t -> t["tag"] == "multi-a", tags)
        @test any(t -> t["tag"] == "multi-b", tags)

        # Empty vector is a no-op
        @test isempty(tag_experiments(String[]; query="batch-tag"))

        delete_experiment(id)
    end

    @testset "update_experiments with new_body" begin
        id = create_experiment(title="batch-update-target", body="original")

        ids = update_experiments(query="batch-update"; new_body="replaced")
        @test id in ids

        exp = get_experiment(id)
        @test exp["body"] == "replaced"

        delete_experiment(id)
    end

    @testset "delete_items dry_run" begin
        id = create_item(title="batch-del-item")

        ids = delete_items(query="batch-del-item"; dry_run=true)
        @test id in ids
        @test get_item(id)["title"] == "batch-del-item"

        delete_item(id)
    end

    @testset "tag_items" begin
        id = create_item(title="batch-tag-item")

        ids = tag_items("item-batch-tag"; query="batch-tag-item")
        @test id in ids

        tags = list_item_tags(id)
        @test any(t -> t["tag"] == "item-batch-tag", tags)

        # Vector form
        ids2 = tag_items(["multi-x", "multi-y"]; query="batch-tag-item")
        @test id in ids2
        tags = list_item_tags(id)
        @test any(t -> t["tag"] == "multi-x", tags)
        @test any(t -> t["tag"] == "multi-y", tags)

        delete_item(id)
    end

    @testset "update_items" begin
        id = create_item(title="batch-update-item", body="original")

        ids = update_items(query="batch-update-item"; new_body="new content")
        @test id in ids

        item = get_item(id)
        @test item["body"] == "new content"

        delete_item(id)
    end

    @testset "No matches" begin
        ids = delete_experiments(query="zzz-nonexistent-zzz"; dry_run=true)
        @test isempty(ids)

        ids = tag_experiments("tag"; query="zzz-nonexistent-zzz")
        @test isempty(ids)
    end
end
