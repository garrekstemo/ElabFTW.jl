@testset "Events" begin
    item_id = create_item(title="FTIR instrument")
    id = create_event(item=item_id, title="FTIR session",
        start="2026-03-01 09:00:00", end_="2026-03-01 12:00:00")
    @test id isa Int

    events = list_events()
    @test events isa Vector
    @test any(e -> e["id"] == id, events)

    evt = get_event(id)
    @test evt["title"] == "FTIR session"
    @test evt["start"] == "2026-03-01 09:00:00"
    @test evt["end"] == "2026-03-01 12:00:00"
    @test evt["item"] == item_id

    update_event(id; title="Updated session")
    @test get_event(id)["title"] == "Updated session"

    update_event(id; start="2026-03-01 10:00:00", end_="2026-03-01 11:00:00")
    evt = get_event(id)
    @test evt["start"] == "2026-03-01 10:00:00"
    @test evt["end"] == "2026-03-01 11:00:00"

    exp_id = create_experiment(title="Bound exp")
    update_event(id; experiment=exp_id)
    @test get_event(id)["experiment"] == exp_id

    update_event(id; item_link=item_id)
    @test get_event(id)["item_link"] == item_id

    @test_throws ErrorException update_event(id; start="2026-03-01 10:00:00")

    delete_event(id)
    @test_throws NotFoundError get_event(id)
    delete_item(item_id)
    delete_experiment(exp_id)
end
