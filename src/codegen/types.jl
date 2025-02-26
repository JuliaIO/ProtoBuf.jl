# If we have a Dict or Vector of a message type that is parametrized on a OneOf, we cannot type
# the container concretely. In this case we prepend a `<:` to the eltype.
_needs_subtyping_in_containers(t::AbstractProtoType, ctx::Context) = false
function _needs_subtyping_in_containers(t::ReferencedType, ctx::Context)
    !_is_message(t, ctx) && return false
    if ctx.options.parametrize_oneofs
        return (_get_referenced_type(t, ctx)::MessageType).has_oneof_field
    end
    return false
end
# jl_typename is used to get the name of a Julia type corresponding to to messages, its fields, enums...
# BUT for types that require parametrization and "stub" types to get around cyclic dependencies, we need
# go through a more complicated route that calls to _ref_type_or_concrete_stub_or_param.
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
# Note that proper handling of references is done in _ref_type_or_concrete_stub_or_param, which takes care
# stub types and type parametrizations. It calls this method in the regular case.
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

_is_message(t::MessageType, ctx::Context)    = true
_is_message(t::ReferencedType, ctx::Context) = t.reference_type == Parsers.MESSAGE
_is_enum(t::ReferencedType, ctx::Context)    = t.reference_type == Parsers.ENUM

# Return a mapping from type names to a set of dependencies that require type params.
function types_needing_params(cyclical_names::AbstractVector{String}, proto_file, options)
    # The bool is indicator whether the string is a name of a oneof field that we need the type param for
    # or a cyclical type reference if it's false.
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
    end
end
function _types_needing_params!(out, lookup, t::ReferencedType, _cyclical_set, options, self_name, _seen)
    __types_needing_params!(out, lookup, t.name, _cyclical_set, options, self_name, _seen)
end
function __types_needing_params!(out, lookup, tname, _cyclical_set, options, self_name, _seen)
    tname == self_name && return nothing # self-references do not need type params, they just work
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

function _maybe_subtype(name, options)
    isempty(name) && return options.common_abstract_type ? " <: AbstractProtoBufMessage" : ""
    return string(" <: ", abstract_type_name(name))
end

struct ParamMetadata
    param::String # like T1, T2, T3, ...
    bound::String # like var"##Abstract#A", Union{Nothing,Int}... used to bound the type param within struct parametrization
end
struct TypeParams
    references::Dict{String,ParamMetadata} # breaking dependency cycles
    oneofs::Dict{String,ParamMetadata}     # specializing on oneof fields, if requested
end
const EMPTY_TYPE_PARAMS = TypeParams(Dict{String,ParamMetadata}(), Dict{String,ParamMetadata}())

# Type bounds used in parametrizations -- for OneOfs we're constructing the union type, for
# the other cases we're only referring to predeclared abstract types.
function _get_oneof_type_bound(f::OneOfType, ctx::Context, type_params::TypeParams=EMPTY_TYPE_PARAMS)
    seen = Set{String}()
    union_types = String[]
    struct_name = ctx._toplevel_raw_name[]
    for o in f.fields
        type_name = jl_typename(o.type, ctx)
        get!(seen.dict, type_name) do
            if o.type isa ReferencedType
                _raw_name = o.type.name
                is_cyclic = _raw_name in keys(ctx._types_and_oneofs_requiring_type_params)
                is_self_ref = _raw_name == struct_name
                # This is legal definition:
                # struct A
                #     x::Union{Nothing,A}
                # end
                # This isn't:
                # struct A{T1<:Union{Nothing,A}}
                #     x::T1
                # end
                # So we need to use the abstract type if we're specializing on OneOf that refer
                # to struct itself.
                needs_abstract = ctx.options.parametrize_oneofs && (is_cyclic || is_self_ref)

                name_in_oneof_union = needs_abstract ?
                    abstract_type_name(_raw_name) :
                    _ref_type_or_concrete_stub_or_param(o.type, ctx, type_params)
            else
                name_in_oneof_union = type_name
            end
            push!(union_types, name_in_oneof_union)
            return nothing
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

# Parametrizing oneofs is the only way a non-cyclic definitions might need type params
function get_type_params_for_non_cyclic(t::MessageType, ctx::Context)
    i = 0
    !(ctx.options.parametrize_oneofs || t.has_oneof_field) && return EMPTY_TYPE_PARAMS
    type_params = TypeParams(EMPTY_TYPE_PARAMS.references, Dict{String,ParamMetadata}())
    for field in t.fields
        !(field isa OneOfType) && continue
        i += 1
        param_meta = ParamMetadata(
            string("T", i),
            _get_oneof_type_bound(field, ctx),
        )
        type_params.oneofs[field.name] = param_meta
    end
    return type_params
end

function get_type_params_for_cyclic(t::MessageType, ctx::Context)
    i = 0
    type_params = TypeParams(Dict{String,ParamMetadata}(), Dict{String,ParamMetadata}())
    deps = get(ctx._types_and_oneofs_requiring_type_params, t.name, Tuple{Bool,String}[]) # bool is true for oneofs

    fields_scan_position = 1 # to only scan the fields once when looking for oneofs as the deps are ordered
    for (isoneof, dep) in deps
        i += 1
        param = string("T", i)
        if isoneof
            for (offset, field) in enumerate(@view(t.fields[fields_scan_position:end]))
                if field.name == dep
                    bound = _get_oneof_type_bound(field, ctx)
                    type_param = ParamMetadata(param, bound)
                    type_params.oneofs[dep] = type_param
                    fields_scan_position += offset
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

# Struct parametrization with cycles and/or specialized oneof fields
function get_type_param_string(type_params::TypeParams)
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

# NOTE: In case of topologically sort-able types, parametrization due to oneof fields are handled
# in the generate_struct method, here we only care about the type params for cyclic definitions, which
# complicate things further by also parametrizing on stub types to resolve dependency cycles.
function reconstruct_parametrized_stub_type_name(t::Union{MessageType,ReferencedType}, ctx::Context, type_params::TypeParams=EMPTY_TYPE_PARAMS)
    type_name = t.name
    _types_and_oneofs_requiring_type_params = ctx._types_and_oneofs_requiring_type_params
    _remaining_cyclic_defs = ctx._remaining_cyclic_defs
    deps = get(_types_and_oneofs_requiring_type_params, type_name, nothing)
    # If there are no dependencies requiring type params, this means that the type is not cyclic
    # and doesn't have a parametrized oneof fields.
    isnothing(deps) && return _safename(type_name)
    # If the set of dependencies exists but is empty, this means that all there were mutually recursive
    # dependencies, but all corresponding stub definitions have already been generated at this point.
    # This means that we're talking about a stub type that doesn't have to be parametrized.
    isempty(deps) && return stub_type_name(type_name)

    # Otherwise, we need to generate a parametrized stub type name
    io = IOBuffer()
    print(io, stub_type_name(type_name))
    print(io, "{")
    _reconstruct_parametrized_stub_type_name(io, t.name, _types_and_oneofs_requiring_type_params, _remaining_cyclic_defs, type_params)
    print(io, "}")

    return String(take!(io))
end

function _reconstruct_parametrized_stub_type_name(io, name::String, _types_and_oneofs_requiring_type_params, _remaining_cyclic_defs, type_params=EMPTY_TYPE_PARAMS)
    @assert name in keys(_types_and_oneofs_requiring_type_params)
    deps = _types_and_oneofs_requiring_type_params[name]
    _first = true
    for (isoneof, dep) in deps
        !_first && print(io, ',')
        if dep in _remaining_cyclic_defs                            # dep not defined yet -> use type param
            print(io, type_params.references[dep].param)
        elseif dep in keys(_types_and_oneofs_requiring_type_params) # dep is cyclic -> use stubbed name and recurse
            dep_has_params = !isempty(_types_and_oneofs_requiring_type_params[dep])
            if dep_has_params
                print(io, stub_type_name(dep), "{")
                _reconstruct_parametrized_stub_type_name(io, dep, _types_and_oneofs_requiring_type_params, _remaining_cyclic_defs, type_params)
                print(io, '}')
            else
                print(io, stub_type_name(dep))
            end
        else
            print(io, "<:Union{Nothing,<:OneOf}")
        end
        _first = false
    end
end

# Since we're potentially mixing type params used to forward declare cyclic deps and type params for oneofs,
# and since all are potentially optional, we must tell the constructor what is the type of the forward declared
# type even if we get a default value like 'nothing'. And since we're specializing on OneOfs, we'll make sure
# to use the concrete type of the OneOf union by calling `typeof` on the provided value (which is always
# named the same as the field itself).
function _maybe_parametrize_constructor_to_handle_oneofs(io, t::MessageType, ctx::Context)
    if t.has_oneof_field && ctx.options.parametrize_oneofs
        i = 1
        if t.name in keys(ctx._types_and_oneofs_requiring_type_params)
            print(io, stub_type_name(t.name), "{")
            for (isoneof, name) in ctx._types_and_oneofs_requiring_type_params[t.name]
                i > 1 && print(io, ",")
                isoneof ? print(io, "typeof(", _safename(name), ")") : print(io, _safename(name))
                i += 1
            end
        else
            print(io, jl_typename(t, ctx), "{")
            for field in t.fields
                field isa OneOfType || continue
                i > 1 && print(io, ",")
                print(io, "typeof(", _safename(field.name), ")")
                i += 1
            end
        end

        print(io, "}")
    else
        print(io, jl_typename(t, ctx))
    end
end

# If T is is a type name as determined from the reference to a message type, then we need to
# use the rest of the info from the field to know if this is a repeated field and if not,
# we need to decide whether we need to make it optional or not. Usually fields are optional
# unless they are specifically asked by the user as required or marked as required field in
# proto2 syntax. Cyclical definitions are always optional.
function _maybe_union_or_vector_a_type_name(type_name::String, field::Union{GroupType,FieldType{ReferencedType}}, ctx::Context)
    struct_name = ctx._toplevel_raw_name[] # must be set by the caller!
    is_repeated = _is_repeated_field(field)

    if is_repeated
        maybe_subtype = _needs_subtyping_in_containers(field.type, ctx) ? "<:" : ""
        return string("Vector{", maybe_subtype, type_name, "}")
    end

    appears_in_cycle = field.type.name in keys(ctx._types_and_oneofs_requiring_type_params)
    is_self_referential = field.type.name == struct_name
    should_force_required = _should_force_required(string(struct_name, ".", field.name), ctx)
    optional_label = (field.label == Parsers.OPTIONAL || field.label == Parsers.DEFAULT)

    needs_union = (is_self_referential || appears_in_cycle) || (!should_force_required && optional_label)

    if needs_union && _is_message(field.type, ctx)
        type_name = string("Union{Nothing,", type_name,"}")
    end
    return type_name
end

# Type is MessageType if we got here from GroupType or ReferencedType if we got here from FieldType{ReferencedType} or a MapType
# This is where we decide where the field param would refer to a type param of the struct,
# a stubbed type name, or the actual type name.
function _ref_type_or_concrete_stub_or_param(type::Union{MessageType,ReferencedType}, ctx::Context, type_params::TypeParams)
    struct_name = ctx._toplevel_raw_name[] # must be set by the caller!
    appears_in_cycle = type.name in keys(ctx._types_and_oneofs_requiring_type_params)
    is_self_referential = type.name == struct_name

    if type.name in ctx._remaining_cyclic_defs # Cyclic reference that has not yet been defined
        # We need to specialize on the type of this field, either because the user requested
        # specialization on a OneOf member, or because the field is part of a cyclic definition
        type_name = type_params.references[type.name].param
    elseif appears_in_cycle || is_self_referential
        # Cyclic reference that has been defined already
        type_name = reconstruct_parametrized_stub_type_name(type, ctx, type_params)
    else
        # Regular field
        type_name = jl_typename(type, ctx)
    end
    return type_name
end

# The type alias pointing to the concretized stub definition, used to break out dependency cycles
function _generate_struct_alias(io, t::MessageType, ctx::Context)
    struct_name = safename(t)
    type = reconstruct_parametrized_stub_type_name(t, ctx)
    println(io, "const ", struct_name, " = ", type)
end
