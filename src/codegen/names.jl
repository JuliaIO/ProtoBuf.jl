const JULIA_RESERVED_KEYWORDS = Set{String}([
    "if", "else", "elseif", "while", "for", "begin", "end", "quote",
    "try", "catch", "return", "local", "abstract", "function", "macro",
    "ccall", "finally", "typealias", "break", "continue", "type",
    "global", "module", "using", "import", "export", "const", "let",
    "bitstype", "do", "baremodule", "importall", "immutable",
    "Type", "Enum", "Any", "DataType", "Base", "Set", "Method",
    "Array", "Vector", "Dict", "Union",
    "OneOf",
])

_get_name(t::AbstractProtoType) = t.name

safename(t::AbstractProtoType) = _safename(_get_name(t))

function _safename(name::AbstractString)
    dot_pos = findfirst(==('.'), name)
    if name in JULIA_RESERVED_KEYWORDS
        return string("var\"#", name, '"')
    elseif isnothing(dot_pos) && !('#' in name)
        return name
    else
        return string("var\"", name, '"')
    end
end

abstract_type_name(name::AbstractString) = string("var\"##Abstract", name, '"')

jl_fieldname(@nospecialize(f::AbstractProtoFieldType)) = _safename(f.name)
jl_fieldname(f::GroupType) = _safename(f.field_name)

_safe_namespace_string(ns::AbstractVector{<:AbstractString}) = string("var\"#$(first(ns))\"", '.', join(@view(ns[2:end]), '.'))
