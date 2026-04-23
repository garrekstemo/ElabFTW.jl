@testset "Batch operations" begin
    @testset "Input validation" begin
        @test_throws ArgumentError delete_experiments()
        @test_throws ArgumentError tag_experiments("tag")
        @test_throws ArgumentError update_experiments(new_body="test")
        @test_throws ArgumentError delete_items()
        @test_throws ArgumentError tag_items("tag")
        @test_throws ArgumentError update_items(new_body="test")
        @test_throws ArgumentError update_experiments(query="q")  # no body specified
        @test_throws ArgumentError update_items(query="q")
        # Vector overloads enforce the same guards
        @test_throws ArgumentError tag_experiments(["a", "b"])
        @test_throws ArgumentError tag_items(["a", "b"])
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

        # Also the items side + delete/update with no matches
        @test isempty(delete_items(query="zzz-nonexistent-zzz"; dry_run=true))
        @test isempty(tag_items("tag"; query="zzz-nonexistent-zzz"))
        @test isempty(update_experiments(query="zzz-nonexistent-zzz"; new_body="x"))
        @test isempty(update_items(query="zzz-nonexistent-zzz"; new_body="x"))
    end

    @testset "dry_run=false actually deletes" begin
        id = create_experiment(title="real-delete-exp")
        ids = delete_experiments(query="real-delete-exp"; dry_run=false)
        @test id in ids
        @test_throws NotFoundError get_experiment(id)

        iid = create_item(title="real-delete-item")
        ids = delete_items(query="real-delete-item"; dry_run=false)
        @test iid in ids
        @test_throws NotFoundError get_item(iid)
    end

    @testset "append_body path" begin
        id = create_experiment(title="append-exp", body="start")
        update_experiments(query="append-exp"; append_body=" + more")
        @test get_experiment(id)["body"] == "start + more"
        delete_experiment(id)

        iid = create_item(title="append-item", body="orig")
        update_items(query="append-item"; append_body=" + extra")
        @test get_item(iid)["body"] == "orig + extra"
        delete_item(iid)
    end
end
