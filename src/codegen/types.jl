_needs_subtyping_in_containers(t::AbstractProtoType, ctx::Context) = false
function _needs_subtyping_in_containers(t::ReferencedType, ctx::Context)
    !_is_message(t, ctx) && return false
    if ctx.options.parametrize_oneofs
        return (_get_referenced_type(t, ctx)::MessageType).has_oneof_field
    end
    return false
end

function jl_typename(f::AbstractProtoFieldType, ctx)
    type_name = jl_typename(f.type, ctx)
    if _is_repeated_field(f)
        return string("Vector{", _needs_subtyping_in_containers(f.type, ctx) ? "<:" : "", type_name, "}")
    end
    return type_name
end

function jl_typename(t::MapType, ctx::Context)
    key_type = jl_typename(t.keytype, ctx)
    val_type = jl_typename(t.valuetype, ctx)
    return string("Dict{", key_type, ',', _needs_subtyping_in_containers(t.valuetype, ctx) ? "<:" : "", val_type,"}")
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
_is_cyclic_reference(t::ReferencedType, ctx::Context) = t.name in ctx.proto_file.cyclic_definitions && t.name != ctx._toplevel_raw_name[]

_needs_type_params(f::FieldType{ReferencedType}, ctx::Context) = __needs_type_params(f.type, ctx)
_needs_type_params(::FieldType,                  ctx::Context) = false
_needs_type_params(::OneOfType,                  ctx::Context) = ctx.options.parametrize_oneofs
_needs_type_params(f::GroupType,                 ctx::Context) = f.name in ctx._remaining_cyclic_defs
_needs_type_params(f::FieldType{MapType},        ctx::Context) = __needs_type_params(f.type.valuetype, ctx) # enums and messages cannot be keys
__needs_type_params(t::ReferencedType,           ctx::Context) = t.name in ctx._remaining_cyclic_defs && t.name != ctx._toplevel_raw_name[]
__needs_type_params(t::AbstractProtoType,        ctx::Context) = false


function types_needing_params(cyclical_names::AbstractVector{String}, proto_file, options)
    field_types_requiring_type_params = Dict{String,Vector{Tuple{Bool,String}}}()
    isempty(cyclical_names) && return field_types_requiring_type_params
    _seen = Set{Tuple{Bool,String}}()
    _cyclical_set = Set{String}(cyclical_names)
    for c in cyclical_names
        deps = Tuple{Bool,String}[]
        _types_needing_params!(deps, field_types_requiring_type_params, proto_file.definitions[c], _cyclical_set, options, c, _seen)
        empty!(_seen)
        pop!(_cyclical_set, c) # remove the current name from the set since it will be defined for all remaining cyclic definitions
        field_types_requiring_type_params[c] = deps
    end
    return field_types_requiring_type_params
end

_types_needing_params!(out, lookup, t::AbstractProtoType,         _cyclical_set, options, self_name, _seen) = nothing
_types_needing_params!(out, lookup, t::FieldType{ReferencedType}, _cyclical_set, options, self_name, _seen) = _types_needing_params!(out, lookup, t.type, _cyclical_set, options, self_name, _seen)
_types_needing_params!(out, lookup, t::MessageType,               _cyclical_set, options, self_name, _seen) = foreach(f->_types_needing_params!(out, lookup, f, _cyclical_set, options, self_name, _seen), t.fields)
_types_needing_params!(out, lookup, t::GroupType,                 _cyclical_set, options, self_name, _seen) = foreach(f->_types_needing_params!(out, lookup, f, _cyclical_set, options, self_name, _seen), t.type.fields)
_types_needing_params!(out, lookup, t::FieldType{MapType},        _cyclical_set, options, self_name, _seen) = _types_needing_params!(out, lookup, t.type.valuetype, _cyclical_set, options, self_name, _seen)
function _types_needing_params!(out, lookup, t::OneOfType, _cyclical_set, options, self_name, _seen)
    if options.parametrize_oneofs
        get!(_seen.dict, (true, t.name)) do
            push!(out, (true, t.name))
            return nothing
        end
    else
        # foreach(f->_types_needing_params!(out, lookup, f.type, _cyclical_set, options, self_name, _seen), t.fields)
    end
end
function _types_needing_params!(out, lookup, t::ReferencedType, _cyclical_set, options, self_name, _seen)
    __types_needing_params!(out, lookup, t.name, _cyclical_set, options, self_name, _seen)
end
function __types_needing_params!(out, lookup, tname, _cyclical_set, options, self_name, _seen)
    tname == self_name && return nothing
    if tname in _cyclical_set
        get!(_seen.dict, (false, tname)) do
            push!(out, (false, tname))
            return nothing
        end
    elseif tname in keys(lookup)
        foreach(f->__types_needing_params!(out, lookup, f[2], _cyclical_set, options, self_name, _seen), lookup[tname])
    end
    return nothing
end

_get_type_bound(f::FieldType{ReferencedType}, ::Context) = abstract_type_name(f.type.name)
_get_type_bound(f::GroupType,                 ::Context) = abstract_type_name(f.type.name)
_get_type_bound(f::FieldType{MapType},        ::Context) = abstract_type_name(f.type.valuetype.name) # enums and messages cannot be keys
function _get_type_bound(f::OneOfType, ctx::Context)
    seen = Set{String}()
    union_types = String[]
    struct_name = ctx._toplevel_raw_name[]
    for o in f.fields
        type_name = jl_typename(o.type, ctx)
        get!(seen.dict, type_name) do
            if o.type isa ReferencedType
                _raw_name = o.type.name
                is_cyclic = _raw_name in keys(ctx._field_types_requiring_type_params)
                is_self_ref = _raw_name == struct_name
                needs_abstract = _raw_name in ctx._remaining_cyclic_defs ||
                    ctx.options.parametrize_oneofs && (is_cyclic || is_self_ref)

                name_in_oneof_union = needs_abstract ?
                    abstract_type_name(_raw_name) :
                    is_cyclic ?
                        stub_name(_raw_name) :
                        type_name
            else
                name_in_oneof_union = type_name
            end
            push!(union_types, name_in_oneof_union)
            return nothing
        end
    end
    if length(union_types) == 1
        type = string("OneOf{", only(union_types), '}')
    else
        type = string("OneOf{<:Union{", join(union_types, ','), "}}")
    end
    return type
end

function _maybe_subtype(name, options)
    isempty(name) && return options.common_abstract_type ? " <: AbstractProtoBufMessage" : ""
    return string(" <: ", abstract_type_name(name))
end

struct ParamMetadata
    param::String
    bound::String
end
struct TypeParams
    references::Dict{String,ParamMetadata}
    oneofs::Dict{String,ParamMetadata}
end
const EMPTY_TYPE_PARAMS = TypeParams(Dict{String,ParamMetadata}(), Dict{String,ParamMetadata}())

function get_type_params_for_non_cyclic(t::MessageType, ctx::Context)
    i = 0
    type_params = TypeParams(EMPTY_TYPE_PARAMS.references, Dict{String,ParamMetadata}())
    !(ctx.options.parametrize_oneofs || t.has_oneof_field) && return type_params
    for field in t.fields
        !(field isa OneOfType) && continue
        i += 1
        param_meta = ParamMetadata(
            string("T", i),
            _get_type_bound(field, ctx),
        )
        type_params.oneofs[field.name] = param_meta
    end
    return type_params
end

function get_type_params_for_cyclic(t::MessageType, ctx::Context)
    i = 0
    type_params = TypeParams(Dict{String,ParamMetadata}(), Dict{String,ParamMetadata}())
    deps = get(ctx._field_types_requiring_type_params, t.name, Tuple{Bool,String}[])

    for (isoneof, dep) in deps
        i += 1
        param = string("T", i)
        if isoneof
            for field in t.fields
                if field.name == dep
                    bound = _get_type_bound(field, ctx)
                    type_param = ParamMetadata(param, bound)
                    type_params.oneofs[dep] = type_param
                    break
                end
            end
        else
            bound = abstract_type_name(dep)
            type_param = ParamMetadata(param, bound)
            type_params.references[dep] = type_param
        end
    end
    return type_params
end

function get_type_param_string(type_params)
    isempty(type_params.references) && isempty(type_params.oneofs) && return ""
    io = IOBuffer()
    buf = String[]
    for p in values(type_params.references)
        push!(buf, string(p.param, "<:", p.bound))
    end
    for p in values(type_params.oneofs)
        push!(buf, string(p.param, "<:", p.bound))
    end
    sort!(buf) # Params are T1, T2, T3, ... so this is easily sorteable
    print(io, "{")
    join(io, buf, ',')
    print(io, "}")
    return String(take!(io))
end

function reconstruct_parametrized_type_name(t::Union{MessageType,ReferencedType}, ctx::Context, type_params::TypeParams=EMPTY_TYPE_PARAMS)
    type_name = t.name
    _field_types_requiring_type_params = ctx._field_types_requiring_type_params
    _remaining_cyclic_defs = ctx._remaining_cyclic_defs
    deps = get(_field_types_requiring_type_params, type_name, nothing)
    isnothing(deps) && return _safename(type_name)
    isempty(deps) && return stub_name(type_name)

    io = IOBuffer()
    print(io, stub_name(type_name))
    print(io, "{")
    _first = true
    # @info type_name _remaining_cyclic_defs type_params.references
    for (isoneof, dep) in deps
        !_first && print(io, ',')
        if dep in _remaining_cyclic_defs                             # dep not defined yet -> use type param
            print(io, type_params.references[dep].param)
        elseif dep in keys(_field_types_requiring_type_params)       # dep is cyclic -> use stubbed name and recurse
            dep_has_params = !isempty(_field_types_requiring_type_params[dep])
            if dep_has_params
                print(io, stub_name(dep), "{")
                _reconstruct_parametrized_type_name(io, dep, _field_types_requiring_type_params, _remaining_cyclic_defs, type_params)
                print(io, '}')
            else
                print(io, stub_name(dep))
            end
        # elseif dep in keys(type_params.oneofs) # parametrization due to oneof
        #     print(io, type_params.oneofs[dep].param)
        else
            print(io, "<:OneOf")
        end
        _first = false
    end
    print(io, "}")

    return String(take!(io))
end

function _reconstruct_parametrized_type_name(io, name::String, _field_types_requiring_type_params, _remaining_cyclic_defs, type_params)
    @assert name in keys(_field_types_requiring_type_params)
    deps = _field_types_requiring_type_params[name]
    _first = true
    for (isoneof, dep) in deps
        !_first && print(io, ',')
        if dep in _remaining_cyclic_defs                       # dep not defined yet -> use type param
            print(io, type_params.references[dep].param)
        elseif dep in keys(_field_types_requiring_type_params) # dep is cyclic -> use stubbed name and recurse
            dep_has_params = !isempty(_field_types_requiring_type_params[dep])
            if dep_has_params
                print(io, stub_name(dep), "{")
                _reconstruct_parametrized_type_name(io, dep, _field_types_requiring_type_params, _remaining_cyclic_defs, type_params)
                print(io, '}')
            else
                print(io, stub_name(dep))
            end
        # elseif dep in keys(type_params.oneofs)               # parametrization due to oneof
        #     print(io, type_params.oneofs[dep].param)
        else
            print(io, "<:OneOf")
        end
        _first = false
    end
end
