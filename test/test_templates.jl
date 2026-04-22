@testset "Templates" begin
    @testset "Experiment templates" begin
        id = create_experiment_template(title="Test template", body="Template body")
        @test id isa Int

        templates = list_experiment_templates()
        @test templates isa Vector
        @test any(t -> t["id"] == id, templates)

        tmpl = get_experiment_template(id)
        @test tmpl["title"] == "Test template"
        @test tmpl["id"] == id

        update_experiment_template(id; title="Updated template", body="New body")
        tmpl = get_experiment_template(id)
        @test tmpl["title"] == "Updated template"

        dup_id = duplicate_experiment_template(id)
        @test dup_id isa Int
        @test dup_id != id

        delete_experiment_template(dup_id)
        @test_throws NotFoundError get_experiment_template(dup_id)

        delete_experiment_template(id)
    end

    @testset "Items types (plain)" begin
        id = create_items_type(title="Sample type", body="Sample template body")
        @test id isa Int

        types = list_items_types()
        @test types isa Vector
        @test any(t -> t["id"] == id, types)

        it = get_items_type(id)
        @test it["title"] == "Sample type"

        update_items_type(id; title="Updated type", body="New body")
        it = get_items_type(id)
        @test it["title"] == "Updated type"

        delete_items_type(id)
        @test_throws NotFoundError get_items_type(id)
    end

    @testset "Items types (with metadata)" begin
        meta = Dict("extra_fields" => Dict("field1" => Dict("type" => "text", "value" => "")))
        id = create_items_type(title="Rich type", body="With metadata", metadata=meta)
        @test id isa Int

        it = get_items_type(id)
        @test it["title"] == "Rich type"
        @test !isnothing(it["metadata"])

        delete_items_type(id)
    end
end
