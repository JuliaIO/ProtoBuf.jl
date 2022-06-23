# All definitions should've been pushed to the top-level messages' definitions
# I.e. we shouldn't have to recurse here.
_get_fields(t::AbstractProtoType) = [t]
_get_fields(::EnumType) = []
_get_fields(t::GroupType) = _get_fields(t.type)
_get_fields(t::ServiceType) = t.rpcs
_get_fields(t::Union{OneOfType,MessageType}) = Iterators.flatten(Iterators.map(_get_fields, t.fields))

_get_types(t::AbstractProtoFieldType) = (t.type,)
_get_types(t::RPCType) = (t.request_type, t.response_type)

function find_external_references(definitions::Dict{String, AbstractProtoType})
    # Traverse all definition and see which of those referenced are not defined
    # in this module. Create a list of these imported definitions so that we can ignore
    # them when doing the topological sort.
    referenced = Set{String}()
    for definition in values(definitions)
        for field in _get_fields(definition)
            for type in _get_types(field)
                if isa(type, ReferencedType)
                    push!(referenced, type.name)
                    if type.namespace in keys(definitions)
                        type.namespace_is_type = true
                        # The prefix is referring to another type in which the referenced type is defined
                        # we need to change the name to reflect that to prevent name collisions.
                        type.name = string(type.namespace, '.', type.name)
                    end
                end
            end
        end
    end
    return setdiff(referenced, keys(definitions))
end

get_type_name(::AbstractProtoNumericType) = nothing
get_type_name(t::ExtendType)     = string(t.type.name)  # TODO: handle Extensions
get_type_name(t::FieldType)      = get_type_name(t.type)
get_type_name(t::GroupType)      = t.name
get_type_name(t::ReferencedType) = t.name
get_type_name(t::MessageType)    = t.name
get_type_name(t::EnumType)       = t.name
get_type_name(t::ServiceType)    = t.name
get_type_name(::StringType)      = nothing
get_type_name(::BytesType)       = nothing
get_type_name(::MapType)         = nothing

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
function get_upstream_dependencies!(t::GroupType, out)
    get_upstream_dependencies!(t.type, out)
    return nothing
end
function get_upstream_dependencies!(t::MessageType, out)
    for field in t.fields
        _get_upstream_dependencies!(field, out)
    end
    return nothing
end
function get_upstream_dependencies!(t::ExtendType, out) # TODO: handle Extensions
    _get_upstream_dependencies!(t.type, out)
    foreach(field->_get_upstream_dependencies!(field, out), t.field_extensions)
    return nothing
end

function _get_upstream_dependencies!(t::ReferencedType, out)
    push!(out, t.name)
    return nothing
end
function _get_upstream_dependencies!(t::OneOfType, out)
    for field in t.fields
        _get_upstream_dependencies!(field, out)
    end
    return nothing
end
function _get_upstream_dependencies!(t::FieldType, out)
    name = get_type_name(t.type)
    name === nothing || push!(out, name)
    return nothing
end
function _get_upstream_dependencies!(t::GroupType, out)
    push!(out, t.name)
    get_upstream_dependencies!(t.type, out)
    return nothing
end
function _get_upstream_dependencies!(t::MessageType, out)
    push!(out, t.name) # TODO: Is this needed?
    for field in t.fields
        _get_upstream_dependencies!(field, out)
    end
    return nothing
end