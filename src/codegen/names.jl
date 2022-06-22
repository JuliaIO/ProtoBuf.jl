const JULIA_RESERVED_KEYWORDS = Set{String}([
    "baremodule", "begin", "break", "catch", "const", "continue", "do", "else", "elseif", "end",
    "export", "false", "finally", "for", "function", "global", "if", "import", "let", "local",
    "macro", "module", "quote", "return", "struct", "true", "try", "using", "while",
    "abstract", "ccall", "typealias", "type", "bitstype", "importall", "immutable", "Type", "Enum",
    "Any", "DataType", "Base", "Core", "InteractiveUtils", "Set", "Method", "include", "eval", "ans",
    # TODO: add all subtypes(Any) from a fresh julia session?
    "PB", "OneOf", "Nothing", "Vector", "zero", "isempty", "isnothing", "Ref",
])


function safename(name::AbstractString, ctx)
    for _import in ctx.imports
        if startswith(name, "$(_import).")
            namespaced_name = @view name[nextind(name, length(_import), 2):end]
            return string(proto_module_name(_import), '.', safename(namespaced_name))
        end
    end
    return safename(name)
end

function safename(name::AbstractString)
    # TODO: handle namespaced definitions (pkg_name.MessageType)
    dot_pos = findfirst(==('.'), name)
    if name in JULIA_RESERVED_KEYWORDS
        return string("var\"#", name, '"')
    elseif isnothing(dot_pos) && !('#' in name)
        return name
    elseif dot_pos == 1
        return string("@__MODULE__.", safename(@view name[2:end]))
    else
        return string("var\"", name, '"')
    end
end

function abstract_type_name(name::AbstractString)
    return string("var\"##Abstract", name, '"')
end

jl_fieldname(f::AbstractProtoFieldType) = safename(f.name)
jl_fieldname(f::GroupType) = safename(f.field_name)