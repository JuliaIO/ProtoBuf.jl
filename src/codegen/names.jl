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
abstract_tagged_oneof_type_name(field::OneOfType, ctx::Context) = abstract_tagged_oneof_type_name(field.name, ctx._toplevel_raw_name[])
abstract_tagged_oneof_type_name(field::AbstractString, ctx::Context) = abstract_tagged_oneof_type_name(field, ctx._toplevel_raw_name[])
function abstract_tagged_oneof_type_name(field::AbstractString, parent::AbstractString)
    string("var\"##Abstract#", parent, ".", replace(titlecase(field), "_"=>""), "\"")
end

jl_fieldname(@nospecialize(f::AbstractProtoFieldType)) = _safename(f.name)
jl_fieldname(f::GroupType) = _safename(f.field_name)

jl_tagged_type_name(field::OneOfType, parent) = string("var\"", parent, ".", replace(titlecase(field.name), "_"=>""), "\"")
jl_tagged_type_name(fieldname::AbstractString, parent) = string("var\"", parent, ".", replace(titlecase(fieldname), "_"=>""), "\"")
jl_tagged_type_name(field::OneOfType, ctx::Context) = string("var\"", ctx._toplevel_raw_name[], ".", replace(titlecase(field.name), "_"=>""), "\"")

_safe_namespace_string(ns::AbstractVector{<:AbstractString}) = string("var\"#$(first(ns))\"", '.', join(@view(ns[2:end]), '.'))

stub_type_name(x) = string("var\"##Stub#", x, "\"")
