module Codecs

@enum(WireType, VARINT=0, FIXED64=1, LENGTH_DELIMITED=2, START_GROUP=3, END_GROUP=4, FIXED32=5)

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

# Any of the following decode statements can appear in a translated
# decode method.
decode(d::ProtoDecoder, ::Type{T}) where {T} = decode(d.io, T)
decode(d::ProtoDecoder, ::Type{T}, ::Type{V}) where {T,V} = decode(d.io, T, V)
decode!(d::ProtoDecoder, buffer::Base.RefValue) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, buffer::Vector) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, buffer::Vector, ::Type{V}) where {V} = decode!(d.io, buffer, V)
decode!(d::ProtoDecoder, buffer::Dict) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, buffer::Dict, ::Type{V}) where {V} = decode!(d.io, buffer, V)


zigzag_encode(x::T) where {T <: Integer} = xor(x << 1, x >> (8 * sizeof(T) - 1))
zigzag_decode(x::T) where {T <: Integer} = xor(x >> 1, -(x & T(1)))

@inline function vbyte_decode(io, ::Type{T}) where {T<:Union{UInt32,Int32}}
    b = T(read(io, UInt8))
    b < 0x80 && return b

    x = b & 0x7F
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 7))

    x |= (b & 0x7F) << 7
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 14))

    x |= (b & 0x7F) << 14
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 21))

    x |= (b & 0x7F) << 21
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 28))

    x |= (b & 0x7F) << 28
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 7))

    return zero(T)
end

@inline function vbyte_decode(io, ::Type{T}) where {T<:Union{UInt64,Int64}}
    b = T(read(io, UInt8))
    b < 0x80 && return b

    x = b & 0x7F
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 7))

    x |= (b & 0x7F) << 7
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 14))

    x |= (b & 0x7F) << 14
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 21))

    x |= (b & 0x7F) << 21
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 28))

    x |= (b & 0x7F) << 28
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 35))

    x |= (b & 0x7F) << 35
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 42))

    x |= (b & 0x7F) << 42
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 49))

    x |= (b & 0x7F) << 49
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 56))

    x |= (b & 0x7F) << 56
    b = T(read(io, UInt8))
    b < 0x80 && return (x | (b << 63))

    return zero(T)
end

# https://discourse.julialang.org/t/allocation-due-to-noinline-for-unsafe-read-and-unsafe-write-in-io-jl/69421
@inline function _unsafe_write(io::IO, ref::Ref{T}, nb::Integer) where T
    GC.@preserve ref unsafe_write(io, Base.unsafe_convert(Ref{T}, ref)::Ptr, nb)
end

@inline function vbyte_encode(io::IO, x::T) where {T <: Union{UInt32,Int32}}
    if (x < (1 << 7))
        write(io, x & 0x7F)
    elseif (x < (1 << 14))
        _unsafe_write(io,
            Ref((
                UInt8(((x >> 0) & 0x7F) | (1 << 7)),
                UInt8(((x >> 7))),
            )),
            2,
        )
    elseif (x < (1 << 21))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14))),
            )),
            3,
        )
    elseif (x < (1 << 28))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21))),
            )),
            4,
        )
    else
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28))),
            )),
            5,
        )
    end
    return nothing;
end

@inline function vbyte_encode(io::IO, x::T) where {T <: Union{UInt64,Int64}}
    if (x < (1 << 7))
        write(io, x & 0x7F)
    elseif (x < (1 << 14))
        _unsafe_write(io,
            Ref((
                UInt8(((x >> 0) & 0x7F) | (1 << 7)),
                UInt8(((x >> 7))),
            )),
            2,
        )
    elseif (x < (1 << 21))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14))),
            )),
            3,
        )
    elseif (x < (1 << 28))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21))),
            )),
            4,
        )
    elseif (x < (1 << 35))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28))),
            )),
            5,
        )
    elseif (x < (1 << 42))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28) & 0x7F) | (1 << 7)),
                UInt8(((x >> 35))),
            )),
            6,
        )
    elseif (x < (1 << 49))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28) & 0x7F) | (1 << 7)),
                UInt8(((x >> 35) & 0x7F) | (1 << 7)),
                UInt8(((x >> 42))),
            )),
            7,
        )
    elseif (x < (1 << 56))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28) & 0x7F) | (1 << 7)),
                UInt8(((x >> 35) & 0x7F) | (1 << 7)),
                UInt8(((x >> 42) & 0x7F) | (1 << 7)),
                UInt8(((x >> 49))),
            )),
            8,
        )
    elseif (x < (1 << 56))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28) & 0x7F) | (1 << 7)),
                UInt8(((x >> 35) & 0x7F) | (1 << 7)),
                UInt8(((x >> 42) & 0x7F) | (1 << 7)),
                UInt8(((x >> 49) & 0x7F) | (1 << 7)),
                UInt8(((x >> 56))),
            )),
            9,
        )
    else
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21) & 0x7F) | (1 << 7)),
                UInt8(((x >> 28) & 0x7F) | (1 << 7)),
                UInt8(((x >> 35) & 0x7F) | (1 << 7)),
                UInt8(((x >> 42) & 0x7F) | (1 << 7)),
                UInt8(((x >> 49) & 0x7F) | (1 << 7)),
                UInt8(((x >> 56) & 0x7F) | (1 << 7)),
                UInt8(((x >> 63))),
            )),
            10,
        )
    end
    return nothing;
end

function decode_tag(d::ProtoDecoder)
    b = vbyte_decode(d.io, UInt32)
    field_number = b >> 3
    wire_type = WireType(b & 0x07)
    return field_number, wire_type
end

_max_varint_size(::Type{T}) where {T} = (sizeof(T) + div(sizeof(T), 4))

# uint32, uint64
decode(io::IO, ::Type{T}) where {T <: Union{UInt32,UInt64}} = vbyte_decode(io, T)
# int32: Negative int32 are encoded in 10 bytes...
# TODO: add check the int is negative if larger thatn typemax UInt32
decode(io::IO, ::Type{Int32}) = reinterpret(Int32, UInt32(vbyte_decode(io, UInt64) % UInt32))
# int64
decode(io::IO, ::Type{Int64}) = reinterpret(Int64, vbyte_decode(io, UInt64))
# sfixed32, sfixed64, # fixed32, fixed64
decode(io::IO, ::Type{T}, ::Val{:fixed}) where {T <: Union{Int32,Int64}} = read(io, T)
# sint32, sint64
function decode(io::IO, ::Type{T}, ::Val{:zigzag}) where {T <: Union{Int32,Int64}}
    return convert(T, zigzag_decode(vbyte_decode(io, unsigned(T))))
end
decode(io::IO, ::Type{Bool}) = Bool(read(io, UInt8))
decode(io::IO, ::Type{T}) where {T <: Base.Enum} = T(vbyte_decode(io, Int32))
decode(io::IO, ::Type{T}) where {T <: Union{Float64,Float32}} = read(io, T)
function decode!(io::IO, buffer::Dict{K,V}) where {K,V}
    len = vbyte_decode(io, UInt32) + position(io)
    while position(io) < len
        key = decode(io, K)
        val = decode(io, V)
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Nothing,W}}}) where {K,V,W}
    len = vbyte_decode(io, UInt32) + position(io)
    while position(io) < len
        key = decode(io, K)
        val = decode(io, V, Var{W})
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Q,Nothing}}}) where {K,V,Q}
    len = vbyte_decode(io, UInt32) + position(io)
    while position(io) < len
        key = decode(io, K, Var{Q})
        val = decode(io, V)
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Q,W}}}) where {K,V,Q,W}
    len = vbyte_decode(io, UInt32) + position(io)
    while position(io) < len
        key = decode(io, K, Var{Q})
        val = decode(io, V, Var{W})
        buffer[key] = val
    end
    nothing
end

function decode(io::IO, ::Type{String})
    len = vbyte_decode(io, UInt32)
    return String(read(io, len))
end
function decode(io::IO, ::Type{Vector{UInt8}})
    len = vbyte_decode(io, UInt32)
    return read(io, len)
end

# packed
function decode!(io::IO, buffer::Vector{T}, ::Type{Vector{T}}) where T
    len = vbyte_decode(io, UInt32)
    endpos = len + position(io)
    while position(io) < endpos
        push!(buffer, decode(io, T))
    end
    return nothing
end

# TODO: Messages should be initialized as Ref{Union{MessageType,Nothing}}(nothing)
function decode!(io::IO, buffer::Vector{T}) where {T <: Union{Int64,UInt32,UInt32}}
    len = vbyte_decode(io, UInt32)
    if len > _max_varint_size(T)
        sizehint!(buffer, length(buffer) + cld(len, _max_varint_size(T)))
    end
    endpos = len + position(io)
    while position(io) < endpos
        push!(buffer, decode(io, T))
    end
    return nothing
end

function decode!(io::IO, buffer::Vector{Int32})
    len = vbyte_decode(io, UInt32)
    if len > _max_varint_size(UInt64) # negative int32 take up 10 bytes
        sizehint!(buffer, length(buffer) + cld(len, _max_varint_size(UInt64)))
    end
    endpos = len + position(io)
    while position(io) < endpos
        push!(buffer, decode(io, Int32))
    end
    return nothing
end

function decode!(io::IO, buffer::Vector{T}) where {T <: Base.Enum}
    len = vbyte_decode(io, UInt32)
    if len > _max_varint_size(UInt32)
        sizehint!(buffer, length(buffer) + cld(len, _max_varint_size(UInt32)))
    end
    endpos = len + position(io)
    while position(io) < endpos
        push!(buffer, decode(io, T))
    end
    return nothing
end

function decode!(io::IO, buffer::Vector{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
    len = vbyte_decode(io, UInt32)
    if len > _max_varint_size(T)
        sizehint!(buffer, length(buffer) + cld(len, _max_varint_size(T)))
    end
    endpos = len + position(io)
    while position(io) < endpos
        push!(buffer, decode(io, T, Val{:zigzag}))
    end
    return nothing
end

function decode!(io::IO, buffer::Vector{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64}}
    len = vbyte_decode(io, UInt32)
    n_incoming = div(len, sizeof(T))
    n_current = length(buffer)
    resize!(buffer, n_current + n_incoming)
    endpos = len + position(io)
    for i in (n_current+1):n_incoming
        @inbounds buffer[i] = decode(io, T, Val{:fixed})
    end
    @assert position(io) == endpos
    return nothing
end

function decode!(io::IO, buffer::Vector{T}) where {T <: Union{Bool,Float32,Float64}}
    len = vbyte_decode(io, UInt32)
    n_incoming = div(len, sizeof(T))
    n_current = length(buffer)
    resize!(buffer, n_current + n_incoming)
    endpos = len + position(io)
    for i in (n_current+1):n_incoming
        @inbounds buffer[i] = decode(io, T)
    end
    @assert position(io) == endpos
    return nothing
end

function decode!(io::IO, buffer::Base.RefValue{T}) where {T}
    len = vbyte_decode(io, UInt32)
    endpos = len + position(io)
    if isassigned(buffer)
        buffer[] =_merge_structs(buffer[], decode(d, T))
    else
        buffer[] = decode(d, T)
    end
    @assert position(io) == endpos
    return nothing
end

# From docs: Normally, an encoded message would never have more than one instance of a non-repeated field.
# ...
# For embedded message fields, the parser merges multiple instances of the same field, as if with the
# Message::MergeFrom method – that is, all singular scalar fields in the latter instance replace
# those in the former, singular embedded messages are merged, and repeated fields are concatenated.
# The effect of these rules is that parsing the concatenation of two encoded messages
# produces exactly the same result as if you had parsed the two messages separately
# and merged the resulting objects
@generated function _merge_structs(s1::Union{Nothing,T}, s2::T) where {T}
    isnothing(s1) && return s2
    isnothing(s2) && return s2
    # TODO: Error gracefully on unsuported types like Missing, Matrices...
    #       Would be easier if we have a HolyTrait for user defined structs
    merged_values = Tuple(
        (
            type <: Union{Float64,Float32,Int32,Int64,UInt64,UInt32,Bool,String,Vector{UInt8}} ? :(s2.$name) :
            type <: AbstractVector ? :(vcat(s1.$name, s2.$name)) :
            :(_merge_structs(s1.$name, s2.$name))
        )
        for (name, type)
        in zip(fieldnames(T), fieldtypes(T))
    )
    return quote T($(merged_values...)) end
end

@inline function Base.skip(d::ProtoDecoder, wire_type::WireType)
    if wire_type == VARINT
        while read(d.io, UInt8) >= 0x80 end
    elseif wire_type == FIXED64
        skip(d.io, 8)
    elseif wire_type == LENGTH_DELIMITED
        len = vbyte_decode(d, UInt32)
        skip(d.io, len)
    elseif wire_type == START_GROUP
        #TODO: this is not verified
        len = vbyte_decode(d, UInt32)
        skip(d.io, len)
    elseif wire_type == FIXED32
        skip(d.io, 4)
    else wire_type == END_GROUP
        error("Encountered END_GROUP wiretype while skipping")
    end
    return nothing
end

end # module