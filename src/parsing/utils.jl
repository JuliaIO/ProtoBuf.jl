function find_external_references_and_check_enums(definitions::Dict{String, AbstractProtoType}, preamble::ProtoFilePreamble)
    # Traverse all definition and see which of those referenced are not defined
    # in this module. Create a list of these imported definitions so that we can ignore
    # them when doing the topological sort.
    referenced = Set{String}()
    invalid_enums = Set{String}()
    for definition in values(definitions)
        for field in Parsers._get_leaf_fields(definition)
            for type in Parsers._get_types(field)
                if isa(type, ReferencedType)
                    push!(referenced, type.name)
                    if type.namespace in keys(definitions)
                        type.namespace_is_type = true
                        # The prefix is referring to another type in which the referenced type is defined
                        # we need to change the name to reflect that to prevent name collisions.
                        type.name = string(type.namespace, '.', type.name)
                    end
                elseif preamble.isproto3 && isa(type, EnumType)
                    first(values(type.elements)) != 0 && push!(invalid_enums, type.name)
                end
            end
        end
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