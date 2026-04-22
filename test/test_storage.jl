@testset "Storage" begin
    @testset "Storage unit CRUD" begin
        freezer = create_storage_unit(name="Freezer A")
        @test freezer isa Int

        drawer = create_storage_unit(name="Drawer 1", parent_id=freezer)
        @test drawer isa Int

        unit = get_storage_unit(freezer)
        @test unit["name"] == "Freezer A"
        @test unit["parent_id"] === nothing
        @test unit["level_depth"] == 0

        child = get_storage_unit(drawer)
        @test child["parent_id"] == freezer
        @test child["level_depth"] == 1
        @test child["full_path"] == "Freezer A > Drawer 1"

        rename_storage_unit(freezer, "Freezer A (cold room)")
        @test get_storage_unit(freezer)["name"] == "Freezer A (cold room)"
        @test get_storage_unit(drawer)["full_path"] == "Freezer A (cold room) > Drawer 1"

        tree = list_storage_units(hierarchy=true)
        @test any(u -> u["id"] == freezer && u["children_count"] == 1, tree)
        @test any(u -> u["id"] == drawer && u["children_count"] == 0, tree)

        @test_throws ErrorException delete_storage_unit(freezer)

        delete_storage_unit(drawer)
        delete_storage_unit(freezer)
        @test_throws ErrorException get_storage_unit(freezer)
    end

    @testset "Containers on items" begin
        item_id = create_item(title="Stored sample")
        unit_id = create_storage_unit(name="Box A")

        @test isempty(list_containers(:items, item_id))

        cid = create_container(:items, item_id;
            storage_id=unit_id, qty_stored=50, qty_unit="mL")
        @test cid isa Int

        rows = list_containers(:items, item_id)
        @test length(rows) == 1
        @test rows[1]["id"] == cid
        @test rows[1]["storage_id"] == unit_id
        @test rows[1]["qty_unit"] == "mL"

        row = get_container(:items, item_id, cid)
        @test row["id"] == cid
        @test row["qty_unit"] == "mL"

        update_container(:items, item_id, cid; qty_stored=25, qty_unit="g")
        row = get_container(:items, item_id, cid)
        @test row["qty_stored"] == "25"
        @test row["qty_unit"] == "g"

        update_container(:items, item_id, cid)

        delete_container(:items, item_id, cid)
        @test isempty(list_containers(:items, item_id))

        delete_storage_unit(unit_id)
        delete_item(item_id)
    end

    @testset "Containers on experiments" begin
        exp_id = create_experiment(title="Stored experiment")
        unit_id = create_storage_unit(name="Shelf X")

        cid = create_container(:experiments, exp_id;
            storage_id=unit_id, qty_stored=1, qty_unit="•")
        rows = list_containers(:experiments, exp_id)
        @test length(rows) == 1
        @test rows[1]["id"] == cid

        delete_container(:experiments, exp_id, cid)
        delete_storage_unit(unit_id)
        delete_experiment(exp_id)
    end

    @testset "list_storage_units default returns assignments" begin
        item_id = create_item(title="Default-list probe")
        unit_id = create_storage_unit(name="Probe bin")
        cid = create_container(:items, item_id;
            storage_id=unit_id, qty_stored=10, qty_unit="mL")

        rows = list_storage_units()
        hit = findfirst(r -> r["container2item_id"] == cid, rows)
        @test hit !== nothing
        @test rows[hit]["entity_id"] == item_id
        @test rows[hit]["storage_id"] == unit_id

        delete_container(:items, item_id, cid)
        delete_storage_unit(unit_id)
        delete_item(item_id)
    end
end
