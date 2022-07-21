#TODO: Cleanup!
struct ParamMetadata
    param::String
    bound::String
end

function jl_typename(f::AbstractProtoFieldType, ctx)
    type_name = jl_typename(f.type, ctx)
    if _is_repeated_field(f)
        return string("Vector{", type_name, "}")
    end
    return type_name
end

jl_typename(::DoubleType, ctx)   = "Float64"
jl_typename(::FloatType, ctx)    = "Float32"
jl_typename(::Int32Type, ctx)    = "Int32"
jl_typename(::Int64Type, ctx)    = "Int64"
jl_typename(::UInt32Type, ctx)   = "UInt32"
jl_typename(::UInt64Type, ctx)   = "UInt64"
jl_typename(::SInt32Type, ctx)   = "Int32"
jl_typename(::SInt64Type, ctx)   = "Int64"
jl_typename(::Fixed32Type, ctx)  = "UInt32"
jl_typename(::Fixed64Type, ctx)  = "UInt64"
jl_typename(::SFixed32Type, ctx) = "Int32"
jl_typename(::SFixed64Type, ctx) = "Int64"
jl_typename(::BoolType, ctx)     = "Bool"
jl_typename(::StringType, ctx)   = "String"
jl_typename(::BytesType, ctx)    = "Vector{UInt8}"
jl_typename(t::MessageType, ctx) = safename(t)
function jl_typename(t::MapType, ctx)
    key_type = jl_typename(t.keytype, ctx)
    val_type = jl_typename(t.valuetype, ctx)
    return string("Dict{", key_type, ',', val_type,"}")
end
function jl_typename(t::ReferencedType, ctx)
    name = safename(t)
    # The identifier might have been prefixed with either the name of the enclosing type
    # or with the module it was defined in. Here we determine whether the namespace is
    # actually a package and if it is, we prefix the safename of the type with it.
    if !(isempty(t.namespace) || !isnothing(t.enclosing_type) || t.namespace_is_type || t.namespace == namespace(ctx.proto_file))
        import_chain = mapreduce(proto_module_name, (x, y)->join((x, y), '.'), split(t.namespace, '.'))
        name = string(import_chain, '.', name)
    end
    # This is where EnumX.jl bites us -- we need to search through all defitnition (including imported)
    # to make sure a ReferencedType is an Enum, in which case we need to add a `.T` suffix.
    _get_referenced_type_type!(t, ctx) == "enum" && return string(name, ".T")
    return name
end
# NOTE: If there is a self-reference to the parent type, we might get
#       a Union{..., Union{Nothing,parentType}, ...}. This is probably ok?
function jl_typename(t::OneOfType, ctx)
    return string("OneOf{", _jl_oneof_inner_typename(t, ctx), "}")
end

function _jl_oneof_inner_typename(t::OneOfType, ctx)
    union_types = unique!([jl_typename(f.type, ctx) for f in t.fields])
    return length(union_types) == 1 ? only(union_types) : string("Union{", join(union_types, ','), '}')
end

function _search_imports(proto_file::ProtoFile, file_map, t::ReferencedType, depth=0)
    def = get(proto_file.definitions, t.name, nothing)
    !isnothing(def) && return def
    for _import in proto_file.preamble.imports
        ((depth > 1) && _import.import_option != Parsers.PUBLIC) && continue
        def = _search_imports(file_map[_import.path].proto_file, file_map, t, depth+1)
        !isnothing(def) && return def
    end
end

# TODO: should we store the definition within the referenced type itself?
# we need this to find the first value of enums...
function _get_referenced_type(t::ReferencedType, ctx)
    def = _search_imports(ctx.proto_file, ctx.file_map, t)
    isnothing(def) && error("Referenced type `$(t)` not found in any imported package ('$(join(union(ctx.imports, [namespace(ctx.proto_file)]), "', '"))').")
    return def
end

function _get_referenced_type_type!(t::ReferencedType, ctx)
    if isempty(t.type_name)
        def = _get_referenced_type(t, ctx)
        if isa(def, MessageType)
            t.type_name = "message"
        elseif isa(def, EnumType)
            t.type_name = "enum"
        elseif isa(def, ServiceType)
            t.type_name = "service"
        elseif isa(def, RPCType)
            t.type_name = "rpc"
        else
            error("Referenced type `$(t.name)` has unsupported type $(typeof(def))")
        end
    end
    return t.type_name
end

_is_message(t::ReferencedType, ctx) = _get_referenced_type_type!(t, ctx) == "message"
_is_enum(t::ReferencedType, ctx)    = _get_referenced_type_type!(t, ctx) == "enum"

_needs_type_params(f::FieldType{ReferencedType}, ctx) = f.type.name in ctx._curr_cyclic_defs && f.type.name != ctx._toplevel_name[]
_needs_type_params(f::FieldType, ctx) = false
_needs_type_params(f::OneOfType, ctx) = true
_needs_type_params(f::GroupType, ctx) = f.name in ctx._curr_cyclic_defs
function _needs_type_params(f::FieldType{MapType}, ctx)
    if isa(f.type.valuetype, ReferencedType)
        return f.type.valuetype.name in ctx._curr_cyclic_defs && f.type.valuetype.name != ctx._toplevel_name[]
    end
    return false
end

_get_type_bound(f::FieldType{ReferencedType}, ctx) = string("Union{Nothing,", abstract_type_name(f.type.name), '}')
_get_type_bound(f::GroupType, ctx) = string("Union{Nothing,", abstract_type_name(f.type.name), '}')
_get_type_bound(f::FieldType{MapType}, ctx) = string("Union{Nothing,", abstract_type_name(f.type.valuetype.name), '}')
function _get_type_bound(f::OneOfType, ctx)
    seen = Dict{String,Nothing}()
    union_types = String[]
    for o in f.fields
        name = jl_typename(o.type, ctx)
        get!(seen, name) do
            push!(union_types, name in ctx._curr_cyclic_defs || name == ctx._toplevel_name[] ? abstract_type_name(name) : name)
            nothing
        end
    end
    if length(union_types) == 1
        return string("Union{Nothing,OneOf{", only(union_types), "}}")
    else
        return string("Union{Nothing,OneOf{<:Union{", join(union_types, ','), "}}}")
    end
end

function _maybe_subtype(name)
    isempty(name) && return ""
    return string(" <: ", abstract_type_name(name))
end

function get_type_params(t::MessageType, ctx)
    out = [field.name => _get_type_bound(field, ctx) for field in t.fields if _needs_type_params(field, ctx)]
    type_params = Dict(k => ParamMetadata(string("T", i), v) for (i, (k, v)) in enumerate(out))
    return type_params
end

function get_type_param_string(type_params)
    isempty(type_params) && return ""
    return string('{', join(Iterators.map(x->string(x.param, "<:", x.bound), values(type_params)), ','), '}')
end