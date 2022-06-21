# to hook in, import and define get_upstream_dependencies! methods for your types
function get_upstream_dependencies!(definition, upstreams) end

function _topological_sort(definitions, ignored_keys::Set{String})
    has_ignored_keys = !isempty(ignored_keys)
    number_of_upstream_dependencies = Dict{String,Int}()
    downstream_dependencies = Dict{String,Vector{String}}()
    upstreams = Set{String}()
    topologically_sorted = sizehint!(String[], length(definitions))
    queue = sizehint!(String[], length(definitions))

    for (name, definition) in definitions
        empty!(upstreams)
        get_upstream_dependencies!(definition, upstreams)
        has_ignored_keys && setdiff!(upstreams, ignored_keys)
        if length(upstreams) == 0
            push!(queue, name)
        else
            number_of_upstream_dependencies[name] = length(upstreams)
        end
        get!(downstream_dependencies, name, String[])
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

    cyclic_definitions = upstreams
    empty!(cyclic_definitions)
    if !isempty(number_of_upstream_dependencies)
        @debug "The input is not a DAG."
        for cyclic_definition in first.(sort!(collect(number_of_upstream_dependencies), by=last))
            deps = downstream_dependencies[cyclic_definition]
            if !(length(deps) == 1 && only(deps) == cyclic_definition)
                push!(cyclic_definitions, cyclic_definition)
            end
        end
        append!(topologically_sorted, cyclic_definitions)
    end
    return topologically_sorted, cyclic_definitions
end