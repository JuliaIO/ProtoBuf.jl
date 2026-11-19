const JULIA_RESERVED_KEYWORDS = Set{String}([
    "abstract",
    "AbstractProtoBufMessage",
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

# Names that a generated `PB.decode` method binds or reads besides its field locals: its arguments
# and locals, the `PB` alias, and the Base names in its initial values, decode calls, and return.
# A field local with one of these names would shadow it, so the local becomes `var"##name"`.
# `_safename` already escapes `Base`, `OneOf`, `Union`, `Vector`, and `Dict`.
const DECODE_METHOD_NAMES = Set{String}([
    "_endpos", "_group", "d", "field_number", "wire_type",
    "Bool", "Float32", "Float64", "Inf", "Int32", "Int64", "NaN", "Nothing", "PB", "Ref",
    "String", "Tuple", "UInt32", "UInt64", "UInt8", "Val", "nothing", "typeof", "zero",
])

_decode_local(jl_name::String) = jl_name in DECODE_METHOD_NAMES ? string("var\"##", jl_name, '"') : jl_name
jl_decode_local(@nospecialize(f::AbstractProtoFieldType)) = _decode_local(jl_fieldname(f))

_safe_namespace_string(ns::AbstractVector{<:AbstractString}) = string("var\"#$(first(ns))\"", '.', join(@view(ns[2:end]), '.'))

stub_type_name(x) = string("var\"##Stub#", x, "\"")
