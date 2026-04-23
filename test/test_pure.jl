@testset "Configuration" begin
    saved_url = ElabFTW._elabftw_config.url
    saved_key = ElabFTW._elabftw_config.api_key
    saved_enabled = ElabFTW._elabftw_config.enabled
    saved_cache = ElabFTW._elabftw_config.cache_dir
    saved_cats = copy(ElabFTW._elabftw_config.category_ids)

    try
        ElabFTW._elabftw_config.url = nothing
        ElabFTW._elabftw_config.api_key = nothing
        ElabFTW._elabftw_config.enabled = false

        @test !elabftw_enabled()
        @test_throws NotConfiguredError enable_elabftw()

        tmpdir = mktempdir()
        configure_elabftw(url="http://test.example.com/", api_key="key-123", cache_dir=tmpdir)
        @test elabftw_enabled()
        @test ElabFTW._elabftw_config.url == "http://test.example.com"
        @test ElabFTW._elabftw_config.api_key == "key-123"
        @test isdir(tmpdir)

        disable_elabftw()
        @test !elabftw_enabled()
        enable_elabftw()
        @test elabftw_enabled()
    finally
        ElabFTW._elabftw_config.url = saved_url
        ElabFTW._elabftw_config.api_key = saved_key
        ElabFTW._elabftw_config.enabled = saved_enabled
        ElabFTW._elabftw_config.cache_dir = saved_cache
        ElabFTW._elabftw_config.category_ids = saved_cats
    end
end

@testset "_parse_id_from_response" begin
    resp = HTTP.Response(201, "")
    push!(resp.headers, "Location" => "/api/v2/experiments/42")
    @test ElabFTW._parse_id_from_response(resp) == 42

    resp2 = HTTP.Response(201, JSON.json(Dict("id" => 7)))
    @test ElabFTW._parse_id_from_response(resp2) == 7

    resp3 = HTTP.Response(201, "{}")
    @test_throws ParseError ElabFTW._parse_id_from_response(resp3)
end

@testset "_get_cache_path" begin
    ElabFTW._elabftw_config.cache_dir = "/tmp/test_cache"
    @test ElabFTW._get_cache_path(10, 5, "data.csv") == "/tmp/test_cache/10/data.csv"
    @test ElabFTW._get_cache_path(10, 5, "") == "/tmp/test_cache/10/upload_5.csv"
end

@testset "elabftw_cache_info empty" begin
    tmpdir = mktempdir()
    ElabFTW._elabftw_config.cache_dir = tmpdir
    info = elabftw_cache_info()
    @test info.files == 0
    @test info.size_mb == 0.0
    @test info.path == tmpdir
end

@testset "API guards (disabled)" begin
    disable_elabftw()

    @testset "Experiment guards" begin
        @test_throws NotConfiguredError create_experiment(title="test")
        @test_throws NotConfiguredError update_experiment(1; title="test")
        @test_throws NotConfiguredError upload_to_experiment(1, "test.pdf")
        @test_throws NotConfiguredError tag_experiment(1, "test")
        @test_throws NotConfiguredError tag_experiment(1, ["a", "b"])
        @test_throws NotConfiguredError get_experiment(1)
        @test_throws NotConfiguredError log_to_elab(title="test")
        @test_throws NotConfiguredError list_experiments()
        @test_throws NotConfiguredError search_experiments(query="test")
        @test_throws NotConfiguredError delete_experiment(1)
        @test_throws NotConfiguredError duplicate_experiment(1)
        @test_throws NotConfiguredError create_from_template(1)
    end

    @testset "Tag guards" begin
        @test_throws NotConfiguredError list_experiment_tags(1)
        @test_throws NotConfiguredError untag_experiment(1, 1)
        @test_throws NotConfiguredError clear_experiment_tags(1)
        @test_throws NotConfiguredError list_team_tags()
        @test_throws NotConfiguredError rename_team_tag(1, "new")
        @test_throws NotConfiguredError delete_team_tag(1)
    end

    @testset "Item guards" begin
        @test_throws NotConfiguredError create_item(title="test")
        @test_throws NotConfiguredError get_item(1)
        @test_throws NotConfiguredError update_item(1; title="test")
        @test_throws NotConfiguredError delete_item(1)
        @test_throws NotConfiguredError duplicate_item(1)
        @test_throws NotConfiguredError list_items()
        @test_throws NotConfiguredError search_items(query="test")
        @test_throws NotConfiguredError tag_item(1, "test")
        @test_throws NotConfiguredError tag_item(1, ["a", "b"])
        @test_throws NotConfiguredError untag_item(1, 1)
        @test_throws NotConfiguredError list_item_tags(1)
        @test_throws NotConfiguredError clear_item_tags(1)
        @test_throws NotConfiguredError upload_to_item(1, "test.pdf")
        @test_throws NotConfiguredError list_item_uploads(1)
        @test_throws NotConfiguredError delete_item_upload(1, 1)
        @test_throws NotConfiguredError add_item_step(1, "test")
        @test_throws NotConfiguredError list_item_steps(1)
        @test_throws NotConfiguredError finish_item_step(1, 1)
    end

    @testset "Link guards" begin
        @test_throws NotConfiguredError link_experiment_to_item(1, 2)
        @test_throws NotConfiguredError unlink_experiment_from_item(1, 2)
        @test_throws NotConfiguredError list_experiment_item_links(1)
        @test_throws NotConfiguredError link_item_to_experiment(1, 2)
        @test_throws NotConfiguredError unlink_item_from_experiment(1, 2)
        @test_throws NotConfiguredError list_item_experiment_links(1)
        @test_throws NotConfiguredError link_items(1, 2)
        @test_throws NotConfiguredError unlink_items(1, 2)
        @test_throws NotConfiguredError list_item_links(1)
        @test_throws NotConfiguredError list_experiment_links(1)
        @test_throws NotConfiguredError unlink_experiments(1, 2)
        @test_throws NotConfiguredError link_experiments(1, 2)
    end

    @testset "Comment guards" begin
        @test_throws NotConfiguredError create_comment(:experiments, 1, "test")
        @test_throws NotConfiguredError list_comments(:experiments, 1)
        @test_throws NotConfiguredError get_comment(:experiments, 1, 1)
        @test_throws NotConfiguredError update_comment(:experiments, 1, 1, "test")
        @test_throws NotConfiguredError delete_comment(:experiments, 1, 1)
        @test_throws NotConfiguredError comment_experiment(1, "test")
        @test_throws NotConfiguredError list_experiment_comments(1)
        @test_throws NotConfiguredError comment_item(1, "test")
        @test_throws NotConfiguredError list_item_comments(1)
    end

    @testset "Template guards" begin
        @test_throws NotConfiguredError list_experiment_templates()
        @test_throws NotConfiguredError create_experiment_template(title="test")
        @test_throws NotConfiguredError get_experiment_template(1)
        @test_throws NotConfiguredError update_experiment_template(1; title="test")
        @test_throws NotConfiguredError delete_experiment_template(1)
        @test_throws NotConfiguredError duplicate_experiment_template(1)
        @test_throws NotConfiguredError list_items_types()
        @test_throws NotConfiguredError create_items_type(title="test")
        @test_throws NotConfiguredError get_items_type(1)
        @test_throws NotConfiguredError update_items_type(1; title="test")
        @test_throws NotConfiguredError delete_items_type(1)
    end

    @testset "Event guards" begin
        @test_throws NotConfiguredError list_events()
        @test_throws NotConfiguredError create_event(item=1, title="test",
            start="2026-01-01 00:00:00", end_="2026-01-02 00:00:00")
        @test_throws NotConfiguredError get_event(1)
        @test_throws NotConfiguredError update_event(1; title="test")
        @test_throws NotConfiguredError delete_event(1)
    end

    @testset "Compound guards" begin
        @test_throws NotConfiguredError list_compounds()
        @test_throws NotConfiguredError create_compound(name="test")
        @test_throws NotConfiguredError get_compound(1)
        @test_throws NotConfiguredError delete_compound(1)
        @test_throws NotConfiguredError link_compound(:experiments, 1, 1)
        @test_throws NotConfiguredError list_compound_links(:experiments, 1)
    end

    @testset "Utility guards" begin
        @test_throws NotConfiguredError instance_info()
        @test_throws NotConfiguredError list_favorite_tags()
        @test_throws NotConfiguredError add_favorite_tag("alpha")
        @test_throws NotConfiguredError remove_favorite_tag(1)
    end

    @testset "Team guards" begin
        @test_throws NotConfiguredError list_experiments_categories()
        @test_throws NotConfiguredError list_items_categories()
    end

    @testset "Batch guards" begin
        @test_throws NotConfiguredError delete_experiments()
        @test_throws NotConfiguredError tag_experiments("tag")
        @test_throws NotConfiguredError update_experiments(new_body="test")
        @test_throws NotConfiguredError delete_items()
        @test_throws NotConfiguredError tag_items("tag")
        @test_throws NotConfiguredError update_items(new_body="test")
    end

    @testset "Steps and misc guards" begin
        @test_throws NotConfiguredError test_connection()
        @test_throws NotConfiguredError add_step(1, "test")
        @test_throws NotConfiguredError list_steps(1)
        @test_throws NotConfiguredError finish_step(1, 1)
    end
end
