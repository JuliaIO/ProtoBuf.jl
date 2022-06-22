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
jl_typename(t::MessageType, ctx) = safename(t.name, ctx) #TODO: the method with ctx is probably useless
function jl_typename(t::MapType, ctx)
    key_type = jl_typename(t.keytype, ctx)
    val_type = jl_typename(t.valuetype, ctx)
    return string("Dict{", key_type, ',', val_type,"}")
end
function jl_typename(t::ReferencedType, ctx)
    name = safename(t.name)
    # TODO: explain the confusion between enclosing type and package
    if !isempty(t.package) && isnothing(t.enclosing_type) && t.package != namespace(ctx.proto_file)
        name = string(proto_module_name(t.package), '.', name)
    end
    # This is where EnumX.jl bites us -- we need to search through all defitnition (including imported)
    # to make sure a ReferencedType is an Enum, in which case we need to add a `.T` suffix.
    _get_referenced_type_type!(t, ctx) == "enum" && return string(name, ".T")
    return name
end
# NOTE: If there is a self-reference to the parent type, we might get
#       a Union{..., Union{Nothing,parentType}, ...}. This is probably ok?
function jl_typename(t::OneOfType, ctx)
    return string("OneOf{", _jl_inner_typename(t, ctx), "}")
end

function _jl_inner_typename(t::OneOfType, ctx)
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

function _get_referenced_type_type!(t::ReferencedType, ctx)
    if isempty(t.type_name)
        def = _search_imports(ctx.proto_file, ctx.file_map, t)
        isnothing(def) && error("Referenced type `$(t)` not found in any imported package ('$(join(union(ctx.imports, [namespace(ctx.proto_file)]), "', '"))').")
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

_needs_type_params(f::FieldType{ReferencedType}, ctx) = f.type.name in ctx._curr_cyclic_defs
_needs_type_params(f::FieldType, ctx) = false
_needs_type_params(f::OneOfType, ctx) = true
_needs_type_params(f::GroupType, ctx) = f.name in ctx._curr_cyclic_defs

_get_type_bound(f::FieldType{ReferencedType}, ctx) = abstract_type_name(f.type.name)
_get_type_bound(f::OneOfType, ctx) = _jl_inner_typename(f, ctx) # TODO: handle mutually recursive types in OneOf!
_get_type_bound(f::GroupType, ctx) = abstract_type_name(f.name)

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