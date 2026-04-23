@testset "Experiments" begin
    @testset "CRUD" begin
        id = create_experiment(title="Test experiment", body="Markdown body")
        @test id isa Int
        @test id > 0

        exp = get_experiment(id)
        @test exp["title"] == "Test experiment"
        @test exp["id"] == id

        update_experiment(id; title="Updated title", body="New body")
        exp = get_experiment(id)
        @test exp["title"] == "Updated title"

        exps = list_experiments()
        @test exps isa Vector
        @test any(e -> e["id"] == id, exps)

        results = search_experiments(query="Updated")
        @test any(e -> e["id"] == id, results)

        dup_id = duplicate_experiment(id)
        @test dup_id isa Int
        @test dup_id != id
        dup = get_experiment(dup_id)
        @test dup["id"] == dup_id

        delete_experiment(id)
        @test_throws NotFoundError get_experiment(id)
        delete_experiment(dup_id)
    end

    @testset "create_from_template" begin
        tmpl_id = create_experiment_template(title="Test template", body="Template body")
        exp_id = create_from_template(tmpl_id; title="From template", tags=["tmpl-tag"])
        @test exp_id isa Int

        exp = get_experiment(exp_id)
        @test exp["title"] == "From template"

        tags = list_experiment_tags(exp_id)
        @test any(t -> t["tag"] == "tmpl-tag", tags)

        delete_experiment(exp_id)
        delete_experiment_template(tmpl_id)
    end

    @testset "Tags" begin
        id = create_experiment(title="Tag test")

        tag_experiment(id, "single-tag")
        tags = list_experiment_tags(id)
        @test length(tags) == 1
        @test tags[1]["tag"] == "single-tag"

        tag_experiment(id, ["batch-a", "batch-b"])
        tags = list_experiment_tags(id)
        @test length(tags) == 3

        tag_id = tags[1]["tag_id"]
        untag_experiment(id, tag_id)
        tags = list_experiment_tags(id)
        @test length(tags) == 2

        clear_experiment_tags(id)
        tags = list_experiment_tags(id)
        @test isempty(tags)

        delete_experiment(id)
    end

    @testset "Steps" begin
        id = create_experiment(title="Step test")

        s1 = add_step(id, "Load data")
        @test s1 isa Int
        s2 = add_step(id, "Fit model")

        steps = list_steps(id)
        @test length(steps) == 2
        @test steps[1]["body"] == "Load data"
        @test steps[1]["finished"] == false

        finish_step(id, s1)
        steps = list_steps(id)
        finished_step = first(filter(s -> s["id"] == s1, steps))
        @test finished_step["finished"] == true

        delete_step(id, s2)
        steps = list_steps(id)
        @test length(steps) == 1
        @test steps[1]["id"] == s1

        # update_step: plain fields
        update_step(id, s1; body="Rewritten", deadline="2026-05-01 12:00:00")
        step = first(filter(s -> s["id"] == s1, list_steps(id)))
        @test step["body"] == "Rewritten"
        @test step["deadline"] == "2026-05-01 12:00:00"

        # notif_step toggles once deadline is set
        notif_step(id, s1)
        @test first(filter(s -> s["id"] == s1, list_steps(id)))["deadline_notif"] == 1
        notif_step(id, s1)
        @test first(filter(s -> s["id"] == s1, list_steps(id)))["deadline_notif"] == 0

        # Argument validation
        @test_throws ArgumentError update_step(id, s1)
        @test_throws ArgumentError update_step(id, s1; is_immutable=99)

        delete_experiment(id)
    end

    @testset "Uploads" begin
        id = create_experiment(title="Upload test")
        tmpfile = tempname() * ".txt"
        write(tmpfile, "test content")

        try
            upload_id = upload_to_experiment(id, tmpfile; comment="test file")
            @test upload_id isa Int

            uploads = list_experiment_uploads(id)
            @test length(uploads) == 1

            # Rename via PATCH
            updated = update_experiment_upload(id, upload_id; real_name="renamed.txt")
            @test updated["real_name"] == "renamed.txt"

            # Archive (state=2) removes from default listing, visible with state=2
            update_experiment_upload(id, upload_id; state=2)
            @test isempty(list_experiment_uploads(id))
            @test length(list_experiment_uploads(id; state=2)) == 1
            @test length(list_experiment_uploads(id; state=[1, 2])) == 1

            # Restore, then replace with a new file
            update_experiment_upload(id, upload_id; state=1)
            new_id = replace_experiment_upload(id, upload_id, tmpfile; comment="v2")
            @test new_id != upload_id
            # Old is archived; new is active
            active = list_experiment_uploads(id)
            @test length(active) == 1
            @test active[1]["id"] == new_id
            @test length(list_experiment_uploads(id; state=2)) == 1

            # Argument validation
            @test_throws ArgumentError update_experiment_upload(id, new_id)
            @test_throws ArgumentError update_experiment_upload(id, new_id; state=99)

            delete_experiment_upload(id, new_id)
            # Archived original still exists — delete it too for cleanup
            delete_experiment_upload(id, upload_id)
            @test isempty(list_experiment_uploads(id; state=[1, 2, 3]))
        finally
            isfile(tmpfile) && rm(tmpfile)
        end

        delete_experiment(id)
    end

    @testset "Experiment-to-experiment links" begin
        id1 = create_experiment(title="Link source")
        id2 = create_experiment(title="Link target")

        link_experiments(id1, id2)
        links = list_experiment_links(id1)
        @test length(links) == 1
        @test links[1]["entityid"] == id2

        unlink_experiments(id1, id2)
        links = list_experiment_links(id1)
        @test isempty(links)

        delete_experiment(id1)
        delete_experiment(id2)
    end

    @testset "Metadata" begin
        meta = Dict("extra_field" => "value", "count" => 42)
        id = create_experiment(title="Meta test", metadata=meta)
        exp = get_experiment(id)
        @test !isnothing(exp["metadata"])

        update_experiment(id; metadata=Dict("updated" => true))
        exp = get_experiment(id)
        @test !isnothing(exp["metadata"])

        delete_experiment(id)
    end

    @testset "List filters" begin
        a = create_experiment(title="filter-a", category=101)
        b = create_experiment(title="filter-b", category=102)

        # cat filter (single)
        only_a = list_experiments(cat=101)
        @test any(e -> e["id"] == a, only_a)
        @test !any(e -> e["id"] == b, only_a)

        # cat filter (vector)
        both = list_experiments(cat=[101, 102])
        @test any(e -> e["id"] == a, both)
        @test any(e -> e["id"] == b, both)

        # search_experiments exposes the same filters
        res = search_experiments(query="filter", cat=102)
        @test any(e -> e["id"] == b, res)
        @test !any(e -> e["id"] == a, res)

        # state filter: mock entities default to state=1, so state=2 returns
        # empty (serializing the param as an int round-trips through the URL
        # builder and the mock's state branch).
        @test !any(e -> e["id"] in (a, b), list_experiments(state=2))
        # owner filter with a user id nobody owns
        @test !any(e -> e["id"] in (a, b), list_experiments(owner=[99999]))

        delete_experiment(a)
        delete_experiment(b)
    end

    @testset "update_experiment with no fields warns and does not hit HTTP" begin
        id = create_experiment(title="noop-update", body="keep me")
        # _update_entity's contract: warn when called without any field, and
        # skip the HTTP call entirely. We prove both by (a) asserting the
        # warn fires, (b) queueing a 503 on the PATCH URL and confirming the
        # call returns cleanly — if it had issued the PATCH, the retry layer
        # would have exhausted and raised ServerError.
        queue_failure!(mock.state, "/api/v2/experiments/$id", 503)
        @test_logs (:warn,) update_experiment(id)
        @test !isempty(mock.state.inject_failures)  # still queued → no request made
        empty!(mock.state.inject_failures)

        @test get_experiment(id)["body"] == "keep me"
        delete_experiment(id)
    end

    @testset "update_experiment forwards extra kwargs" begin
        id = create_experiment(title="kwargs-exp", body="b")
        update_experiment(id; rating=4, custom_id="FTIR-042", date="2026-04-23")
        exp = get_experiment(id)
        @test exp["rating"] == 4
        @test exp["custom_id"] == "FTIR-042"
        @test exp["date"] == "2026-04-23"
        delete_experiment(id)
    end

    @testset "DateTime on create_event / update_event / update_step" begin
        item_id = create_item(title="dt-event-item")
        id = create_event(item=item_id, title="dt booking",
            start=Dates.DateTime(2026, 3, 1, 9, 0, 0),
            end_=Dates.DateTime(2026, 3, 1, 12, 0, 0))
        evt = get_event(id)
        @test evt["start"] == "2026-03-01 09:00:00"
        @test evt["end"] == "2026-03-01 12:00:00"

        update_event(id; start=Dates.DateTime(2026, 3, 2, 10, 0, 0),
                         end_=Dates.DateTime(2026, 3, 2, 11, 0, 0))
        evt = get_event(id)
        @test evt["start"] == "2026-03-02 10:00:00"

        exp_id = create_experiment(title="dt-step")
        s = add_step(exp_id, "with deadline")
        update_step(exp_id, s; deadline=Dates.DateTime(2026, 5, 1, 12, 0, 0))
        step = first(filter(x -> x["id"] == s, list_steps(exp_id)))
        @test step["deadline"] == "2026-05-01 12:00:00"

        delete_experiment(exp_id)
        delete_event(id)
        delete_item(item_id)
    end
end
