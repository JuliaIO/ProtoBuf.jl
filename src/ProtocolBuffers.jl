module ProtocolBuffers
import EnumX
import TranscodingStreams
using TOML

# TODO:
# - configs for protojl:
#    * Allow the user to use inline string for specific message string fields
#    * Allow the user to mark dict values and non-optional messages as Union{nothing,T} to
#      be more resilient to cases when the sender sends an incomplete message etc.
# - Services & RPC
# - Extensions


const PACKAGE_VERSION = let
    project = TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))
    VersionNumber(project["version"])
end

const VENDORED_WELLKNOWN_TYPES_PARENT_PATH = dirname(@__FILE__)
struct OneOf{T}
    name::Symbol
    value::T
end

Base.getindex(t::OneOf) = t.value
Base.Pair(t::OneOf) = t.name => t.value


include("topological_sort.jl")

include("lexing/Tokens.jl")
include("lexing/Lexers.jl")

include("parsing/Parsers.jl")
include("codegen/CodeGenerators.jl")
include("codec/Codecs.jl")

import .Parsers
import .CodeGenerators
import .CodeGenerators: protojl
import .Codecs
import .Codecs: decode, decode!, encode, AbstractProtoDecoder, AbstractProtoEncoder, ProtoDecoder, BufferedVector, ProtoEncoder, message_done, try_eat_end_group, decode_tag, skip

# For codegen/metadata_methods.jl
"""
    reserved_fields(::Type{T}) where T

Return a named tuple of reserved field `names` and `numbers` from the original proto message definition.
The numbers might be individual integers or integer ranges.
"""
function reserved_fields end
"""
    extendable_field_numbers(::Type{T}) where T

Return `extensions` field numbers from the original proto message definition.
The numbers might be individual integers or integer ranges.
"""
function extendable_field_numbers end
"""
    oneof_field_types(::Type{T}) where T

Return a named tuple of `oneof` field names to the full NamedTuple type describing the type individual `oneof` options.
Returns an empty named tuple, `(;)`, if the original proto message doesn't contain any `oneof` fields
"""
function oneof_field_types end
"""
    field_numbers(::Type{T}) where T

Return a named tuple of fields names to their respective field numbers from the original proto message type.
Fields of `OneOf` types are expanded as they don't map to any single field number.
"""
function field_numbers end
"""
    default_values(::Type{T}) where T

Return a named tuple of fields names to their respective default values from the original proto message type.
Fields of `OneOf` types are expanded as they don't map to any single default value.

`BufferedVector` and `Ref` types must be dereferenced (`x[]`) to get the true default value. These containers are used
for performance and dispatch reasons during the decoding stage. Note that dereferencing an unassigned `Ref` type (`Ref{T}()`)
will throw an error -- they are used for non-optional message fields which don't have a default value.
"""
function default_values end

export protojl, encode, ProtoEncoder, decode, decode!, ProtoDecoder

end # module
