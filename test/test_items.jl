@testset "Items" begin
    @testset "CRUD" begin
        id = create_item(title="Test item", body="Item body")
        @test id isa Int
        @test id > 0

        item = get_item(id)
        @test item["title"] == "Test item"
        @test item["id"] == id

        update_item(id; title="Updated item", body="New body")
        item = get_item(id)
        @test item["title"] == "Updated item"

        items = list_items()
        @test items isa Vector
        @test any(i -> i["id"] == id, items)

        results = search_items(query="Updated")
        @test any(i -> i["id"] == id, results)

        dup_id = duplicate_item(id)
        @test dup_id isa Int
        @test dup_id != id

        delete_item(id)
        @test_throws ErrorException get_item(id)
        delete_item(dup_id)
    end

    @testset "Tags" begin
        id = create_item(title="Tag item test")

        tag_item(id, "item-tag")
        tags = list_item_tags(id)
        @test length(tags) == 1
        @test tags[1]["tag"] == "item-tag"

        tag_item(id, ["tag-a", "tag-b"])
        tags = list_item_tags(id)
        @test length(tags) == 3

        tag_id = tags[1]["tag_id"]
        untag_item(id, tag_id)
        tags = list_item_tags(id)
        @test length(tags) == 2

        clear_item_tags(id)
        tags = list_item_tags(id)
        @test isempty(tags)

        delete_item(id)
    end

    @testset "Steps" begin
        id = create_item(title="Step item test")

        s1 = add_item_step(id, "Step one")
        @test s1 isa Int
        s2 = add_item_step(id, "Step two")

        steps = list_item_steps(id)
        @test length(steps) == 2

        finish_item_step(id, s1)
        steps = list_item_steps(id)
        finished = first(filter(s -> s["id"] == s1, steps))
        @test finished["finished"] == true

        delete_item(id)
    end

    @testset "Uploads" begin
        id = create_item(title="Upload item test")
        tmpfile = tempname() * ".txt"
        write(tmpfile, "item upload content")

        try
            upload_id = upload_to_item(id, tmpfile; comment="item file")
            @test upload_id isa Int

            uploads = list_item_uploads(id)
            @test length(uploads) == 1

            delete_item_upload(id, upload_id)
            uploads = list_item_uploads(id)
            @test isempty(uploads)
        finally
            isfile(tmpfile) && rm(tmpfile)
        end

        delete_item(id)
    end

    @testset "Item-to-item links" begin
        id1 = create_item(title="Link item 1")
        id2 = create_item(title="Link item 2")

        link_items(id1, id2)
        links = list_item_links(id1)
        @test length(links) == 1
        @test links[1]["entityid"] == id2

        unlink_items(id1, id2)
        links = list_item_links(id1)
        @test isempty(links)

        delete_item(id1)
        delete_item(id2)
    end

    @testset "Cross-entity links" begin
        exp_id = create_experiment(title="Cross-link exp")
        item_id = create_item(title="Cross-link item")

        link_experiment_to_item(exp_id, item_id)
        links = list_experiment_item_links(exp_id)
        @test length(links) == 1
        @test links[1]["entityid"] == item_id

        unlink_experiment_from_item(exp_id, item_id)
        links = list_experiment_item_links(exp_id)
        @test isempty(links)

        link_item_to_experiment(item_id, exp_id)
        links = list_item_experiment_links(item_id)
        @test length(links) == 1
        @test links[1]["entityid"] == exp_id

        unlink_item_from_experiment(item_id, exp_id)
        links = list_item_experiment_links(item_id)
        @test isempty(links)

        delete_experiment(exp_id)
        delete_item(item_id)
    end

    @testset "Category" begin
        id = create_item(title="Categorized item", category=5)
        item = get_item(id)
        @test item["category"] == 5
        delete_item(id)
    end
end
