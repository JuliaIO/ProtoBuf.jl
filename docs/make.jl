using Documenter
using ProtocolBuffers

makedocs(
    sitename = "ProtocolBuffers.jl",
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
    repo = "github.com/Drvi/ProtocolBuffers.jl.git",
    push_preview = true,
)