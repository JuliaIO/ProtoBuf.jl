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

jl_typename(::DoubleType, ::Context)   = "Float64"
jl_typename(::FloatType, ::Context)    = "Float32"
jl_typename(::Int32Type, ::Context)    = "Int32"
jl_typename(::Int64Type, ::Context)    = "Int64"
jl_typename(::UInt32Type, ::Context)   = "UInt32"
jl_typename(::UInt64Type, ::Context)   = "UInt64"
jl_typename(::SInt32Type, ::Context)   = "Int32"
jl_typename(::SInt64Type, ::Context)   = "Int64"
jl_typename(::Fixed32Type, ::Context)  = "UInt32"
jl_typename(::Fixed64Type, ::Context)  = "UInt64"
jl_typename(::SFixed32Type, ::Context) = "Int32"
jl_typename(::SFixed64Type, ::Context) = "Int64"
jl_typename(::BoolType, ::Context)     = "Bool"
jl_typename(::StringType, ::Context)   = "String"
jl_typename(::BytesType, ::Context)    = "Vector{UInt8}"
jl_typename(t::MessageType, ::Context) = safename(t)
function jl_typename(t::MapType, ctx::Context)
    key_type = jl_typename(t.keytype, ctx)
    val_type = jl_typename(t.valuetype, ctx)
    return string("Dict{", key_type, ',', val_type,"}")
end
function jl_typename(t::ReferencedType, ctx::Context)
    # Assessing the type makes sure we search for the reference in imports
    # and populate the resolved_package field.
    @assert t.resolved "Reference to $(t.name) not resolved."
    name = safename(t)
    if !isnothing(t.package_namespace)
        name = string(t.package_namespace, '.', name)
    end
    # References to enum types need to have a `.T` suffix as were using EnumX.jl
    _is_enum(t, ctx) && (name = string(name, ".T"))
    return name
end

function jl_typename(t::OneOfType, ctx::Context)
    return string("OneOf{", _jl_oneof_inner_typename(t, ctx), "}")
end

function _jl_oneof_inner_typename(t::OneOfType, ctx::Context)
    union_types = unique!([jl_typename(f.type, ctx) for f in t.fields])
    return length(union_types) == 1 ? only(union_types) : string("Union{", join(union_types, ','), '}')
end

# TODO: should we store the definition within the referenced type itself?
# we need this to find the first value of enums...
function _get_referenced_type(t::ReferencedType, ctx::Context)
    @assert t.resolved "Reference to $(t.name) not resolved."
    if isnothing(t.package_import_path)
        return ctx.proto_file.definitions[t.name]
    else
        return ctx.file_map[t.package_import_path].proto_file.definitions[t.name]
    end
end

_is_message(t::ReferencedType, ctx::Context) = t.reference_type == Parsers.MESSAGE
_is_enum(t::ReferencedType, ctx::Context)    = t.reference_type == Parsers.ENUM

_is_cyclic_reference(t, ::Context) = false
_is_cyclic_reference(t::ReferencedType, ctx::Context) = t.name in ctx.proto_file.cyclic_definitions || t.name == ctx._toplevel_name[]

_needs_type_params(f::FieldType{ReferencedType}, ctx::Context) = f.type.name in ctx._curr_cyclic_defs && f.type.name != ctx._toplevel_name[]
_needs_type_params(::FieldType, ctx::Context) = false
_needs_type_params(::OneOfType, ctx::Context) = ctx.options.parametrize_oneofs
_needs_type_params(f::GroupType, ctx::Context) = f.name in ctx._curr_cyclic_defs
function _needs_type_params(f::FieldType{MapType}, ctx::Context)
    if isa(f.type.valuetype, ReferencedType)
        return f.type.valuetype.name in ctx._curr_cyclic_defs && f.type.valuetype.name != ctx._toplevel_name[]
    end
    return false
end

_get_type_bound(f::FieldType{ReferencedType}, ::Context) = string("Union{Nothing,", abstract_type_name(f.type.name), '}')
_get_type_bound(f::GroupType, ::Context) = string("Union{Nothing,", abstract_type_name(f.type.name), '}')
_get_type_bound(f::FieldType{MapType}, ::Context) = string("Union{Nothing,", abstract_type_name(f.type.valuetype.name), '}')
function _get_type_bound(f::OneOfType, ctx::Context)
    seen = Dict{String,Nothing}()
    struct_name = ctx._toplevel_name[]
    union_types = String[]
    for o in f.fields
        name = jl_typename(o.type, ctx)
        get!(seen, name) do
            push!(union_types, _is_cyclic_reference(o.type, ctx) ? abstract_type_name(_get_name(o.type)) : name)
            nothing
        end
    end
    should_force_required = _should_force_required(string(struct_name, ".", f.name), ctx)
    if length(union_types) == 1
        type = string("OneOf{", only(union_types), '}')
    else
        type = string("OneOf{<:Union{", join(union_types, ','), "}}")
    end
    if !should_force_required
        type = string("Union{Nothing,", type, '}')
    end
    return type
end

function _maybe_subtype(name)
    isempty(name) && return ""
    return string(" <: ", abstract_type_name(name))
end

function get_type_params(t::MessageType, ctx::Context)
    out = (field.name => _get_type_bound(field, ctx) for field in t.fields if _needs_type_params(field, ctx))
    i = 0
    type_params = Dict{String,ParamMetadata}()
    for field in t.fields
        !_needs_type_params(field, ctx) && continue
        i += 1
        type_params[field.name] = ParamMetadata(string("T", i), _get_type_bound(field, ctx))
    end
    return type_params
end

function get_type_param_string(type_params)
    isempty(type_params) && return ""
    return string('{', join(Iterators.map(x->string(x.param, "<:", x.bound), values(type_params)), ','), '}')
end