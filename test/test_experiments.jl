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
        @test_throws ErrorException get_experiment(id)
        delete_experiment(dup_id)
    end

    @testset "create_from_template" begin
        tmpl_id = create_experiment_template(title="Test template", body="Template body")
        exp_id = create_from_template(tmpl_id; title="From template", tags=["tmpl-tag"])
        @test exp_id isa Int

        exp = get_experiment(exp_id)
        @test exp["title"] == "From template"

        tags = list_tags(exp_id)
        @test any(t -> t["tag"] == "tmpl-tag", tags)

        delete_experiment(exp_id)
        delete_experiment_template(tmpl_id)
    end

    @testset "Tags" begin
        id = create_experiment(title="Tag test")

        tag_experiment(id, "single-tag")
        tags = list_tags(id)
        @test length(tags) == 1
        @test tags[1]["tag"] == "single-tag"

        tag_experiment(id, ["batch-a", "batch-b"])
        tags = list_tags(id)
        @test length(tags) == 3

        tag_id = tags[1]["tag_id"]
        untag_experiment(id, tag_id)
        tags = list_tags(id)
        @test length(tags) == 2

        clear_tags(id)
        tags = list_tags(id)
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

            delete_experiment_upload(id, upload_id)
            uploads = list_experiment_uploads(id)
            @test isempty(uploads)
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
end
