using FlowGenerator
using Documenter

DocMeta.setdocmeta!(FlowGenerator, :DocTestSetup, :(using FlowGenerator); recursive = false)

makedocs(;
    modules = [FlowGenerator],
    authors = "Vinicius Loti de Lima",
    sitename = "FlowGenerator.jl",
    format = Documenter.HTML(;
        canonical = "https://loti45.github.io/FlowGenerator.jl",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Getting started" => [
            "Public interface" => "index.md",
            "Examples" => map(
                s -> "examples/$(s)",
                sort(readdir(joinpath(@__DIR__, "src/examples"))),
            ),
        ],
        "For developers" =>
            map(s -> "internal/$(s)", sort(readdir(joinpath(@__DIR__, "src/internal")))),
    ],
)

deploydocs(; repo = "github.com/loti45/FlowGenerator.jl", devbranch = "main")
