module Codecs
# TODO: Messages should be initialized as Ref{Union{MessageType,Nothing}}(nothing)
# since, according to the docs, a message could be missing from a payload and the
# decoder should handle it. This means all struct fields need to be Union{Nothing,T}
# at least if not REQUIRED. Bummer.

@enum(WireType::UInt32, VARINT=0, FIXED64=1, LENGTH_DELIMITED=2, START_GROUP=3, END_GROUP=4, FIXED32=5)

struct ProtoDecoder{I<:IO,F<:Function}
    io::I
    message_done::F
end
message_done(d::ProtoDecoder) = d.message_done(d.io)
ProtoDecoder(io::IO) = ProtoDecoder(io, eof)
function try_eat_end_group(d::ProtoDecoder, wire_type::WireType)
    wire_type == START_GROUP && read(d, UInt8) # read end group
    return nothing
end
struct ProtoEncoder{I<:IO}
    io::I
end

zigzag_encode(x::T) where {T <: Integer} = xor(x << 1, x >> (8 * sizeof(T) - 1))
zigzag_decode(x::T) where {T <: Integer} = xor(x >> 1, -(x & T(1)))
_max_varint_size(::Type{T}) where {T} = (sizeof(T) + div(sizeof(T), 4))
_varint_size(x) = cld((8sizeof(x) - leading_zeros(x)), 7)
_varint_size1(x) = max(1, _varint_size(x))

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
_grow_by(::Type{T}) where {T<:Union{UInt32,UInt64,Int64,Int32,Base.Enum}} = div(128, sizeof(T))
_grow_by(::Type) = 16
_grow_by(::Type{T}) where {T<:Union{Bool,UInt8}} = 64


include("vbyte.jl")
include("decode.jl")
include("encode.jl")

end # module