module ProtocolBuffers
import EnumX
import TranscodingStreams
import BufferedStreams
using TOML

#TODO: This has to be removed, but is needed until
#      https://github.com/JuliaIO/BufferedStreams.jl/pull/67
#       is merged.
Base.position(x::BufferedStreams.BufferedOutputStream) = max(0, position(x.sink) + x.position - 1)

# TODO:
# - Services & RPC
# - Support proper julia package generation when proto packages share a dependency
# - Preserve docstrings
# - Text Format
# - Vendor proto definitions of common Julia types and dedicated methods for encode/decode
#    * Int8, UInt8, Int16, UInt16, Int128, UInt128, Float16, UUID, Date, DateTime, Rational
# - Add a metadata method to query integer encodings (varint / zigzag / fixed)
# - well-known Any type support
# - configs for protojl:
#    * Allow the user to use inline string for specific message string fields
#    * Make Dicts robust to missing values where possible
# - Extensions

const PACKAGE_VERSION = let
    project = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
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

import .Lexers
import .Parsers
import .CodeGenerators
import .CodeGenerators: protojl
import .Codecs
import .Codecs: decode, decode!, encode, AbstractProtoDecoder, AbstractProtoEncoder, ProtoDecoder, BufferedVector, ProtoEncoder, message_done, decode_tag, skip, _encoded_size

# For codegen/metadata_methods.jl
"""
    reserved_fields(::Type{T}) where T

Return a named tuple of reserved field `names` and `numbers` from the original proto message definition.
The numbers might be individual integers or integer ranges.
"""
function reserved_fields(::Type{T}) where T
    return (names = String[], numbers = Union{Int,UnitRange{Int}}[])
end
"""
    extendable_field_numbers(::Type{T}) where T

Return `extensions` field numbers from the original proto message definition.
The numbers might be individual integers or integer ranges.
"""
function extendable_field_numbers(::Type{T}) where T
    return Union{Int,UnitRange{Int}}[]
end
"""
    oneof_field_types(::Type{T}) where T

Return a named tuple of `oneof` field names to the full NamedTuple type describing the type individual `oneof` options.
Returns an empty named tuple, `(;)`, if the original proto message doesn't contain any `oneof` fields
"""
function oneof_field_types(::Type{T}) where T
    return (;)
end
"""
    field_numbers(::Type{T}) where T

Return a named tuple of fields names to their respective field numbers from the original proto message type.
Fields of `OneOf` types are expanded as they don't map to any single field number.
"""
function field_numbers(::Type{T}) where T
    return (;)
end
"""
    default_values(::Type{T}) where T

Return a named tuple of fields names to their respective default values from the original proto message type.
Fields of `OneOf` types are expanded as they don't map to any single default value.

`required` message-fields do not have a default value and are represented as `Ref{MyFieldMessageType}()`.
"""
function default_values(::Type{T}) where T
    return (;)
end

"""
    decode(d::AbstractProtoDecoder, ::Type{T}) where {T}

Decode a protobuf message from `IO` wrapped by `AbstractProtoDecoder` into s struct of type T.

For general structs, these methods should be generated using the [`protojl`](@ref) function.
"""
function decode(d::AbstractProtoDecoder, ::Type{T}) where {T} end

"""
    encode(d::AbstractProtoDecoder, x::T) where {T}

Encode struct `x` of type `T` as protobuf message to `IO` wrapped by `AbstractProtoEncoder`.

For general structs, these methods should be generated using the [`protojl`](@ref) function.
"""
function encode(e::AbstractProtoEncoder, x::T) where {T} end

export protojl, encode, ProtoEncoder, decode, decode!, ProtoDecoder
export OneOf
export reserved_fields, extendable_field_numbers, oneof_field_types, field_numbers, default_values

if Base.VERSION >= v"1.4.2"
    include("precompile.jl")
    _precompile_()
end

end # module
