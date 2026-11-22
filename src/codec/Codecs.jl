module Codecs

using BufferedStreams: BufferedOutputStream, BufferedInputStream

@enum(WireType::UInt32, VARINT=0, FIXED64=1, LENGTH_DELIMITED=2, START_GROUP=3, END_GROUP=4, FIXED32=5)

abstract type AbstractProtoDecoder end
abstract type AbstractProtoEncoder end
get_stream(d::AbstractProtoDecoder) = d.io

mutable struct ProtoDecoder{I<:IO,F<:Function} <: AbstractProtoDecoder
    const io::I
    const message_done::F
end
function message_done(d::AbstractProtoDecoder, endpos::Int, group::Bool)
    io = get_stream(d)
    if group
        done = _peek_end_group(io)
    else
        done = d.message_done(io) || (endpos > 0 && position(io) >= endpos)
    end
    return done
end
ProtoDecoder(io::IO) = ProtoDecoder(io, eof)

# The low 3 bits of a tag's first byte are its wire type. An END_GROUP tag also carries the
# group's field number, so it can be longer than one byte. Consume it when found.
function _peek_end_group(io::IO)
    done = peek(io) & 0x07 == UInt8(END_GROUP)
    done && vbyte_decode(io, UInt32)
    return done
end

struct ProtoEncoder{I<:IO} <: AbstractProtoEncoder
    io::I
end

zigzag_encode(x::T) where {T <: Integer} = xor(x << 1, x >> (8 * sizeof(T) - 1))
zigzag_decode(x::T) where {T <: Integer} = xor(x >> 1, -(x & T(1)))

mutable struct BufferedVector{T}
    elements::Vector{T}
    occupied::Int
end
BufferedVector{T}() where {T} = BufferedVector(T[], 0)
BufferedVector(v::Vector{T}) where {T} = BufferedVector{T}(v, length(v))
Base.getindex(x::BufferedVector) = resize!(x.elements, x.occupied)
empty!(buffer::BufferedVector) = buffer.occupied = 0
@inline function Base.setindex!(buffer::BufferedVector{T}, x::T) where {T}
    if length(buffer.elements) == buffer.occupied
        Base._growend!(buffer.elements, _grow_by(T))
    end
    buffer.occupied += 1
    @inbounds buffer.elements[buffer.occupied] = x
end
_grow_by(::Type{T}) where {T<:Union{UInt32,UInt64,Int64,Int32,Enum{Int32},Enum{UInt32}}} = div(128, sizeof(T))
_grow_by(::Type) = 16
_grow_by(::Type{T}) where {T<:Union{Bool,UInt8}} = 64

include("encoded_size.jl")
include("vbyte.jl")
include("decode.jl")
include("encode.jl")

export encode, decode


# Backwards compatibility with old older decode methods

message_done(d::ProtoDecoder) = d.message_done(d.io)
struct LengthDelimitedProtoDecoder{I<:IO} <: AbstractProtoDecoder
    io::I
    endpos::Int
end
message_done(d::LengthDelimitedProtoDecoder) = d.endpos == position(d.io)

struct GroupProtoDecoder{I<:IO} <: AbstractProtoDecoder
    io::I
end
function message_done(d::GroupProtoDecoder)
    return _peek_end_group(d.io)
end

end # module
