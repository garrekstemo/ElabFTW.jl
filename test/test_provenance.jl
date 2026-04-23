@testset "tags_from_sample" begin
    sample = Dict(
        "solute" => "NH4SCN",
        "solvent" => "DMF",
        "concentration" => "1.0M",
        "substrate" => "CaF2",
        "_id" => "NH4SCN_DMF_1M",
        "path" => "ftir/test.csv",
        "date" => "2025-06-19",
        "pathlength" => 12.0
    )

    tags = tags_from_sample(sample)
    @test "NH4SCN" in tags
    @test "DMF" in tags
    @test "1.0M" in tags
    @test "CaF2" in tags
    @test !("NH4SCN_DMF_1M" in tags)
    @test !("ftir/test.csv" in tags)
    @test !("2025-06-19" in tags)
    @test length(tags) == 4

    tags_filtered = tags_from_sample(sample; include=[:solute, :solvent])
    @test "NH4SCN" in tags_filtered
    @test "DMF" in tags_filtered
    @test !("1.0M" in tags_filtered)
    @test !("CaF2" in tags_filtered)
    @test length(tags_filtered) == 2

    @test isempty(tags_from_sample(Dict()))
end

@testset "log_to_elab create path" begin
    id = log_to_elab(title="Mock log test", body="Test body", tags=["mock-tag"])
    @test id isa Int
    @test id > 0

    exp = get_experiment(id)
    @test exp["title"] == "Mock log test"
    tags = list_experiment_tags(id)
    @test any(t -> t["tag"] == "mock-tag", tags)
end

@testset "log_to_elab update path + attachment replace" begin
    # log_to_elab uses the running script's dirname for .elab_id. Tests
    # run with PROGRAM_FILE empty, so point it at a real file in a tempdir.
    tmpdir = mktempdir()
    fake_script = joinpath(tmpdir, "fake_script.jl")
    write(fake_script, "# marker\n")

    saved_prog = Base.PROGRAM_FILE
    try
        Base.PROGRAM_FILE = fake_script
        tmpfile = joinpath(tmpdir, "attach.txt")
        write(tmpfile, "v1")

        # First run seeds two tags.
        id = log_to_elab(title="Idempotent log", body="v1",
                         attachments=[tmpfile], tags=["stale-a", "stale-b"])
        @test isfile(joinpath(tmpdir, ".elab_id"))
        @test length(list_experiment_tags(id)) == 2

        # Re-run with same title hits the update branch + attachment replace.
        # New tags are a different set — the old ones must disappear, not
        # accumulate. The bug this guards against: update branch appending
        # tags instead of replacing them.
        write(tmpfile, "v2")
        id2 = log_to_elab(title="Idempotent log", body="v2",
                          attachments=[tmpfile], tags=["upd-tag"])
        @test id2 == id

        exp = get_experiment(id)
        @test exp["body"] == "v2"
        tag_names = [t["tag"] for t in list_experiment_tags(id)]
        @test tag_names == ["upd-tag"]  # stale-a / stale-b gone
        @test !("stale-a" in tag_names)
        @test !("stale-b" in tag_names)

        # Re-run with no tags should leave the experiment with zero tags.
        log_to_elab(title="Idempotent log", body="v3")
        @test isempty(list_experiment_tags(id))

        # Replace semantics: the old attach.txt was deleted, the new one
        # was uploaded — there must be exactly one active attachment with
        # that filename, not two. (A bug that appended instead of replaced
        # would leave two uploads here.)
        uploads = list_experiment_uploads(id)
        active_attach = filter(uploads) do u
            get(u, "real_name", "") == "attach.txt" && get(u, "state", 1) == 1
        end
        @test length(active_attach) == 1

        delete_experiment(id)
    finally
        Base.PROGRAM_FILE = saved_prog
        rm(tmpdir; recursive=true, force=true)
    end
end
