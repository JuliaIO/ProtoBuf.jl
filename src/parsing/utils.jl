function _postprocess_reference!(referenced, type::ReferencedType, definitions, namespace)
    # if isempty(type.namespace)
    #     namespaced_name = string(namespace, '.', type.name)
    #     if namespaced_name in keys(definitions)
    #         @warn type.name namespace type
    #         type.name = namespaced_name
    #         type.enclosing_type = namespace
    #     end
    # end
    push!(referenced, type.name)
    if type.namespace in keys(definitions)
        type.namespace_is_type = true
        # The prefix is referring to another type in which the referenced type is defined
        # we need to change the name to reflect that to prevent name collisions.
        type.name = string(type.namespace, '.', type.name)
    end
end

function _postprocess_field!(referenced, invalid_enums, f::FieldType{ReferencedType}, definitions, preamble, namespace)
    _postprocess_reference!(referenced, f.type, definitions, namespace)
end
_postprocess_field!(referenced, invalid_enums, f::FieldType, definitions, preamble, namespace) = nothing
function _postprocess_field!(referenced, invalid_enums, f::OneOfType, definitions, preamble, namespace)
    for field in f.fields
        _postprocess_field!(referenced, invalid_enums, field, definitions, preamble, namespace)
    end
    return nothing
end
function _postprocess_field!(referenced, invalid_enums, f::GroupType, definitions, preamble, namespace)
    for field in f.type.fields
        _postprocess_field!(referenced, invalid_enums, field, definitions, preamble, namespace)
        _postprocess_field!(referenced, invalid_enums, field, definitions, preamble, f.type.name)
    end
    return nothing
end

function _postprocess_type!(referenced, invalid_enums, t::EnumType, definitions, preamble)
    preamble.isproto3 && first(t.element_values) != 0 && push!(invalid_enums, t.name)
    return nothing
end
function _postprocess_type!(referenced, invalid_enums, t::ServiceType, definitions, preamble)
    for rpc in t.rpcs
        _postprocess_reference!(referenced, rpc.request_type, definitions, t.name)
        _postprocess_reference!(referenced, rpc.response_type, definitions, t.name)
    end
    return nothing
end
function _postprocess_type!(referenced, invalid_enums, t::MessageType, definitions, preamble)
    for field in t.fields
        _postprocess_field!(referenced, invalid_enums, field, definitions, preamble, t.name)
    end
    return nothing
end

function postprocess_types!(definitions::Dict{String, Union{MessageType, EnumType, ServiceType}}, preamble::ProtoFilePreamble)
    # Traverse all definitions and see which of those referenced are not defined
    # in this module. Create a list of these imported definitions so that we can ignore
    # them when doing the topological sort.
    referenced = Set{String}()
    invalid_enums = Set{String}()
    for definition in values(definitions)
        _postprocess_type!(referenced, invalid_enums, definition, definitions, preamble)
    end
    !isempty(invalid_enums) && error("In proto3, enums' first element must map to zero, following enums violate that: $invalid_enums")
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