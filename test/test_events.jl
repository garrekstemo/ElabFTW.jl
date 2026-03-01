@testset "Events" begin
    id = create_event(title="FTIR session", start="2026-03-01T09:00:00", end_="2026-03-01T12:00:00")
    @test id isa Int

    events = list_events()
    @test events isa Vector
    @test any(e -> e["id"] == id, events)

    evt = get_event(id)
    @test evt["title"] == "FTIR session"
    @test evt["start"] == "2026-03-01T09:00:00"
    @test evt["end"] == "2026-03-01T12:00:00"

    update_event(id; title="Updated session", start="2026-03-01T10:00:00")
    evt = get_event(id)
    @test evt["title"] == "Updated session"
    @test evt["start"] == "2026-03-01T10:00:00"

    delete_event(id)
    @test_throws ErrorException get_event(id)

    # Event with item booking
    item_id = create_item(title="FTIR instrument")
    evt_id = create_event(title="Booking", start="2026-03-02T09:00:00", end_="2026-03-02T17:00:00", item=item_id)
    evt = get_event(evt_id)
    @test evt["item"] == item_id

    delete_event(evt_id)
    delete_item(item_id)
end
