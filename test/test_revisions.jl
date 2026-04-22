@testset "Revisions" begin
    @testset "List/get/restore on items" begin
        id = create_item(title="rev-target", body="v1")

        # No body change yet → no revisions captured.
        @test isempty(list_revisions(:items, id))

        # Two edits create two snapshots of the prior body.
        update_item(id; body="v2")
        update_item(id; body="v3 final")

        revs = list_revisions(:items, id)
        @test length(revs) == 2
        # List is id-desc — newest revision first.
        @test revs[1]["id"] > revs[2]["id"]
        @test haskey(revs[1], "created_at")
        @test haskey(revs[1], "fullname")
        # Summary view must not leak body text.
        @test !haskey(revs[1], "body")

        # Get full revision; newest captures the v2 state (what was
        # overwritten when we PATCHed to v3).
        newest = get_revision(:items, id, revs[1]["id"])
        @test newest["body"] == "v2"

        oldest = get_revision(:items, id, revs[2]["id"])
        @test oldest["body"] == "v1"

        # Restore the oldest — item body returns to v1.
        result = restore_revision(:items, id, revs[2]["id"])
        @test result["body"] == "v1"
        @test get_item(id)["body"] == "v1"

        # Restore does not create a new revision.
        @test length(list_revisions(:items, id)) == 2

        delete_item(id)
    end

    @testset "Revisions on experiments" begin
        id = create_experiment(title="rev-exp", body="exp v1")
        update_experiment(id; body="exp v2")

        revs = list_revisions(:experiments, id)
        @test length(revs) == 1

        rev = get_revision(:experiments, id, revs[1]["id"])
        @test rev["body"] == "exp v1"

        restore_revision(:experiments, id, revs[1]["id"])
        @test get_experiment(id)["body"] == "exp v1"

        delete_experiment(id)
    end

    @testset "Error paths" begin
        id = create_item(title="rev-errors", body="original")

        # Unknown revision id on an existing entity → 404.
        @test_throws NotFoundError get_revision(:items, id, 999999)
        @test_throws NotFoundError restore_revision(:items, id, 999999)

        # Revisions on a nonexistent entity → 404.
        @test_throws NotFoundError list_revisions(:items, 999999)

        delete_item(id)
    end
end
