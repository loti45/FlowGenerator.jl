using FlowGenerator
using Documenter

DocMeta.setdocmeta!(FlowGenerator, :DocTestSetup, :(using FlowGenerator); recursive=true)

makedocs(;
    modules=[FlowGenerator],
    authors="Vinicius Loti de Lima",
    sitename="FlowGenerator.jl",
    format=Documenter.HTML(;
        canonical="https://loti45.github.io/FlowGenerator.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/loti45/FlowGenerator.jl",
    devbranch="main",
)
