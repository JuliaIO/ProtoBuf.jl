module Codecs

using BufferedStreams: BufferedOutputStream, BufferedInputStream

macro _const(ex)
    ex = esc(ex)
    if VERSION < v"1.8.0-DEV.1148"
        return ex
    else
        return Expr(:const, ex)
    end
end
const var"@const" = var"@_const"

@enum(WireType::UInt32, VARINT=0, FIXED64=1, LENGTH_DELIMITED=2, START_GROUP=3, END_GROUP=4, FIXED32=5)

abstract type AbstractProtoDecoder end
abstract type AbstractProtoEncoder end
get_stream(d::AbstractProtoDecoder) = d.io

mutable struct ProtoDecoder{I<:IO,F<:Function} <: AbstractProtoDecoder
    @const io::I
    @const message_done::F
end
function message_done(d::AbstractProtoDecoder, endpos::Int, group::Bool)
    io = get_stream(d)
    if group
        done = peek(io) == UInt8(END_GROUP)
        done && skip(io, 1)
    else
        done = d.message_done(io) || (endpos > 0 && position(io) >= endpos)
    end
    return done
end
ProtoDecoder(io::IO) = ProtoDecoder(io, eof)

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

struct LengthDelimitedProtoDecoder{I<:IO} <: AbstractProtoDecoder
    io::I
    endpos::Int
end
message_done(d::LengthDelimitedProtoDecoder) = d.endpos == position(d.io)

struct GroupProtoDecoder{I<:IO} <: AbstractProtoDecoder
    io::I
end
function message_done(d::GroupProtoDecoder)
    done = peek(d.io) == UInt8(END_GROUP)
    done && skip(d.io, 1)
    return done
end

end # module
