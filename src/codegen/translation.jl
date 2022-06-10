const JULIA_RESERVED_KEYWORDS = Set{String}([
    "baremodule", "begin", "break", "catch", "const", "continue", "do", "else", "elseif", "end",
    "export", "false", "finally", "for", "function", "global", "if", "import", "let", "local",
    "macro", "module", "quote", "return", "struct", "true", "try", "using", "while",
    "abstract", "ccall", "typealias", "type", "bitstype", "importall", "immutable", "Type", "Enum",
    "Any", "DataType", "Base", "Core", "InteractiveUtils", "Set", "Method", "include", "eval", "ans",
    # TODO: add all subtypes(Any) from a fresh julia session?
    "OneOf", "Nothing", "Vector",
])

struct Context
    proto_file::ProtoFile
    imports::Set{String}
    file_map::Dict{String,ResolvedProtoFile}
end

function try_strip_namespace(name::AbstractString, imports::Set{String})
    for _import in imports
        if startswith(name, "$(_import).")
            return @view name[nextind(name, length(_import), 2):end]
        end
    end
    return name
end

function safename(name::AbstractString, imports::Set{String})
    for _import in imports
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

# function translate_import_path(p::ResolvedProtoFile)
#     assumed_file_relpath = joinpath(replace(p.preamble.namespace, '.' => '/'), "")
#     relpaths = String[]
#     for i in p.proto_file.preamble.::
#         rel_path_to_module = relpath(dirname(i.path), assumed_file_relpath)
#         translated_module_name = proto_module_name(i.path)
#         push!(relpaths, joinpath(rel_path_to_module, translated_module_name))
#     end
#     return relpaths
# end

codegen(t::Parsers.AbstractProtoType, ctx::Context) = codegen(stdin, t, ctx::Context)

_is_repeated_field(f::Parsers.AbstractProtoFieldType) = f.label == Parsers.REPEATED
_is_repeated_field(::Parsers.OneOfType) = false

function generate_struct_field(io, field, struct_name, ctx)
    field_name = jl_fieldname(field)
    type_name = jl_typename(field, ctx)
    # When a field type is self-referential, we'll use Nothing to signal
    # the bottom of the recursion. Note that we don't have to do this
    # for repeated (`Vector{...}`) types; at this point `type_name`
    # is already a vector if if the field was repeated.
    struct_name == type_name && (type_name = string("Union{Nothing,", type_name,"}"))
    println(io, "    ", field_name, "::", type_name)
end

function codegen(io, t::Parsers.MessageType, ctx::Context)
    struct_name = safename(t.name)
    print(io, "struct ", struct_name, length(t.fields) > 0 ? "" : ' ')
    length(t.fields) > 0 && println(io)
    for field in t.fields
        generate_struct_field(io, field, struct_name, ctx)
    end
    println(io, "end")
end

codegen(io, t::Parsers.GroupType, ctx::Context) = codegen(io, t.type, ctx)

function codegen(io, t::Parsers.EnumType, ::Context)
    name = safename(t.name)
    println(io, "@enumx ", name, join(" $k=$n" for (k, n) in zip(keys(t.elements), t.elements)))
end

function codegen(io, t::Parsers.ServiceType, ::Context)
    println(io, "# TODO: SERVICE")
    println(io, "#    ", t)
end

jl_fieldname(f::Parsers.AbstractProtoFieldType) = safename(f.name)
jl_fieldname(f::Parsers.GroupType) = f.field_name

function jl_typename(f::Parsers.AbstractProtoFieldType, ctx)
    type_name = jl_typename(f.type, ctx)
    if _is_repeated_field(f)
        return string("Vector{", type_name, "}")
    end
    return type_name
end

jl_typename(::Parsers.DoubleType, ctx)   = "Float64"
jl_typename(::Parsers.FloatType, ctx)    = "Float32"
jl_typename(::Parsers.Int32Type, ctx)    = "Int32"
jl_typename(::Parsers.Int64Type, ctx)    = "Int64"
jl_typename(::Parsers.UInt32Type, ctx)   = "UInt32"
jl_typename(::Parsers.UInt64Type, ctx)   = "UInt64"
jl_typename(::Parsers.SInt32Type, ctx)   = "Int32"
jl_typename(::Parsers.SInt64Type, ctx)   = "Int64"
jl_typename(::Parsers.Fixed32Type, ctx)  = "UInt32"
jl_typename(::Parsers.Fixed64Type, ctx)  = "UInt64"
jl_typename(::Parsers.SFixed32Type, ctx) = "Int32"
jl_typename(::Parsers.SFixed64Type, ctx) = "Int64"
jl_typename(::Parsers.BoolType, ctx)     = "Bool"
jl_typename(::Parsers.StringType, ctx)   = "String"
jl_typename(::Parsers.BytesType, ctx)    = "Vector{UInt8}"

jl_typename(t::Parsers.MessageType, ctx) = safename(t.name, ctx.imports)

function jl_typename(t::Parsers.MapType, ctx)
    key_type = jl_typename(t.keytype, ctx)
    val_type = jl_typename(t.valuetype, ctx)
    return string("Dict{", key_type, ',', val_type,"}")
end
function jl_typename(t::Parsers.ReferencedType, ctx)
    name = safename(t.name, ctx.imports)
    # This is where EnumX.jl bites us -- we need to search through all defitnition (including imported)
    # to make sure a ReferencedType is an Enum, in which case we need to add a `.T` suffix.
    isa(get(ctx.proto_file.definitions, t.name, nothing), Parsers.EnumType) && return string(name, ".T")
    lookup_name = try_strip_namespace(t.name, ctx.imports)
    for path in import_paths(ctx.proto_file)
        defs = ctx.file_map[path].proto_file.definitions
        isa(get(defs, lookup_name, nothing), Parsers.EnumType) && return string(name, ".T")
    end
    return name
end
# TODO: Allow (via options?) to be the parent struct parametrized on the type of OneOf
#       Parent structs should be then be parametrized as well?
# NOTE: If there is a self-reference to the parent type, we might get
#       a Union{..., Union{Nothing,parentType}, ...}. This is probably ok?
function jl_typename(t::Parsers.OneOfType, ctx)
    union_types = unique!([jl_typename(f.type, ctx) for f in t.fields])
    if length(union_types) > 1
        return string("OneOf{Union{", join(union_types, ','), "}}")
    else
        return string("OneOf{", only(union_types), "}")
    end
end

function translate(path::String, rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile})
    open(path, "w") do io
        translate(io, rp, file_map)
    end
end

translate(rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile}) = translate(stdin, rp, file_map)
function translate(io, rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile})
    pkg_metadata = Pkg.project()
    p = rp.proto_file
    imports = Set{String}(Iterators.map(i->namespace(file_map[i]), import_paths(p)))
    println(io, "# Autogenerated using $(pkg_metadata.name).jl v$(pkg_metadata.version) on $(Dates.now())")
    println(io, "# original file: ", p.filepath," (proto", p.preamble.isproto3 ? '3' : '2', " syntax)")
    println(io)

    ctx = Context(p, imports, file_map)
    if !is_namespaced(p)
        # if current file is not namespaced, it will not live in a module
        # and will need to import its dependencies directly.
        for path in import_paths(p)
            dependency = file_map[path]
            if !is_namespaced(dependency)
                # if the dependency is also not namespaced, we can just include it
                println(io, "include(", repr(proto_script_name(dependency)), ")")
            else
                # otherwise we need to import it trough a module
                println(io, "include(", repr(proto_module_name(dependency)), ")")
                println(io, "using ", proto_module_name(dependency))
            end
        end
    end # Otherwise all includes will happen in the enclosing module
    println(io, "using ProtocolBuffers: OneOf")
    println(io, "using EnumX: @enumx")
    if is_namespaced(p)
        println(io)
        println(io, "export ", join(Iterators.map(x->safename(x, imports), keys(p.definitions)), ", "))
    end
    println(io)
    for def_name in p.sorted_definitions
        println(io)
        codegen(io, p.definitions[def_name], ctx)
    end
end