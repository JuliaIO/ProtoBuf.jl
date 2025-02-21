function _findfunc(namespace, i, name, from_innermost)
    n = length(namespace)
    if from_innermost
        i > n && return (string(namespace, '.', name), n) # first search
        i == 0 && return ("", -1)                         # not found
        j = something(findprev('.', namespace, i-1), 0)
        j == 0 && i != 0 && return (name, 0)              # last search
        j != 0 && i != 0 && return (string(@view(namespace[1:j]), name), j)
    else
        i < 1 && return (name, 1)                                    # first search
        i == n && return ("", -1)                                    # not found
        j = something(findnext('.', namespace, i+1), n)
        j == n && i != n && return (string(namespace, '.', name), n) # last search
        j != n && i != n && return (string(@view(namespace[1:j]), name), j)
    end
    throw(error("When from_innermost is `true`, i must be >= 0, when from_innermost is `false`, i must be <= length(namespace), got (from_innermost=$from_innermost, i=$i)"))
end

function match_prefix(prefix, name)
    i = length(prefix)
    subprefix = @view prefix[begin:end]
    while true
        startswith(name, subprefix) && return subprefix
        i = findprev('.', prefix, i-1)
        isnothing(i) && return SubString("", 1, 0)
        subprefix = @view prefix[i+1:end]
    end
end

abstract type AbstractResolvingContext end

struct IntraFileResolvingContext <: AbstractResolvingContext
    external_references::Set{String}
    definitions::Dict{String, Union{MessageType, EnumType, ServiceType}}
    package_prefix::String
end

function reference_type(def, t::ReferencedType)
    isa(def, MessageType) ? MESSAGE :
    isa(def, EnumType)    ? ENUM    :
    isa(def, ServiceType) ? SERVICE :
    isa(def, RPCType)     ? RPC     :
    throw(error("Referenced type `$(t.name)` has unsupported type $(typeof(def))"))
end

_postprocess_reference!(type, rctx::AbstractResolvingContext, namespace) = nothing
function _postprocess_reference!(type::ReferencedType, rctx::IntraFileResolvingContext, namespace)
    if !type.resolved
        # Get rid of the package prefix if it coincides with the package of the current file
        matched_prefix = match_prefix(rctx.package_prefix, type.name)
        if !isempty(matched_prefix)
            type.name = type.name[length(matched_prefix)+1:end]
        end
        # We're trying to resolve the reference within our current file
        # if we don't succeed, we'll try to resolve the reference among
        # other proto files later, duing codegen.
        i = type.resolve_from_innermost ? (length(namespace) + 1) : 0
        while true
            (namespaced_name, i) = _findfunc(namespace, i, type.name, type.resolve_from_innermost)
            if i == -1
                push!(rctx.external_references, type.name)
                break
            end
            def = get(rctx.definitions, namespaced_name, nothing)
            if !isnothing(def)
                type.name = namespaced_name
                type.reference_type = reference_type(def, type)
                type.resolved = true
                break
            end
        end
    end
end

_postprocess_field!(f::FieldType{ReferencedType}, rctx, namespace) = _postprocess_reference!(f.type, rctx, namespace)
_postprocess_field!(f::FieldType{MapType}, rctx, namespace)        = _postprocess_reference!(f.type.valuetype, rctx, namespace)
_postprocess_field!(f::FieldType, rctx, namespace) = nothing
function _postprocess_field!(f::OneOfType, rctx, namespace)
    for field in f.fields
        _postprocess_field!(field, rctx, namespace)
    end
    return nothing
end
function _postprocess_field!(f::GroupType, rctx, namespace)
    for field in f.type.fields
        _postprocess_field!(field, rctx, namespace)
    end
    return nothing
end

_postprocess_type!(t::EnumType, rctx::AbstractResolvingContext) = nothing
function _postprocess_type!(t::ServiceType, rctx::AbstractResolvingContext)
    for rpc in t.rpcs
        _postprocess_reference!(rpc.request_type, rctx, t.name)
        _postprocess_reference!(rpc.response_type, rctx, t.name)
    end
    return nothing
end
function _postprocess_type!(t::MessageType, rctx::AbstractResolvingContext)
    for field in t.fields
        _postprocess_field!(field, rctx, t.name)
    end
    return nothing
end

function postprocess_types!(definitions::Dict{String, Union{MessageType, EnumType, ServiceType}}, package_name::String)
    # Traverse all definitions and see which of those referenced are not defined
    # in this module. Create a list of these imported definitions so that we can ignore
    # them when doing the topological sort.
    rctx = IntraFileResolvingContext(Set{String}(), definitions, string(package_name, '.'))
    for definition in values(definitions)
        _postprocess_type!(definition, rctx)
    end
    return rctx.external_references
end

get_type_name(::AbstractProtoNumericType) = nothing
get_type_name(t::ExtendType)     = string(t.type.name)  # TODO: handle Extensions, remove string?
get_type_name(t::FieldType)      = get_type_name(t.type)
get_type_name(t::GroupType)      = t.name
get_type_name(t::ReferencedType) = t.name
get_type_name(t::MessageType)    = t.name
get_type_name(t::EnumType)       = t.name
get_type_name(t::ServiceType)    = t.name
get_type_name(::StringType)      = nothing
get_type_name(::BytesType)       = nothing
get_type_name(t::MapType)        = get_type_name(t.valuetype) # messages and enums can't be keys

function get_upstream_dependencies!(t::ServiceType, out)
    for rpc in t.rpcs
        push!(out, rpc.request_type.name)
        push!(out, rpc.response_type.name)
    end
    return nothing
end
function get_upstream_dependencies!(::EnumType, out)
    return nothing
end
function get_upstream_dependencies!(t::MessageType, out)
    for field in t.fields
        _get_upstream_dependencies!(field, out, t.name)
    end
    return nothing
end
function get_upstream_dependencies!(t::ExtendType, out) # TODO: handle Extensions
    _get_upstream_dependencies!(t.type, out)
    foreach(field->_get_upstream_dependencies!(field, out), t.field_extensions)
    return nothing
end

function _get_upstream_dependencies!(t::ReferencedType, out, self_name=nothing)
    self_name != t.name && push!(out, t.name)
    return nothing
end
function _get_upstream_dependencies!(t::OneOfType, out, self_name=nothing)
    for field in t.fields
        _get_upstream_dependencies!(field, out, self_name)
    end
    return nothing
end
function _get_upstream_dependencies!(t::FieldType, out, self_name=nothing)
    name = get_type_name(t.type)
    if name !== nothing && name != self_name
        push!(out, name)
    end
    return nothing
end
function _get_upstream_dependencies!(t::GroupType, out, self_name=nothing)
    self_name != t.name && push!(out, t.name)
    get_upstream_dependencies!(t.type, out)
    return nothing
end
function _get_upstream_dependencies!(t::MessageType, out, self_name=nothing)
    self_name != t.name && push!(out, t.name) # TODO: Is this needed?
    for field in t.fields
        _get_upstream_dependencies!(field, out)
    end
    return nothing
end
