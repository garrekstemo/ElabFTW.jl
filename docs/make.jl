using Documenter
using ElabFTW

makedocs(
    sitename = "ElabFTW.jl",
    modules = [ElabFTW],
    remotes = nothing,
    checkdocs = :exports,
    warnonly = [:missing_docs, :cross_references],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        repolink = "https://github.com/garrekstemo/ElabFTW.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Tutorials" => [
            "Iterative Experiment" => "tutorials/iterative_experiment.md",
            "Items and Linking" => "tutorials/items_and_linking.md",
        ],
        "How-To Guides" => [
            "Tagging Conventions" => "howto/tagging_conventions.md",
            "Idempotent Logging" => "howto/idempotent_logging.md",
        ],
        "Reference" => [
            "Configuration" => "reference/configuration.md",
            "Experiments" => "reference/experiments.md",
            "Items" => "reference/items.md",
            "Links" => "reference/links.md",
            "Comments" => "reference/comments.md",
            "Templates" => "reference/templates.md",
            "Team" => "reference/team.md",
            "Batch Operations" => "reference/batch.md",
            "Events" => "reference/events.md",
            "Compounds" => "reference/compounds.md",
            "Utility" => "reference/utility.md",
            "Cache" => "reference/cache.md",
            "Provenance" => "reference/provenance.md",
            "Printing" => "reference/printing.md",
        ],
    ],
)

deploydocs(
    repo = "github.com/garrekstemo/ElabFTW.jl.git",
    devbranch = "main",
    push_preview = true,
)
