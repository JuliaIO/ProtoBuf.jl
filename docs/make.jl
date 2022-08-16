using Documenter
using ProtoBuf

makedocs(
    sitename = "ProtoBuf.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages = [
        "Home" => "index.md",
        "Reference" => "reference.md",
        "FAQ" => "faq.md",
    ],
)

deploydocs(
    repo = "github.com/JuliaIO/ProtoBuf.jl.git",
    push_preview = true,
)