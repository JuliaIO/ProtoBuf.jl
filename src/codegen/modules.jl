# # https://github.com/golang/protobuf/issues/992#issuecomment-558718772
proto_module_file_name(path::AbstractString) = string(proto_module_name(path), ".jl")
proto_module_name(path::AbstractString) = basename(path)
proto_script_name(path::AbstractString) = string(replace(basename(path), ".proto" => ""), "_pb.jl")
proto_script_path(path::AbstractString) = joinpath(dirname(path), proto_script_name(path))

is_namespaced(p::ProtoFile) = !isempty(p.preamble.namespace)
namespace(p::ProtoFile) = p.preamble.namespace
proto_module_file_name(p::ProtoFile) = proto_module_file_name(p.filepath)
proto_module_name(p::ProtoFile) = proto_module_name(p.filepath)
proto_script_name(p::ProtoFile) = proto_script_name(p.filepath)
proto_script_path(p::ProtoFile) = proto_script_path(p.filepath)
import_paths(p::ProtoFile) = (i.path for i in p.preamble.imports)

function namespaced_top_include(p::ProtoFile)
    if is_namespaced(p)
        top = first(namespace(p))
        return joinpath(top, proto_module_file_name(top))
    else
        return proto_script_name(p)
    end
end
namespaced_top_import(p::ProtoFile) = string('.', proto_package_name(p))

is_namespaced(p::ResolvedProtoFile) = is_namespaced(p.proto_file)
namespace(p::ResolvedProtoFile) = namespace(p.proto_file)
proto_module_file_name(p::ResolvedProtoFile) = proto_module_file_name(p.proto_file)
proto_module_name(p::ResolvedProtoFile) = proto_module_name(p.proto_file)
proto_script_name(p::ResolvedProtoFile) = proto_script_name(p.proto_file)
import_paths(p::ResolvedProtoFile) = import_paths(p.proto_file)
namespaced_top_include(p::ResolvedProtoFile) = namespaced_top_include(p.proto_file)
namespaced_top_import(p::ResolvedProtoFile) = namespaced_top_import(p.proto_file)
proto_script_path(p::ResolvedProtoFile) = proto_script_path(p.proto_file)

proto_package_name(p) = first(namespace(p))
rel_import_path(file, root_path) = relpath(joinpath(root_path, "..", namespaced_top_include(file)), joinpath(root_path))

struct ProtoModule
    name::String
    namespace::Vector{String}
    proto_files::Vector{ResolvedProtoFile}
    submodules::Dict{Vector{String},ProtoModule}
    internal_imports::Set{Vector{String}}
    external_imports::Set{String}
    nonpkg_imports::Set{String}
end
namespace(m::ProtoModule) = m.namespace
empty_module(name::AbstractString, namespace_vec) = ProtoModule(name, namespace_vec, [], Dict(),  Set(), Set(), Set())

struct Namespaces
    non_namespaced_protos::Vector{ResolvedProtoFile}
    packages::Dict{String,ProtoModule}
end

function Namespaces(files_in_order::Vector{ResolvedProtoFile}, root_path::String, proto_files::Dict)
    t = Namespaces([], Dict())
    for file in files_in_order
        if !is_namespaced(file)
            push!(t.non_namespaced_protos, file)
        else
            top_namespace = first(namespace(file))
            p = get!(t.packages, top_namespace, empty_module(top_namespace, [top_namespace]))
            _add_file_to_package!(p, file, proto_files, root_path)
        end
    end
    return t
end

function _add_file_to_package!(root::ProtoModule, file::ResolvedProtoFile, proto_files::Dict, root_path::String)
    node = root
    depth = 0
    for name in namespace(file)
        depth += 1
        name == node.name && continue
        node = get!(node.submodules, namespace(file)[1:depth], empty_module(name, namespace(file)[1:depth]))
    end
    for ipath in import_paths(file)
        imported_file = proto_files[ipath]
        if !is_namespaced(imported_file)
            # We always wrap the non-namespaced imports into modules internally
            # Sometimes they are forced to be namespaced with `always_use_modules`
            # but it is the responsibility of the root module to make sure there
            # is a importable module in to topmost scope
            depth != 1 && push!(node.external_imports, string("." ^ depth, replace(proto_script_name(imported_file), ".jl" => "")))
            push!(root.nonpkg_imports, replace(proto_script_name(imported_file), ".jl" => ""))
        else
            file_pkg = proto_package_name(imported_file)
            if namespace(file) == namespace(imported_file)
                continue # no need to import from the same package
            elseif file_pkg == root.name
                union!(node.internal_imports, (namespace(proto_files[import_path]) for import_path in import_paths(file)))
            else
                depth != 1 && push!(node.external_imports, string("." ^ depth, proto_package_name(imported_file)))
                push!(root.external_imports, rel_import_path(imported_file, root_path))
            end
        end
    end
    push!(node.proto_files, file)
    return nothing
end

function generate_module_file(io::IO, m::ProtoModule, output_directory::AbstractString, parsed_files::Dict, options::Options, depth::Int)
    println(io, "module $(m.name)")
    println(io)
    has_deps = !isempty(m.internal_imports) || !isempty(m.external_imports) || !isempty(m.nonpkg_imports)
    if depth == 1
        # This is where we include external packages so they are available downstream
        for external_import in m.external_imports
            println(io, "include(", repr(external_import), ')')
        end
        # This is where we include external dependencies that may not be packages.
        # We wrap them in a module to make sure that multiple downstream dependencies
        # can import them safely.
        for nonpkg_import in m.nonpkg_imports
            !options.always_use_modules && print(io, "module $(nonpkg_import)\n    ")
            println(io, "include(", repr(joinpath("..", string(nonpkg_import, ".jl"))), ')')
            !options.always_use_modules && println(io, "end")
        end
    else # depth > 1
        # We're not a top package module, we can import external dependencies
        # from the top package module.
        for external_import in m.external_imports
            println(io, "import ", external_import)
        end
    end

    # We require all files and their parent modules to be inserted in topologically
    # sorted order so we can import the generated Julia code without undefined references.
    # We can't simply topsort files by their imports because this doesn't guarantee that some
    # files within a module (e.g. small files that don't import anything by themselves)
    # would respect the required ordering with respect to modules.
    # To solve this, we topsort the module imports on each module/namespace level.
    if length(m.submodules) > 1
        submodule_namespaces, _ = _topological_sort(m.submodules)
    else
        submodule_namespaces = collect(keys((m.submodules)))
    end

    # This is where we import internal dependencies
    if !isempty(m.internal_imports)
        print(io, "import ", string("." ^ length(namespace(m)), first(namespace(m))))
        # We can't import the toplevel module to a leaf module if their names collide
        # we also need to tweak the `package_namespace` field of each imported ReferencedType
        if first(namespace(m)) == last(namespace(m))
            println(io,  " as var\"#", first(namespace(m)), '"')
        else
            println(io)
        end
    end
    has_deps && println(io)
    # Load in imported proto files that are defined in this package (the files ending with `_pb.jl`)
    # In case there is a dependency of some of these files on a submodule, we include that submodule
    # first.
    seen = Set{String}()
    for file in m.proto_files
        for i in import_paths(file)
            imported_file = parsed_files[i]
            if length(namespace(file)) == length(namespace(imported_file)) - 1 && _startswith(namespace(file), namespace(imported_file))
                submodule_name = last(namespace(imported_file))
                get!(seen.dict, submodule_name) do
                    println(io, "include(", repr(joinpath(submodule_name, string(submodule_name, ".jl"))), ")")
                end
            end
        end
        println(io, "include(", repr(proto_script_name(file)), ")")
    end
    # Load in submodules nested in this namespace (the modules ending with `PB`),
    # that is, if we didn't include them above.
    for submodule_namespace in submodule_namespaces
        submodule = m.submodules[submodule_namespace]
        get!(seen.dict, submodule.name) do
            println(io, "include(", repr(joinpath(submodule.name, string(submodule.name, ".jl"))), ")")
        end
    end
    println(io)
    println(io, "end # module $(m.name)")
end

function generate_package(node::ProtoModule, output_directory::AbstractString, parsed_files::Dict, options::Options, depth=1)
    path = joinpath(output_directory, node.name, "")
    !isdir(path) && mkdir(path)
    open(joinpath(path, string(node.name, ".jl")), "w", lock=false) do io
        generate_module_file(io, node, output_directory, parsed_files, options, depth)
    end
    for file in node.proto_files
        dst_path = joinpath(path, proto_script_name(file))
        CodeGenerators.translate(dst_path, file, parsed_files, options)
    end
    for submodule in values(node.submodules)
        generate_package(submodule, path, parsed_files, options, depth+1)
    end
    return nothing
end

function validate_search_directories!(search_directories::Vector{String}, include_vendored_wellknown_types::Bool)
    include_vendored_wellknown_types && push!(search_directories, VENDORED_WELLKNOWN_TYPES_PARENT_PATH)
    unique!(map!(x->joinpath(abspath(x), ""), search_directories, search_directories))
    bad_dirs = filter(!isdir, search_directories)
    !isempty(bad_dirs) && error("`search_directories` $bad_dirs don't exist")
    return nothing
end

function validate_proto_file_paths!(relative_paths::Vector{<:AbstractString}, search_directories)
    isempty(relative_paths) && error("At least one relative path must be provided, received none.")
    unique!(map!(normpath, relative_paths, relative_paths))
    full_paths = copy(relative_paths)
    proto_files_not_within_reach = String[]
    abspaths = String[]
    for (i, proto_file_path) in enumerate(relative_paths)
        if startswith(proto_file_path, '/')
            push!(abspaths, proto_file_path)
            continue
        end
        found = false
        for search_directory in search_directories
            found && continue
            full_path = joinpath(search_directory, proto_file_path)
            if isfile(joinpath(search_directory, proto_file_path))
                found = true
                full_paths[i] = full_path
            end
        end
        !found && push!(proto_files_not_within_reach, proto_file_path)
    end
    !isempty(proto_files_not_within_reach) && error("Could not find following proto files: $proto_files_not_within_reach within $search_directories")
    !isempty(abspaths) && error("Paths to proto files must be relative to search_directories; got following absolute paths: $abspaths")
    return full_paths
end

function resolve_imports!(imported_paths::Set{String}, parsed_files, search_directories)
    missing_imports = String[]
    while !isempty(imported_paths)
        found = false
        path = pop!(imported_paths)
        path in keys(parsed_files) && continue
        for dir in search_directories
            found && continue
            full_path = joinpath(dir, path)
            if isfile(full_path)
                q = Parsers.parse_proto_file(full_path)
                parsed_files[path] = ResolvedProtoFile(path, q)
                union!(imported_paths, import_paths(q))
                found = true
            end
        end
        !found && push!(missing_imports, path)
    end
    !isempty(missing_imports) && error("Could not find following imports: $missing_imports within $search_directories")
    return nothing
end
