module CodeGenerators


import ..Parsers
import ..Parsers: ProtoFile, DoubleType, FloatType, Int32Type
import ..Parsers: Int64Type, UInt32Type, UInt64Type, SInt32Type, SInt64Type
import ..Parsers: Fixed32Type, Fixed64Type, SFixed32Type, SFixed64Type, BoolType
import ..Parsers: StringType, BytesType
import ..Parsers: GroupType, OneOfType, MapType, FieldType
import ..Parsers: MessageType, EnumType, ServiceType, RPCType, ReferencedType
import ..Parsers: AbstractProtoType, AbstractProtoNumericType, AbstractProtoFixedType
import ..Parsers: AbstractProtoFloatType, AbstractProtoFieldType
import Dates
import ..ProtoBuf: VENDORED_WELLKNOWN_TYPES_PARENT_PATH, PACKAGE_VERSION
import ..ProtoBuf: _topological_sort, get_upstream_dependencies!

_is_repeated_field(f::AbstractProtoFieldType) = f.label == Parsers.REPEATED
_is_repeated_field(::OneOfType) = false

struct ResolvedProtoFile
    import_path::String
    proto_file::ProtoFile
    implicit_imports::Set{String}
    transitive_imports::Set{String}
end
ResolvedProtoFile(rel_path, p) = ResolvedProtoFile(rel_path, p, Set{String}(), Set{String}())

Base.@kwdef struct Options
    include_vendored_wellknown_types::Bool = true
    always_use_modules::Bool = true
    force_required::Union{Nothing,Dict{String,Set{String}}} = nothing
    add_kwarg_constructors::Bool = false
    parametrize_oneofs::Bool = false
end

struct Context
    proto_file::ProtoFile
    proto_file_path::String
    file_map::Dict{String,ResolvedProtoFile}
    _curr_cyclic_defs::Set{String}
    _toplevel_name::Ref{String}
    transitive_imports::Set{String}
    options::Options
end

include("modules.jl")
include("names.jl")
include("types.jl")
include("defaults.jl")
include("decode_methods.jl")
include("encode_methods.jl")
include("metadata_methods.jl")
include("toplevel_definitions.jl")
include("utils.jl")

"""
    protojl(
        relative_paths::Union{String,Vector{String}},
        search_directories::Union{String,Vector{String},Nothing}=nothing,
        output_directory::Union{String,Nothing}=nothing;
        include_vendored_wellknown_types::Bool=true,
        always_use_modules::Bool=true,
        force_required::Union{Nothing,Dict{String,Set{String}}}=nothing,
        add_kwarg_constructors::Bool=false,
        parametrize_oneofs::Bool=false,
    ) -> Nothing

Generate Julia code for `.proto` files at `relative_paths` within `search_directories` and save it to `output_directory`.

When compiling a `{file_name}.proto` files that do not have a `package` specifier, a `{file_name}_pb.jl` is generated in `output_directory`.
When a `{file_name}.proto` contains e.g. `package foo_bar.baz_grok`, the following directory structure is created:
```bash
root  # `output_directory` arg from from `protojl`
└── foo_bar
    ├── foo_bar.jl  # defines module `foo_bar`, imports `baz_grok`
    └── baz_grok
        ├── {file_name}_pb.jl
        └── baz_grok.jl  # defines module `baz_grok`, includes `{file_name}_pb.jl`
```
You should include the top-level module of a generated package, i.e. `foo_bar.jl` in this example.
All imported `.proto` files are compiled as well; an error is thrown if they cannot be resolved or found within `search_directories`.

# Arguments
- `relative_paths::Union{String,Vector{String}}`: A path or paths to `.proto` files to be compiled.
- `search_directories::Union{String,Vector{String},Nothing}=nothing`: A directory or directories to search for `relative_paths` in. By default, the current directory is used.
- `output_directory::Union{String,Nothing}=nothing`: Path to store the generated Julia source code. When omitted, the translated code is saved to temp directory, the path is shown as a @info log.

# Keywords
- `include_vendored_wellknown_types::Bool=true`: Append `ProtoBuf.VENDORED_WELLKNOWN_TYPES_PARENT_PATH` to `search_directories`, making the "well-known" message definitions available.
- `always_use_modules::Bool=true`: Generate julia code in a module even if the `.proto` file doesn't contain a `package` specifier. The module name of `{file_name}.proto` file is `{file_name}_pb`.
- `force_required::Union{Nothing,Dict{String,Set{String}}}=nothing`: Assume `message` and `oneof` fields to be aleways send over the wire -- then we woudln't need to `Union` their respective types with `Nothing`. E.g:
```julia
# force_required === nothing
struct MyMessage
    message_field::Union{Nothing,MyOtherMessage}}
end
```
```julia
# force_required === Dict("{file_name}.proto" => Set(["MyMessage.message_field"]))
struct MyMessage
    message_field::MyOtherMessage}
end
```
- `add_kwarg_constructors::Bool=false`: For each message, generate an outer constructor with optional keyword arguments (if a field is a required message, there are no default values and the keyword argument is not optional).
- `parametrize_oneofs::Bool=false`: Add the `OneOf` type as a type parameter to the generated parent struct. I.e. this changes:
```julia
# parametrize_oneofs == false
struct MyMessage
    oneof_field::Union{Nothing, OneOf{<:Union{Int, String}}}
end
```
to
```julia
# parametrize_oneofs == true
struct MyMessage{T1<:Union{Nothing, OneOf{<:Union{Int, String}}}}
    oneof_field::T1
end
```

# Notes
We use `relative_paths` and `search_directories` instead of absolute paths to resolve proto `import` statements which are using relative paths.
"""
function protojl(
    relative_paths::Union{<:AbstractString,<:AbstractVector{<:AbstractString}},
    search_directories::Union{<:AbstractString,<:AbstractVector{<:AbstractString},Nothing}=nothing,
    output_directory::Union{<:AbstractString,Nothing}=nothing;
    include_vendored_wellknown_types::Bool=true,
    always_use_modules::Bool=true,
    force_required::Union{Nothing,<:Dict{<:AbstractString,<:Set{<:AbstractString}}}=nothing,
    add_kwarg_constructors::Bool=false,
    parametrize_oneofs::Bool=false,
)
    options = Options(include_vendored_wellknown_types, always_use_modules, force_required, add_kwarg_constructors, parametrize_oneofs)
    return _protojl(relative_paths, search_directories, output_directory, options)
end

function _protojl(
    relative_paths::Union{<:AbstractString,<:AbstractVector{<:AbstractString}},
    search_directories::Union{<:AbstractString,<:AbstractVector{<:AbstractString},Nothing},
    output_directory::Union{<:AbstractString,Nothing},
    options::Options,
)
    if isnothing(search_directories)
        search_directories = ["."]
    elseif isa(search_directories, AbstractString)
        search_directories = [search_directories]
    end
    validate_search_directories!(search_directories, options.include_vendored_wellknown_types)

    if isa(relative_paths, AbstractString)
        relative_paths = [relative_paths]
    end
    absolute_paths = validate_proto_file_paths!(relative_paths, search_directories)

    parsed_files = Dict{String,ResolvedProtoFile}()
    _import_paths = Set{String}()
    for (rel_path, abs_path) in zip(relative_paths, absolute_paths)
        p = Parsers.parse_proto_file(abs_path)
        parsed_files[rel_path] = ResolvedProtoFile(rel_path, p)
        union!(_import_paths, import_paths(p))
    end
    resolve_imports!(_import_paths, parsed_files, search_directories)

    if isnothing(output_directory)
        output_directory = mktempdir(tempdir(); prefix="jl_proto_", cleanup=false)
        @info output_directory
    else
        isdir(output_directory) || error("`output_directory` \"$output_directory\" doesn't exist")
        output_directory = abspath(output_directory)
    end

    foreach(p->get_all_transitive_imports!(p, parsed_files), values(parsed_files))
    # Files within the same package could use definitions from different files
    # without fully qualifying their name -- on Julia side, we need to make sure
    # the files are read in order that respect these implicit dependencies.
    resolve_inter_package_references!(parsed_files, options)
    sorted_files, cyclical_imports = _topological_sort(parsed_files)
    !isempty(cyclical_imports) && throw(error(string(
        "Detected cyclical dependency among following imports: $cyclical_imports, ",
        "possibly, the individual files are resolvable, but their `package`s are not."
    )))
    sorted_files = [parsed_files[sorted_file] for sorted_file in sorted_files]
    n = Namespaces(sorted_files, output_directory, parsed_files)
    for m in n.non_namespaced_protos
        dst_path = joinpath(output_directory, proto_script_name(m))
        CodeGenerators.translate(dst_path, m, parsed_files, options)
    end
    for m in values(n.packages)
        generate_package(m, output_directory, parsed_files, options)
    end
    return nothing
end


export protojl

end # CodeGenerators