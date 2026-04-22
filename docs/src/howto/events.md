# Scheduler events and instrument bookings

This guide shows how to book a bookable item (an instrument, typically), reschedule the slot, and attach the booking to an experiment. eLabFTW's scheduler uses two quirky endpoint shapes, so the recipes below note them explicitly.

## API Shape

The scheduler API splits create from read/update/delete across two URL prefixes:

| Operation     | Endpoint                         | Function          |
| ------------- | -------------------------------- | ----------------- |
| Create event  | `POST /events/{item_id}`         | `create_event`    |
| List events   | `GET /events`                    | `list_events`     |
| Get event     | `GET /event/{id}` (singular)     | `get_event`       |
| Update event  | `PATCH /event/{id}` (singular)   | `update_event`    |
| Delete event  | `DELETE /event/{id}` (singular)  | `delete_event`    |

The plural `/events/{item_id}` on create is the item you are booking *against*; the singular `/event/{id}` on GET/PATCH/DELETE is the event itself. Every function in `src/events.jl` hides this — call them by event ID and the correct URL is built for you.

## Booking a Bookable Item

Start with an item that someone has marked "bookable" in the eLabFTW web UI. If you do not have one, create a fresh instrument item first:

```julia
using ElabFTW

ftir = create_item(title="Bruker Vertex 70 FTIR", category=104)
tag_item(ftir, ["instrument", "ftir"])
# Then flip the "bookable" switch on this item in the web UI.
```

Reserve the instrument for a three-hour slot:

```julia
event_id = create_event(
    item  = ftir,
    title = "FTIR: CN stretch series",
    start = "2026-04-23 09:00:00",
    end_  = "2026-04-23 12:00:00",
)
```

Both `start` and `end_` take `"YYYY-MM-DD HH:MM:SS"`; ISO 8601 also parses. The trailing underscore on `end_` avoids clashing with Julia's `end` keyword.

Fetch the booking back to confirm:

```julia
e = get_event(event_id)
e["title"]   # "FTIR: CN stretch series"
e["start"]   # "2026-04-23T09:00:00..."
```

List everything on the scheduler with `list_events`:

```julia
for ev in list_events(limit=50)
    println(ev["id"], ": ", ev["title"], "  ", ev["start"], " → ", ev["end"])
end
```

## Rescheduling a Slot

`update_event` issues one PATCH per field because the eLabFTW API is target-based: each PATCH carries a `target` key and applies to a single attribute. The wrapper hides this.

Change the title:

```julia
update_event(event_id; title="FTIR: CN stretch series (rescheduled)")
```

Move the slot — `start` and `end_` must be provided together; the API rejects partial datetime changes:

```julia
update_event(event_id;
    start = "2026-04-24 09:00:00",
    end_  = "2026-04-24 12:00:00",
)
```

Passing one without the other errors out before any HTTP call:

```julia
update_event(event_id; start="2026-04-25 09:00:00")
# ERROR: update_event: start and end_ must be provided together
```

## Binding the Booking to an Experiment

A booking is more useful when it points at the experiment it enables. `update_event` with `experiment=...` issues a `target="experiment"` PATCH:

```julia
exp_id = create_experiment(title="FTIR: NH4SCN CN stretch, 23 Apr 2026")
update_event(event_id; experiment=exp_id)
```

The experiment link now appears on the booking in the web UI. The reverse — attaching an experiment to an item — is handled by [`link_experiment_to_item`](../reference/links.md); `update_event(..., experiment=...)` is the booking-side binding.

## Linking to a Non-Experiment Item

`item_link` binds a booking to an arbitrary item (a sample, a procedure, a cryostat) rather than an experiment:

```julia
sample_id = create_item(title="NH4SCN 1.0 M in DMF", category=107)
update_event(event_id; item_link=sample_id)
```

`experiment` and `item_link` are separate PATCH targets — a single booking can carry both:

```julia
update_event(event_id;
    experiment = exp_id,
    item_link  = sample_id,
)
# → two PATCH calls, one per target
```

Setting both fields in one call is a cosmetic nicety; under the hood `update_event` walks through each non-`nothing` kwarg and fires its own HTTP request.

## Cancelling a Booking

`delete_event` hits `DELETE /event/{id}`:

```julia
delete_event(event_id)
```

The underlying item stays bookable — only the reservation is removed.

## End-to-End: Book, Bind, Reschedule

```julia
using ElabFTW

# Bookable item (create once, mark bookable in the UI)
ftir = create_item(title="Bruker Vertex 70 FTIR", category=104)

# Reserve
ev = create_event(
    item  = ftir,
    title = "FTIR session",
    start = "2026-04-23 09:00:00",
    end_  = "2026-04-23 12:00:00",
)

# Link to a fresh experiment + the stock sample
exp = create_experiment(title="FTIR: NH4SCN CN stretch")
sample = create_item(title="NH4SCN 1.0 M DMF stock", category=107)
update_event(ev; experiment=exp, item_link=sample)

# Pushed by a day
update_event(ev;
    start = "2026-04-24 09:00:00",
    end_  = "2026-04-24 12:00:00",
)
```

## See Also

- [Events](../reference/events.md) — `create_event`, `get_event`, `update_event`, `delete_event`, `list_events`
- [Items](../reference/items.md) — `create_item`, `tag_item`
- [Experiments](../reference/experiments.md) — `create_experiment`
