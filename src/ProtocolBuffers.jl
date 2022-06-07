module ProtocolBuffers
import EnumX
import TranscodingStreams

struct OneOf{T}
    name::Symbol
    value::T
end

# Since `oneof` fields contain different names per type in the type union
# we can overload `Base.getproperty` to allow direcly reaching for the 
# value we actually got, e.g. for this ProtoBuf message:
#   message MessageType {
#       oneof one_of_field {
#           string inner_field
#           int another_thing
#       }
#   }
# We can use one of the two:
#    MessageType.one_of_field.inner_field
#    MessageType.one_of_field.another_thing
#
# But I guess this will invalidate a lot of julia code?
# function Base.getproperty(t::OneOf, s::Symbol)
#     if s == Base.getfield(t, :name) 
#         Base.getfield(t, :value) 
#     else
#         error(string(
#             "This `OneOf` has no field `$(s)` (Did you mean `$(Base.getfield(t, :name))`? ",
#             "Alternatvely, you can get the value by invoking getinde `[]`)"
#         ))
#     end
# end
Base.getindex(t::OneOf) = getfield(t, :value)
Base.nameof(t::OneOf) = getfield(t, :name) # is this the right thing to overload?
Base.Pair(t::OneOf) = nameof(t) => t[]

include("lexing/Tokens.jl")
include("lexing/Lexers.jl")

include("parsing/Parsers.jl")
include("CodeGenerators.jl")

import .Parsers
import .CodeGenerators

struct Namespace
    name::String
    proto_files::Vector{Parsers.ProtoFile}
    children::Dict{String,Namespace}
end
Namespace(s::AbstractString) = Namespace(s, [], Dict())
Namespace() = Namespace("", [], Dict())

function insert!(node::Namespace, package_file::Parsers.ProtoFile)
    identifier = package_file.preamble.identifier
    if isempty(identifier)
        push!(node.proto_files, package_file)
        return nothing
    end
    for ns in split(identifier, '.')
        node = get!(node.children, ns, Namespace(ns))
    end
    push!(node.proto_files, package_file)
    return nothing
end

function Namespace(pfs::Union{AbstractVector,Base.ValueIterator})
    namespace = Namespace()
    for pf in pfs
        insert!(namespace, pf)
    end
    namespace
end

function Namespace(pfs::Union{AbstractVector,Base.ValueIterator}, s::AbstractString)
    namespace = Namespace(s)
    for pf in pfs
        insert!(namespace, pf)
    end
    namespace
end

# TODO: so far we're creating julia files that are not modules which are including their
# dependencies. We should create the actual package files that would include translated files
# in top sorted order.
function create_namespaced_packages(ns::Namespace, output_directory::AbstractString)
    path = joinpath(output_directory, ns.name, "")
    for p in ns.proto_files
        julian_file_name = replace(titlecase(basename(p.filepath)), r"[-_]" => "", ".Proto" => "PB.jl")
        dst_path = joinpath(path, julian_file_name)
        CodeGenerators.translate(dst_path, p)
    end
    for (child_dir, child) in ns.children
        !isdir(joinpath(path, child_dir)) && mkdir(joinpath(path, child_dir))
        create_namespaced_packages(child, path)
    end
end


function protojl(
    proto_file_paths::String, 
    search_directories::Vector{String}=[".", dirname(proto_file)], 
    output_directory::Union{String,Nothing}=nothing
)
    protojl([proto_file_paths], search_directories, output_directory)
end

# TODO: search directory defaults; we instead of dirname of proto_file, add
# the dirname MINUS its namespace if dirname is "./a/b/c/d" and namespace is
# "c.d"  add the path "./a/b" as it is likely the root od the package
# hierarchy
function protojl(
    proto_file_paths::Vector{String}, 
    search_directories::Vector{String}=[".", dirname.(proto_file_paths)...], 
    output_directory::Union{String,Nothing}=nothing
)
    isempty(proto_file_paths) && return nothing
    parsed_files = Dict{String,Parsers.ProtoFile}()
    import_paths = Set{String}()
    for path in proto_file_paths
        p = Parsers.parse_proto_file(path)
        parsed_files[abspath(path)] = p
        union!(import_paths, Set{String}(i.name for i in p.preamble.imports))
    end

    unique!(map!(abspath, search_directories, search_directories))
    for search_directory in search_directories
        isdir(search_directory) || error("`search_directory` $search_directory doesn't exist")
    end
    missing_imports = String[]
    while !isempty(import_paths)
        path = pop!(import_paths)
        path in keys(parsed_files) && continue
        found = false
        for dir in search_directories
            found && continue
            path = joinpath(dir, path)
            if isfile(path)
                q = Parsers.parse_proto_file(path)
                parsed_files[path] = q
                union!(import_paths, Set{String}(i.name for i in q.preamble.imports))
                found = true
            end
        end
        !found &&  push!(missing_imports, path)
    end

    !isempty(missing_imports) && error("Could not find following imports: $missing_imports")

    if isnothing(output_directory) 
        output_directory = mktempdir(tempdir(); prefix="jl_proto_", cleanup=false)
        @info output_directory
    else
        isdir(output_directory) || error("`output_directory` $output_directory doesn't exist")
        output_directory = abspath(output_directory)
    end

    ns = Namespace(values(parsed_files))
    create_namespaced_packages(ns, output_directory)
end

end # module
