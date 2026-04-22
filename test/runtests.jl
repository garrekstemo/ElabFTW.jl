using Test
using ElabFTW
import HTTP, JSON, Sockets
using Aqua

include("mock_server.jl")

@testset "ElabFTW.jl" begin

    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(ElabFTW; deps_compat=(check_extras=false, ignore=[:Dates],))
    end
    # Pure tests (no HTTP server needed)
    include("test_pure.jl")
    include("test_printing.jl")

    # Start mock HTTP server (global so test files can queue failures on it)
    global mock = start_mock_server()
    cache_dir = mktempdir()
    configure_elabftw(
        url = "http://127.0.0.1:$(mock.port)",
        api_key = "mock-api-key",
        cache_dir = cache_dir
    )

    try
        include("test_provenance.jl")
        include("test_experiments.jl")
        include("test_items.jl")
        include("test_comments.jl")
        include("test_templates.jl")
        include("test_team.jl")
        include("test_events.jl")
        include("test_compounds.jl")
        include("test_storage.jl")
        include("test_revisions.jl")
        include("test_utility.jl")
        include("test_batch.jl")
        include("test_errors.jl")
    finally
        stop_mock_server(mock.server)
        rm(cache_dir; recursive=true, force=true)
    end
end
