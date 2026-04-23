@testset "Actions (PatchAction)" begin
    @testset "Lock toggle on experiments" begin
        id = create_experiment(title="lock-target")
        @test get_experiment(id)["locked"] == 0

        r1 = lock_experiment(id)
        @test r1["locked"] == 1
        @test get_experiment(id)["locked"] == 1

        # Second call unlocks (API contract is toggle, not latch).
        r2 = lock_experiment(id)
        @test r2["locked"] == 0

        delete_experiment(id)
    end

    @testset "Lock toggle on items" begin
        id = create_item(title="lock-item-target")
        lock_item(id)
        @test get_item(id)["locked"] == 1
        lock_item(id)
        @test get_item(id)["locked"] == 0
        delete_item(id)
    end

    @testset "Pin toggle" begin
        eid = create_experiment(title="pin-exp")
        @test pin_experiment(eid)["is_pinned"] == 1
        @test pin_experiment(eid)["is_pinned"] == 0
        delete_experiment(eid)

        iid = create_item(title="pin-item")
        @test pin_item(iid)["is_pinned"] == 1
        @test pin_item(iid)["is_pinned"] == 0
        delete_item(iid)
    end

    @testset "Timestamp" begin
        eid = create_experiment(title="ts-exp")
        r = timestamp_experiment(eid)
        @test r["timestamped"] == 1
        @test !isempty(r["timestamped_at"])
        delete_experiment(eid)

        iid = create_item(title="ts-item")
        r = timestamp_item(iid)
        @test r["timestamped"] == 1
        delete_item(iid)
    end

    @testset "Sign — success path with passphrase + meaning" begin
        id = create_experiment(title="sign-exp")
        # Int meaning
        r = sign_experiment(id; passphrase="secret", meaning=10)
        @test r["signed"] == 1
        @test r["meaning"] == 10
        # Symbol meaning
        r2 = sign_experiment(id; passphrase="secret", meaning=:authorship)
        @test r2["meaning"] == 20
        delete_experiment(id)

        # sign_item parallel path
        iid = create_item(title="sign-item")
        rv = sign_item(iid; passphrase="secret", meaning=:review)
        @test rv["signed"] == 1
        @test rv["meaning"] == 40
        delete_item(iid)
    end

    @testset "Sign — missing passphrase surfaces ServerError" begin
        # The real server returns 500 when signing isn't configured; the mock
        # replicates that when passphrase/meaning are omitted. Without them
        # Julia's type system blocks the call anyway, but we verify the mock
        # 500 path via the private helper.
        id = create_item(title="sign-fail")
        @test_throws ServerError ElabFTW._patch_action(:items, id, "sign")
        delete_item(id)
    end

    @testset "Sign meaning validation" begin
        # Int out of range
        @test_throws ArgumentError sign_experiment(1; passphrase="x", meaning=99)
        # Unknown symbol
        @test_throws ArgumentError sign_experiment(1; passphrase="x", meaning=:bogus)
    end

    @testset "SIGN_MEANING mapping" begin
        @test SIGN_MEANING[:approval] == 10
        @test SIGN_MEANING[:authorship] == 20
        @test SIGN_MEANING[:responsibility] == 30
        @test SIGN_MEANING[:review] == 40
        @test SIGN_MEANING[:safety] == 50
    end

    @testset "force_lock / force_unlock wrappers" begin
        # Mock's action dispatcher only knows lock/pin/timestamp/sign; the
        # forcelock/forceunlock actions pass through as "unknown" and return
        # HTTP 400 → ClientError. That's enough to assert the wrapper threads
        # the right action string into the payload; the real server gates
        # these on admin permission (PermissionError in practice).
        id = create_experiment(title="force-lock-test")
        @test_throws ClientError force_lock_experiment(id)
        @test_throws ClientError force_unlock_experiment(id)
        delete_experiment(id)

        iid = create_item(title="force-lock-item-test")
        @test_throws ClientError force_lock_item(iid)
        @test_throws ClientError force_unlock_item(iid)
        delete_item(iid)
    end
end
