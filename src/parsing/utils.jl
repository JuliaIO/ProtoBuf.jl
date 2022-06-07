# All definitions should've been pushed to the top-level messages' definitions
# I.e. we shouldn't have to recurse here.
_get_fields(t::AbstractProtoType) = [t]
_get_fields(::EnumType) = []
_get_fields(t::GroupType) = _get_fields(t.type)
_get_fields(t::Union{OneOfType,MessageType}) = Iterators.flatten(Iterators.map(_get_fields, t.fields))

function expand_namespaced_definitions!(
    file_definitions::Dict{String, AbstractProtoType}, 
    extends::Vector{ExtendType},
)
    # Traverse all definition and see which of those referenced are not defined
    # in this module. Create a list of these imported definitions so that we can ignore
    # them when doing the topological sort. Also, if they're not containing a dot... error?
    seen = Set{String}()
    referenced = Set{String}()

    for (name, file_definition) in file_definitions
        isa(file_definition, ExtendType) && continue # TODO: implement Extensions
        push!(seen, name)
        if isa(file_definition, MessageType) # only MessageType has a definitions field
            for field in _get_fields(file_definition)
                isa(field.type, ReferencedType) && push!(referenced, field.type.name)
            end

            while !isempty(file_definition.definitions)
                inner_name, inner_definition = pop!(file_definition.definitions)
                inner_definition.name in seen && continue
                # TODO: handle Extensions
                if isa(inner_definition, ExtendType)
                    push!(extends, inner_definition)
                else
                    file_definitions[inner_name] = inner_definition
                    push!(seen, inner_name)
                end
                for field in _get_fields(inner_definition)
                    isa(field.type, ReferencedType) && push!(referenced, field.type.name)
                end
            end
        end
    end
    return setdiff(referenced, seen)
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


function _topological_sort(definitions::Dict{String,<:AbstractProtoType}, external_references::Set{String})
    has_external_references = !isempty(external_references)
    number_of_upstream_dependencies = Dict{String,Int}()
    downstream_dependencies = Dict{String,Vector{String}}()
    topologically_sorted = String[]
    upstreams = Set{String}()
    queue = String[]
    
    for (name, definition) in definitions
        empty!(upstreams)
        isa(definition, ExtendType) && continue # TODO: implement Extensions
        get_upstream_dependencies!(definition, upstreams)
        # Remove imported types, these shouldn't affect topological sort
        has_external_references && setdiff!(upstreams, external_references)
        if length(upstreams) == 0
            push!(queue, name)
        else
            number_of_upstream_dependencies[name] = length(upstreams)
        end
        get!(downstream_dependencies, name, String[]) # preallocate
        for u in upstreams
            # add current definition as an downstream dependency to it's upstreams
            push!(get!(downstream_dependencies, u, String[]), name)
        end
    end

    while !isempty(queue)
        u = popfirst!(queue)
        push!(topologically_sorted, u)
        for d in downstream_dependencies[u]
            if (number_of_upstream_dependencies[d] -= 1) == 0
                pop!(number_of_upstream_dependencies, d)
                push!(queue, d)
            end
        end
    end
    if !isempty(number_of_upstream_dependencies)
        @debug "The input is not a DAG."
        cyclic_definitions = first.(sort!(collect(number_of_upstream_dependencies), by=last))
        append!(topologically_sorted, cyclic_definitions)
    end

    return topologically_sorted
end