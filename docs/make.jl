using Documenter
using ElabFTW

makedocs(
    sitename = "ElabFTW.jl",
    modules = [ElabFTW],
    remotes = nothing,
    checkdocs = :exports,
    warnonly = [:missing_docs],
    format = Documenter.HTML(
        prettyurls=false,
        repolink="https://github.com/garrekstemo/ElabFTW.jl",
    ),
    pages = [
        "Home" => "index.md",
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
