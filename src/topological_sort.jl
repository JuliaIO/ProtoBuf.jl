# to hook in, import and define get_upstream_dependencies! methods for your types
function get_upstream_dependencies!(definition, upstreams)
    throw(MethodError(get_upstream_dependencies!, (typeof(definition), typeof(upstreams))))
end

function _topological_sort(definitions::Dict{K}, ignored_keys::Union{Nothing,Set{K}}=nothing) where {K}
    has_ignored_keys = !isnothing(ignored_keys) && !isempty(ignored_keys)
    number_of_upstream_dependencies = Dict{K,Int}()
    downstream_dependencies = Dict{K,Vector{K}}()
    upstreams = Set{K}()
    topologically_sorted = sizehint!(K[], length(definitions))
    queue = sizehint!(K[], length(definitions))

    for (name, definition) in definitions
        empty!(upstreams)
        get_upstream_dependencies!(definition, upstreams)
        has_ignored_keys && setdiff!(upstreams, ignored_keys)
        intersect!(upstreams,keys(definitions))
        if length(upstreams) == 0
            push!(queue, name)
        else
            number_of_upstream_dependencies[name] = length(upstreams)
        end
        get!(downstream_dependencies, name, K[])
        for u in upstreams
            # add current definition as an downstream dependency to it's upstreams
            push!(get!(downstream_dependencies, u, K[]), name)
        end
    end




    while !isempty(queue)
        u = popfirst!(queue)
        push!(topologically_sorted, u)
        D = downstream_dependencies[u]
        while !isempty(D)
            d = pop!(D)
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
        for cyclic_definition in first.(collect(number_of_upstream_dependencies))
            push!(cyclic_definitions, cyclic_definition)
        end
        append!(topologically_sorted, cyclic_definitions)
    end
    return topologically_sorted, cyclic_definitions
end
