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
        @test_throws ErrorException enable_elabftw()

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
    @test_throws ErrorException ElabFTW._parse_id_from_response(resp3)
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
        @test_throws ErrorException create_experiment(title="test")
        @test_throws ErrorException update_experiment(1; title="test")
        @test_throws ErrorException upload_to_experiment(1, "test.pdf")
        @test_throws ErrorException tag_experiment(1, "test")
        @test_throws ErrorException tag_experiment(1, ["a", "b"])
        @test_throws ErrorException get_experiment(1)
        @test_throws ErrorException log_to_elab(title="test")
        @test_throws ErrorException list_experiments()
        @test_throws ErrorException search_experiments(query="test")
        @test_throws ErrorException delete_experiment(1)
        @test_throws ErrorException duplicate_experiment(1)
        @test_throws ErrorException create_from_template(1)
    end

    @testset "Tag guards" begin
        @test_throws ErrorException list_tags(1)
        @test_throws ErrorException untag_experiment(1, 1)
        @test_throws ErrorException clear_tags(1)
        @test_throws ErrorException list_team_tags()
        @test_throws ErrorException rename_team_tag(1, "new")
        @test_throws ErrorException delete_team_tag(1)
    end

    @testset "Item guards" begin
        @test_throws ErrorException create_item(title="test")
        @test_throws ErrorException get_item(1)
        @test_throws ErrorException update_item(1; title="test")
        @test_throws ErrorException delete_item(1)
        @test_throws ErrorException duplicate_item(1)
        @test_throws ErrorException list_items()
        @test_throws ErrorException search_items(query="test")
        @test_throws ErrorException tag_item(1, "test")
        @test_throws ErrorException tag_item(1, ["a", "b"])
        @test_throws ErrorException untag_item(1, 1)
        @test_throws ErrorException list_item_tags(1)
        @test_throws ErrorException clear_item_tags(1)
        @test_throws ErrorException upload_to_item(1, "test.pdf")
        @test_throws ErrorException list_item_uploads(1)
        @test_throws ErrorException delete_item_upload(1, 1)
        @test_throws ErrorException add_item_step(1, "test")
        @test_throws ErrorException list_item_steps(1)
        @test_throws ErrorException finish_item_step(1, 1)
    end

    @testset "Link guards" begin
        @test_throws ErrorException link_experiment_to_item(1, 2)
        @test_throws ErrorException unlink_experiment_from_item(1, 2)
        @test_throws ErrorException list_experiment_item_links(1)
        @test_throws ErrorException link_item_to_experiment(1, 2)
        @test_throws ErrorException unlink_item_from_experiment(1, 2)
        @test_throws ErrorException list_item_experiment_links(1)
        @test_throws ErrorException link_items(1, 2)
        @test_throws ErrorException unlink_items(1, 2)
        @test_throws ErrorException list_item_links(1)
        @test_throws ErrorException list_experiment_links(1)
        @test_throws ErrorException unlink_experiments(1, 2)
        @test_throws ErrorException link_experiments(1, 2)
    end

    @testset "Comment guards" begin
        @test_throws ErrorException create_comment(:experiments, 1, "test")
        @test_throws ErrorException list_comments(:experiments, 1)
        @test_throws ErrorException get_comment(:experiments, 1, 1)
        @test_throws ErrorException update_comment(:experiments, 1, 1, "test")
        @test_throws ErrorException delete_comment(:experiments, 1, 1)
        @test_throws ErrorException comment_experiment(1, "test")
        @test_throws ErrorException list_experiment_comments(1)
        @test_throws ErrorException comment_item(1, "test")
        @test_throws ErrorException list_item_comments(1)
    end

    @testset "Template guards" begin
        @test_throws ErrorException list_experiment_templates()
        @test_throws ErrorException create_experiment_template(title="test")
        @test_throws ErrorException get_experiment_template(1)
        @test_throws ErrorException update_experiment_template(1; title="test")
        @test_throws ErrorException delete_experiment_template(1)
        @test_throws ErrorException duplicate_experiment_template(1)
        @test_throws ErrorException list_items_types()
        @test_throws ErrorException create_items_type(title="test")
        @test_throws ErrorException get_items_type(1)
        @test_throws ErrorException update_items_type(1; title="test")
        @test_throws ErrorException delete_items_type(1)
    end

    @testset "Event guards" begin
        @test_throws ErrorException list_events()
        @test_throws ErrorException create_event(item=1, title="test",
            start="2026-01-01 00:00:00", end_="2026-01-02 00:00:00")
        @test_throws ErrorException get_event(1)
        @test_throws ErrorException update_event(1; title="test")
        @test_throws ErrorException delete_event(1)
    end

    @testset "Compound guards" begin
        @test_throws ErrorException list_compounds()
        @test_throws ErrorException create_compound(name="test")
        @test_throws ErrorException get_compound(1)
        @test_throws ErrorException delete_compound(1)
        @test_throws ErrorException link_compound(:experiments, 1, 1)
        @test_throws ErrorException list_compound_links(:experiments, 1)
    end

    @testset "Utility guards" begin
        @test_throws ErrorException instance_info()
        @test_throws ErrorException list_favorite_tags()
        @test_throws ErrorException add_favorite_tag("alpha")
        @test_throws ErrorException remove_favorite_tag(1)
    end

    @testset "Team guards" begin
        @test_throws ErrorException list_experiments_categories()
        @test_throws ErrorException list_items_categories()
    end

    @testset "Batch guards" begin
        @test_throws ErrorException delete_experiments()
        @test_throws ErrorException tag_experiments("tag")
        @test_throws ErrorException update_experiments(new_body="test")
        @test_throws ErrorException delete_items()
        @test_throws ErrorException tag_items("tag")
        @test_throws ErrorException update_items(new_body="test")
    end

    @testset "Steps and misc guards" begin
        @test_throws ErrorException test_connection()
        @test_throws ErrorException add_step(1, "test")
        @test_throws ErrorException list_steps(1)
        @test_throws ErrorException finish_step(1, 1)
    end
end
