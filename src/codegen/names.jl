const JULIA_RESERVED_KEYWORDS = Set{String}([
    "abstract",
    "Any",
    "Array",
    "baremodule",
    "Base",
    "begin",
    "bitstype",
    "break",
    "catch",
    "ccall",
    "const",
    "continue",
    "DataType",
    "Dict",
    "do",
    "else",
    "elseif",
    "end",
    "Enum",
    "export",
    "Expr",
    "false",
    "finally",
    "for",
    "function",
    "global",
    "if",
    "immutable",
    "import",
    "importall",
    "let",
    "local",
    "macro",
    "Method",
    "module",
    "OneOf",
    "quote",
    "return",
    "Set",
    "struct",
    "true",
    "try",
    "type",
    "Type",
    "typealias",
    "Union",
    "using",
    "Vector",
    "while",
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

abstract_type_name(name::AbstractString) = string("var\"##Abstract#", name, "\"")

jl_fieldname(@nospecialize(f::AbstractProtoFieldType)) = _safename(f.name)
jl_fieldname(f::GroupType) = _safename(f.field_name)

_safe_namespace_string(ns::AbstractVector{<:AbstractString}) = string("var\"#$(first(ns))\"", '.', join(@view(ns[2:end]), '.'))

stub_name(x) = string("var\"##Stub#", x, "\"")
