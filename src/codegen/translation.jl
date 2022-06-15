const JULIA_RESERVED_KEYWORDS = Set{String}([
    "baremodule", "begin", "break", "catch", "const", "continue", "do", "else", "elseif", "end",
    "export", "false", "finally", "for", "function", "global", "if", "import", "let", "local",
    "macro", "module", "quote", "return", "struct", "true", "try", "using", "while",
    "abstract", "ccall", "typealias", "type", "bitstype", "importall", "immutable", "Type", "Enum",
    "Any", "DataType", "Base", "Core", "InteractiveUtils", "Set", "Method", "include", "eval", "ans",
    # TODO: add all subtypes(Any) from a fresh julia session?
    "PB", "OneOf", "Nothing", "Vector", "zero"
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

function _is_message(t::Parsers.ReferencedType, ctx)
    isa(get(ctx.proto_file.definitions, t.name, nothing), Parsers.MessageType) && return true
    lookup_name = try_strip_namespace(t.name, ctx.imports)
    for path in import_paths(ctx.proto_file)
        defs = ctx.file_map[path].proto_file.definitions
        isa(get(defs, lookup_name, nothing), Parsers.MessageType) && return true
    end
    return false
end

function _is_enum(t::Parsers.ReferencedType, ctx)
    isa(get(ctx.proto_file.definitions, t.name, nothing), Parsers.EnumType) && return true
    lookup_name = try_strip_namespace(t.name, ctx.imports)
    for path in import_paths(ctx.proto_file)
        defs = ctx.file_map[path].proto_file.definitions
        isa(get(defs, lookup_name, nothing), Parsers.EnumType) && return true
    end
    return false
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

_is_repeated_field(f::Parsers.AbstractProtoFieldType) = f.label == Parsers.REPEATED
_is_repeated_field(::Parsers.OneOfType) = false

function jl_decode_default(io, field::Parsers.FieldType, ctx)
    name = jl_fieldname(field)
    if _is_repeated_field(field)
        def_value = "$(jl_typename(field.type, ctx))[]"
    else
        def_value = jl_type_default(field, field.type, ctx)
    end
    println(io, "    ", name, " = ", def_value)
end
jl_type_default(f, ::Parsers.BytesType, ctx)                 = get(f.options, "default", "UInt8[]")
jl_type_default(f, ::Parsers.StringType, ctx)                = get(f.options, "default", "\"\"")
jl_type_default(f, ::Parsers.BoolType, ctx)                  = get(f.options, "default", "false")
jl_type_default(f, t::Parsers.AbstractProtoNumericType, ctx) = get(f.options, "default", "zero($(jl_typename(t, ctx)))")
function jl_type_default(f, t::Parsers.ReferencedType, ctx)
    if _is_enum(t, ctx)
        default = get(f.options, "default", "0")
        if default == "0"
            return "$(jl_typename(t, ctx))(0)"
        else
            return "$(jl_typename(t, ctx)[1:end-2]).$(default)"
        end
    else
        return get(f.options, "default", "nothing")
    end
end
# end
function jl_type_default(f, t::Parsers.MapType, ctx)
    return "Dict{$(jl_typename(t.keytype, ctx)),$(jl_typename(t.valuetype, ctx))}()"
end
function jl_decode_default(io, field::Parsers.OneOfType, ctx)
    println(io, "    ", jl_fieldname(field), " = nothing")
end
function jl_decode_default(io, field::Parsers.GroupType, ctx)
    if _is_repeated_field(field)
        println(io, "    ", jl_fieldname(field), " = $(field.type.name)[]")
    else
        println(io, "    ", jl_fieldname(field), " = nothing")
    end
end

jl_type_decode_expr(f, t::Parsers.AbstractProtoType, ctx) = "$(jl_fieldname(f)) = PB.decode(d, $(jl_typename(t, ctx)))"
jl_type_decode_expr(f, ::Parsers.SFixed32Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int32, Val(:fixed))"
jl_type_decode_expr(f, ::Parsers.SFixed64Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int64, Val(:fixed))"
jl_type_decode_expr(f, ::Parsers.Fixed32Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int32, Val(:fixed))"
jl_type_decode_expr(f, ::Parsers.Fixed64Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int64, Val(:fixed))"
jl_type_decode_expr(f, ::Parsers.SInt32Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int32, Val(:zigzag))"
jl_type_decode_expr(f, ::Parsers.SInt64Type, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int64, Val(:zigzag))"
jl_type_decode_expr(f, ::Parsers.MapType, ctx) = "PB.decode!(d, $(jl_fieldname(f)), $(jl_typename(f, ctx)))"
function jl_type_decode_repeated_expr(field, ctx)
    # We set `packed` to true for proto3 numeric types during option parsing
    is_packed = parse(Bool, get(field.options, "packed", "false"))
    type_name = jl_typename(field.type, ctx)
    is_packed && (type_name = string("Vector{", type_name, "}"))
    return "PB.decode!(d, $(jl_fieldname(field)), $(type_name))"
end
function jl_type_decode_expr(f, t::Parsers.ReferencedType, ctx)
    _is_message(t, ctx) && return "$(jl_fieldname(f)) = PB.decode_message(d, $(jl_fieldname(f)))"
    return "$(jl_fieldname(f)) = PB.decode(d, $(jl_typename(t, ctx)))"
end

function field_decode_expr(io, field::Parsers.FieldType, i, ctx)
    if _is_repeated_field(field)
        decode_expr = jl_type_decode_repeated_expr(field, ctx)
    else
        decode_expr = jl_type_decode_expr(field, field.type, ctx)
    end
    println(io, "    " ^ 2, i == 1 ? "if " : "elseif ", "field_number == ", field.number)
    println(io, "    " ^ 3, decode_expr)
    return nothing
end

jl_type_oneof_decode_expr(f, t, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, $(jl_typename(t, ctx))))"
jl_type_oneof_decode_expr(f, ::Parsers.SFixed32Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int32, Val(:fixed)))"
jl_type_oneof_decode_expr(f, ::Parsers.SFixed64Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int64, Val(:fixed)))"
jl_type_oneof_decode_expr(f, ::Parsers.Fixed32Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int32, Val(:fixed)))"
jl_type_oneof_decode_expr(f, ::Parsers.Fixed64Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int64, Val(:fixed)))"
jl_type_oneof_decode_expr(f, ::Parsers.SInt32Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int32, Val(:zigzag)))"
jl_type_oneof_decode_expr(f, ::Parsers.SInt64Type, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int64, Val(:zigzag)))"
# function jl_type_decode_expr(f, t::Parsers.ReferencedType, ctx)
#     _is_message(t, ctx) && return "OneOf(:$(jl_fieldname(f)),PB.decode_message(d, $(jl_fieldname(f))))"
#     return "OneOf(:$(jl_fieldname(f)), PB.decode(d, $(jl_typename(t, ctx))))"
# end
function field_decode_expr(io, field::Parsers.OneOfType, i, ctx)
    field_name = jl_fieldname(field)
    for (j, case) in enumerate(field.fields)
        j += i
        println(io, "    " ^ 2, j == 2 ? "if " : "elseif ", "field_number == ", case.number)
        println(io, "    " ^ 3, field_name, " = ", jl_type_oneof_decode_expr(case, case.type, ctx))
    end
    return nothing
end

function field_decode_expr(io, field::Parsers.GroupType, i, ctx)
    field_name = jl_fieldname(field)
    println(io, "    " ^ 2, i == 1 ? "if " : "elseif ", "field_number == ", field.number)
    println(io, "    " ^ 3, field_name, " = PB.decode_message(d, ", field_name, ")")
    return nothing
end

function generate_decode_method(io, t::Parsers.MessageType, ctx)
    println(io, "function PB.decode(d::PB.ProtoDecoder, ::Type{$(t.name)})")
    # defaults
    for field in t.fields
        jl_decode_default(io, field, ctx)
    end
    println(io, "    while !PB.message_done(d)")
    println(io, "        field_number, wire_type = PB.decode_tag(d)")
    for (i, field) in enumerate(t.fields)
        field_decode_expr(io, field, i, ctx)
    end
    println(io, "        else")
    println(io, "            PB.skip(d, wire_type)")
    println(io, "        end")
    println(io, "        PB.try_eat_end_group(d, wire_type)")
    println(io, "    end")
    print(io, "    return ", jl_typename(t, ctx), "(")
    print(io, join(map(jl_fieldname, t.fields), ", "))
    println(io, ")")
    println(io, "end")
end


function generate_struct_field(io, field, struct_name, ctx)
    field_name = jl_fieldname(field)
    type_name = jl_typename(field, ctx)
    # When a field type is self-referential, we'll use Nothing to signal
    # the bottom of the recursion. Note that we don't have to do this
    # for repeated (`Vector{...}`) types; at this point `type_name`
    # is already a vector if if the field was repeated.
    struct_name == type_name && (type_name = string("Union{Nothing,", type_name,"}"))
    isa(field, Parsers.OneOfType) && (type_name = string("Union{Nothing,", type_name,"}"))
    println(io, "    ", field_name, "::", type_name)
end

codegen(t::Parsers.AbstractProtoType, ctx::Context) = codegen(stdin, t, ctx::Context)

function codegen(io, t::Parsers.MessageType, ctx::Context)
    struct_name = safename(t.name)
    print(io, "struct ", struct_name, length(t.fields) > 0 ? "" : ' ')
    length(t.fields) > 0 && println(io)
    for field in t.fields
        generate_struct_field(io, field, struct_name, ctx)
    end
    println(io, "end")
    if !isempty(t.fields)
        generate_decode_method(io, t, ctx)
    end
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
    println(io, "import ProtocolBuffers as PB")
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