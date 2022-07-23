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
import ..ProtocolBuffers: VENDORED_WELLKNOWN_TYPES_PARENT_PATH, PACKAGE_VERSION
import ..ProtocolBuffers: _topological_sort, get_upstream_dependencies!

_is_repeated_field(f::AbstractProtoFieldType) = f.label == Parsers.REPEATED
_is_repeated_field(::OneOfType) = false

struct ResolvedProtoFile
    import_path::String
    proto_file::ProtoFile
end

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
    imports::Set{String}
    file_map::Dict{String,ResolvedProtoFile}
    _curr_cyclic_defs::Set{String}
    _toplevel_name::Ref{String}
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
    _protojl(relative_paths, search_directories, output_directory, options)
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
    ns = NamespaceTrie(values(parsed_files))
    create_namespaced_packages(ns, output_directory, output_directory, parsed_files, options)
    return nothing
end


export protojl

end # CodeGenerators