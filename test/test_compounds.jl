@testset "Compounds" begin
    @testset "CRUD" begin
        id = create_compound(name="NH4SCN", cas_number="1762-95-4")
        @test id isa Int

        compounds = list_compounds()
        @test compounds isa Vector
        @test any(c -> c["id"] == id, compounds)

        compound = get_compound(id)
        @test compound["name"] == "NH4SCN"
        @test compound["cas_number"] == "1762-95-4"

        delete_compound(id)
        @test_throws NotFoundError get_compound(id)
    end

    @testset "Compound with SMILES" begin
        id = create_compound(name="Water", smiles="O", molecular_formula="H2O")
        compound = get_compound(id)
        @test compound["name"] == "Water"
        @test compound["smiles"] == "O"
        @test compound["molecular_formula"] == "H2O"
        delete_compound(id)
    end

    @testset "Compound linking" begin
        exp_id = create_experiment(title="Compound link test")
        comp_id = create_compound(name="Test compound")

        link_compound(:experiments, exp_id, comp_id)
        links = list_compound_links(:experiments, exp_id)
        @test length(links) == 1
        @test links[1]["id"] == comp_id

        delete_experiment(exp_id)
        delete_compound(comp_id)
    end

    @testset "Compound linking to item" begin
        item_id = create_item(title="Compound item test")
        comp_id = create_compound(name="Item compound")

        link_compound(:items, item_id, comp_id)
        links = list_compound_links(:items, item_id)
        @test length(links) == 1
        @test links[1]["id"] == comp_id

        delete_item(item_id)
        delete_compound(comp_id)
    end
end
