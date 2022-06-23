const JULIA_RESERVED_KEYWORDS = Set{String}([
    "baremodule", "begin", "break", "catch", "const", "continue", "do", "else", "elseif", "end",
    "export", "false", "finally", "for", "function", "global", "if", "import", "let", "local",
    "macro", "module", "quote", "return", "struct", "true", "try", "using", "while",
    "abstract", "ccall", "typealias", "type", "bitstype", "importall", "immutable", "Type", "Enum",
    "Any", "DataType", "Base", "Core", "InteractiveUtils", "Set", "Method", "include", "eval", "ans",
    # TODO: add all subtypes(Any) from a fresh julia session?
    "PB", "OneOf", "Nothing", "Vector", "zero", "isempty", "isnothing", "Ref",
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

jl_fieldname(f::AbstractProtoFieldType) = _safename(f.name)
jl_fieldname(f::GroupType) = _safename(f.field_name)