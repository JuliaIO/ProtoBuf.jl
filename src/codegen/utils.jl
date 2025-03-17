function get_upstream_dependencies!(m::ProtoModule, upstreams)
    ns = namespace(m)
    for i in m.internal_imports
        length(i) >= length(ns) && !_startswith(ns, i) && push!(upstreams, i)
    end
    for s in values(m.submodules)
        _get_upstream_dependencies!(s, upstreams, m)
    end
    delete!(upstreams, namespace(m))
end

function _get_upstream_dependencies!(m::ProtoModule, upstreams, root)
    ns = namespace(root)
    for i in m.internal_imports
        length(i) >= length(ns) && !_startswith(ns, i) && push!(upstreams, i)
    end
    for s in values(m.submodules)
        _get_upstream_dependencies!(s, upstreams, root)
    end
end


function get_all_transitive_imports!(resolved_file::ResolvedProtoFile, file_map)
    _get_all_transitive_imports!(resolved_file.transitive_imports, resolved_file.proto_file, file_map)
    return nothing
end

function _get_all_transitive_imports!(seen::Set{String}, proto_file::ProtoFile, file_map, depth=0)
    for i in proto_file.preamble.imports
        ((depth > 1) && i.import_option != Parsers.PUBLIC) && continue
        push!(seen, i.path)
        _get_all_transitive_imports!(seen, file_map[i.path].proto_file, file_map, depth+1)
    end
end

function get_upstream_dependencies!(file::ResolvedProtoFile, upstreams)
    # for path in file.transitive_imports
    #     push!(upstreams, path)
    # end
    for path in file.implicit_imports
        push!(upstreams, path)
    end
end

struct InterFileResolvingContext <: Parsers.AbstractResolvingContext
    options::Options
    file_map::Dict
    resolved_file::ResolvedProtoFile
end

function resolve_inter_package_references!(file_map, options)
    for file in values(file_map)
        rctx = InterFileResolvingContext(options, file_map, file)
        for definition in values(file.proto_file.definitions)
            Parsers._postprocess_type!(definition, rctx)
        end
    end
end

_maybe_top_namespace(p) = isempty(namespace(p)) ? nothing : first(namespace(p))
function Parsers._postprocess_reference!(t::ReferencedType, rctx::InterFileResolvingContext, ::String)
    if !t.resolved
        found = false
        ns = namespace(rctx.resolved_file)
        root_namespace = isempty(ns) ? "" : first(ns)
        # We can't import the toplevel module to a leaf module if their names collapse
        # we also need to tweak the import statement in `generate_module_file`
        namespaces_clash = length(ns) > 1 && first(ns) == last(ns)
        for import_path in rctx.resolved_file.transitive_imports
            imported_file = rctx.file_map[import_path].proto_file
            ins = namespace(imported_file)
            package_name_dot = string(join(ins, '.'), '.')
            # If fully qualified
            # When we see type.name == "A.B.C", can it match package A.B for def C and package A for def B.C?
            # No, these definitions would name-clash with module names
            if root_namespace == _maybe_top_namespace(imported_file)
                # Same root package namespace, different leaf package namespace ([[[A.]B.]C.]type x [[[A.]B.]D.]type)
                matched_prefix = Parsers.match_prefix(package_name_dot, t.name)
                name_without_import = @view(t.name[length(matched_prefix)+1:end])
                def = get(imported_file.definitions, name_without_import, nothing)
                isnothing(def) && continue
                t.name = name_without_import
                ins == ns && push!(rctx.resolved_file.implicit_imports, import_path)
                found = true
            elseif startswith(t.name, package_name_dot)
                # Referring to a type from a different package (A.B.C.type x X.Y.Z.type)
                name_without_import = @view(t.name[length(package_name_dot)+1:end])
                def = get(imported_file.definitions, name_without_import, nothing)
                isnothing(def) && continue
                t.name = name_without_import
                found = true
            else
                # The name is not qualified.
                def = get(imported_file.definitions, t.name, nothing)
                isnothing(def) && continue
                if !isempty(ins)
                    # Same package, different file -> no package prefix needed
                    if ns != ins
                        t.package_namespace = namespaces_clash ? _safe_namespace_string(ins) : join(ins, '.')
                    end
                elseif rctx.options.always_use_modules
                    t.package_namespace = replace(proto_script_name(imported_file), ".jl" => "")
                end
                t.package_import_path = import_path
                t.reference_type = Parsers.reference_type(def, t)
                t.resolved = true
                return def
            end
            if found
                # Same package, different file -> no package prefix needed
                if ns != ins
                    t.package_namespace = namespaces_clash ? _safe_namespace_string(ins) : join(ins, '.')
                end
                t.package_import_path = import_path
                t.reference_type = Parsers.reference_type(def, t)
                t.resolved = true
                return def
            end
        end
        throw(error("Couldn't find $(t.name) among $(vcat([rctx.resolved_file.proto_file.filepath], collect(rctx.file_map[i].proto_file.filepath for i in rctx.resolved_file.transitive_imports)))"))
    else
        if isnothing(t.package_import_path)
            return rctx.resolved_file.proto_file.definitions[t.name]
        else
            return rctx.file_map[t.package_import_path].proto_file.definitions[t.name]
        end
    end
end

function _startswith(prefix, path)
    isempty(prefix) && return true
    length(prefix) > length(path) && return false
    i = 1
    while i <= length(prefix)
        @inbounds prefix[i] != path[i] && return false
        i += 1
    end
    return true
end

function _cyclic_defs(p::ProtoFile)
    ncyclic = length(p.cyclic_definitions)
    return @view(p.sorted_definitions[(end-ncyclic+1):end])
end
function _non_cyclic_defs(p::ProtoFile)
    ncyclic = length(p.cyclic_definitions)
    return @view(p.sorted_definitions[begin:(end-ncyclic)])
end
