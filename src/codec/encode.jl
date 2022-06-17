# encode(d::ProtoEncoder, x::T) where {T} = encode(d.io, x)
# encode(d::ProtoEncoder, i::Int, x::T) where {T} = encode(d.io, i, x)
# encode(d::ProtoEncoder, i::Int, x::T, ::Type{V}) where {T,V} = encode(d.io, i, x, V)
# encode(d::ProtoEncoder, i::Int, buffer::Base.RefValue) = encode(d.io, i, buffer)
# encode(d::ProtoEncoder, i::Int, buffer::Vector) = encode(d.io, i, buffer)
# encode(d::ProtoEncoder, i::Int, buffer::Vector, ::Type{V}) where {V} = encode(d.io, i, buffer, V)
# encode(d::ProtoEncoder, i::Int, buffer::Dict) = encode(d.io, i, buffer)
# encode(d::ProtoEncoder, i::Int, buffer::Dict, ::Type{V}) where {V} = encode(d.io, i, buffer, V)

function encode_tag(io::IO, field_number, wire_type::WireType)
    vbyte_encode(io, UInt32(field_number << 3) | UInt32(wire_type))
    return nothing
end

# https://discourse.julialang.org/t/allocation-due-to-noinline-for-unsafe-read-and-unsafe-write-in-io-jl/69421
@inline function _unsafe_write(io::IO, ref::Ref{T}, nb::Integer) where T
    GC.@preserve ref unsafe_write(io, Base.unsafe_convert(Ref{T}, ref)::Ptr, nb)
end

@inline function vbyte_encode(io::IO, x::T) where {T <: Union{UInt32,Int32}}
    if (x < (one(UInt32) << 7))
        write(io, UInt8(x & 0x7F))
    elseif (x < (one(UInt32) << 14))
        _unsafe_write(io,
            Ref((
                UInt8(((x >> 0) & 0x7F) | (1 << 7)),
                UInt8(((x >> 7))),
            )),
            2,
        )
    elseif (x < (one(UInt32) << 21))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14))),
            )),
            3,
        )
    elseif (x < (one(UInt32) << 28))
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
    if (x < (one(UInt64) << 7))
        write(io, UInt8(x & 0x7F))
    elseif (x < (one(UInt64) << 14))
        _unsafe_write(io,
            Ref((
                UInt8(((x >> 0) & 0x7F) | (1 << 7)),
                UInt8(((x >> 7))),
            )),
            2,
        )
    elseif (x < (one(UInt64) << 21))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14))),
            )),
            3,
        )
    elseif (x < (one(UInt64) << 28))
        _unsafe_write(io,
            Ref((
                UInt8(((x >>  0) & 0x7F) | (1 << 7)),
                UInt8(((x >>  7) & 0x7F) | (1 << 7)),
                UInt8(((x >> 14) & 0x7F) | (1 << 7)),
                UInt8(((x >> 21))),
            )),
            4,
        )
    elseif (x < (one(UInt64) << 35))
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
    elseif (x < (one(UInt64) << 42))
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
    elseif (x < (one(UInt64) << 49))
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
    elseif (x < (one(UInt64) << 56))
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
    elseif (x < (one(UInt64) << 63))
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

function encode(io::IO, i::Int, x::T) where {T}
    tmpbuf = IOBuffer(sizehint=sizeof(T))
    encode(tmpbuf, x)
    encode_tag(io, i, LENGTH_DELIMITED)
    vbyte_encode(io, UInt32(position(tmpbuf)))
    write(tmpbuf, io)
    close(tmpbuf)
    return nothing
end

function encode(io::IO, x::T) where {T<:Union{Int64,UInt32,UInt64}}
    vbyte_encode(io, x)
    return nothing
end

function encode(io::IO, x::Int32)
    vbyte_encode(io, Int64(x))
    return nothing
end

function encode(io::IO, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,Int64,Vector{Int32},Vector{Int64}}}
    write(io, x)
    return nothing
end

function encode(io::IO, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    vbyte_encode(io, zigzag_encode(x))
    return nothing
end

function encode(io::IO, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    for el in x
        vbyte_encode(io, zigzag_encode(el))
    end
    return nothing
end

function encode(io::IO, x::T) where {S<:Union{Bool,UInt8,Float32,Float64},T<:Union{Bool,Float32,Float64,String,Vector{S}}}
    write(io, x)
    return nothing
end

function encode(io::IO, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int64,Int32}}
    for el in x
        vbyte_encode(io, el)
    end
    return nothing
end

function encode(io::IO, x::Dict{K,V}) where {K,V}
    for (k, v) in values(x)
        encode(io, k)
        encode(io, v)
    end
    nothing
end

function encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Nothing,W}}}) where {K,V,W}
    for (k, v) in values(x)
        encode(io, k)
        encode(io, v, Var{W})
    end
    nothing
end

function encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Q,Nothing}}}) where {K,V,Q}
    for (k, v) in values(x)
        encode(io, k, Var{Q})
        encode(io, v)
    end
    nothing
end

function encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Q,W}}}) where {K,V,Q,W}
    for (k, v) in values(x)
        encode(io, k, Var{Q})
        encode(io, v, Var{W})
    end
    nothing
end



function encode(io::IO, i::Int, x::T) where {T<:Union{Bool,Int32,Int64,UInt32,UInt64}}
    encode_tag(io, i, VARINT)
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(io, i, VARINT)
    encode(io, x, Var{:zigzag})
    return nothing
end

function encode(io::IO, i::Int, x::Int32, ::Type{Val{:fixed}})
    encode_tag(io, i, FIXED32)
    encode(io, x, Var{:fixed})
    return nothing
end

function encode(io::IO, i::Int, x::Float32)
    encode_tag(io, i, FIXED32)
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::Int64, ::Type{Val{:fixed}})
    encode_tag(io, i, FIXED64)
    encode(io, x, Var{:fixed})
    return nothing
end

function encode(io::IO, i::Int, x::Float64)
    encode_tag(io, i, FIXED64)
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::T) where {S<:Union{Bool,UInt8,Float32,Float64},T<:Union{String,Vector{S}}}
    encode_tag(io, i, LENGTH_DELIMITED)
    vbyte_encode(io, UInt32(sizeof(x)))
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::Vector{T}, ::Type{Val{:fixed}}) where {T<:Union{Int32,Int64}}
    encode_tag(io, i, LENGTH_DELIMITED)
    vbyte_encode(io, UInt32(sizeof(x)))
    encode(io, x, Var{:fixed})
    return nothing
end

function encode(io::IO, i::Int, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int64}}
    encode_tag(io, i, LENGTH_DELIMITED)
    vbyte_encode(io, UInt32(sum(_varint_size, x)))
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::Vector{Int32})
    encode_tag(io, i, LENGTH_DELIMITED)
    vbyte_encode(io, UInt32(sum(y->_varint_size(Int64(y)), x)))
    encode(io, x)
    return nothing
end

function encode(io::IO, i::Int, x::Dict{K,V}) where {K,V}
    encode_tag(io, i, LENGTH_DELIMITED)
    encode(io, x)
    nothing
end

function encode(io::IO, i::Int, x::Dict{K,V}, ::Type{W}) where {K,V,W}
    encode_tag(io, i, LENGTH_DELIMITED)
    encode(io, x, W)
    nothing
end


function encode(io::IO, i::Int, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(io, i, LENGTH_DELIMITED)
    tmpbuf = IOBuffer(sizehint=cld(sizeof(x), _max_varint_size(T)))
    encode(tmpbuf, x)
    vbyte_encode(io, UInt32(position(tmpbuf)))
    write(tmpbuf, io)
    close(tmpbuf)
    return nothing
end

# function encode2(io::IO, i::Int, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int64}}
#     encode_tag(io, i, LENGTH_DELIMITED)
#     tmpbuf = IOBuffer(sizehint=cld(sizeof(x), _max_varint_size(T)))
#     encode(tmpbuf, x)
#     vbyte_encode(io, UInt32(position(tmpbuf)))
#     write(tmpbuf, io)
#     close(tmpbuf)
#     return nothing
# end

# function encode2(io::IO, i::Int, x::Vector{Int32})
#     encode_tag(io, i, LENGTH_DELIMITED)
#     tmpbuf = IOBuffer(sizehint=cld(sizeof(x), _max_varint_size(Int64)))
#     encode(tmpbuf, x)
#     vbyte_encode(io, UInt32(position(tmpbuf)))
#     write(tmpbuf, io)
#     close(tmpbuf)
#     return nothing
# end