function encode_tag(e::ProtoEncoder, field_number, wire_type::WireType)
    vbyte_encode(e.io, (UInt32(field_number) << 3) | UInt32(wire_type))
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{T}) where {T}
    _io = IOBuffer(sizehint=sizeof(T))
    Base.ensureroom(e.io, length(x) * sizeof(T))
    for el in x
        _encode(_io, el)
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(position(_io)))
        write(_io, e.io)
        seekstart(_io)
    end
    close(_io)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::T) where {T}
    _io = PipeBuffer(Vector{UInt8}(undef, sizeof(T)))
    _encode(_io, x)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(position(_io)))
    write(_io, e.io)
    close(_io)
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{UInt32,UInt64}}
    vbyte_encode(io, x)
    return nothing
end

@inline function _encode(io::IO, x::Int64)
    vbyte_encode(io, reinterpret(UInt64, x))
    return nothing
end

function _encode(io::IO, x::Int32)
    x < 0 ? vbyte_encode(io, reinterpret(UInt64, Int64(x))) : vbyte_encode(io, reinterpret(UInt32, x))
    return nothing
end

function _encode(io::IO, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,Int64,Vector{Int32},Vector{Int64},UInt32,UInt64,Vector{UInt32},Vector{UInt64}}}
    write(io, x)
    return nothing
end

function _encode(io::IO, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    vbyte_encode(io, reinterpret(unsigned(T), zigzag_encode(x)))
    return nothing
end

function _encode(io::IO, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    Base.ensureroom(io, length(x))
    for el in x
        _encode(io, el, Val{:zigzag})
    end
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{Bool,Float32,Float64,String}}
    write(io, x)
    return nothing
end

function _encode(io::IO, x::Vector{T}) where {T<:Union{Bool,UInt8,Float32,Float64}}
    write(io, x)
    return nothing
end

function _encode(io::IO, x::Base.CodeUnits{UInt8, String})
    write(io, x)
    return nothing
end

function _encode(io::IO, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int32,Int64,Base.Enum}}
    Base.ensureroom(io, length(x))
    for el in x
        _encode(io, el)
    end
    return nothing
end

function _encode(io::IO, x::Dict{K,V}) where {K,V}
    Base.ensureroom(io, 2length(x))
    for (k, v) in x
        _encode(io, k)
        _encode(io, v)
    end
    nothing
end

function _encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Nothing,Nothing}}}) where {K,V}
    Base.ensureroom(io, 2length(x))
    for (k, v) in x
        _encode(io, k)
        _encode(io, v)
    end
    nothing
end

function encode(e::ProtoEncoder, x::Dict{K,V}, ::Type{Val{Tuple{Nothing,W}}}) where {K,V,W}
    Base.ensureroom(io, 2length(x))
    for (k, v) in x
        _encode(io, k)
        _encode(io, v, Val{W})
    end
    nothing
end

function _encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Q,Nothing}}}) where {K,V,Q}
    Base.ensureroom(io, 2length(x))
    for (k, v) in x
        _encode(io, k, Val{Q})
        _encode(io, v)
    end
    nothing
end

function _encode(io::IO, x::Dict{K,V}, ::Type{Val{Tuple{Q,W}}}) where {K,V,Q,W}
    Base.ensureroom(io, 2length(x))
    # FIXME: `Nothing` makes is here as Q for some reason:/
    @info Q W
    for (k, v) in x
        _encode(io, k, Val{Q})
        _encode(io, v, Val{W})
    end
    nothing
end



function encode(e::ProtoEncoder, i::Int, x::T) where {T<:Union{Bool,Int32,Int64,UInt32,UInt64}}
    encode_tag(e, i, VARINT)
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(e, i, VARINT)
    _encode(e.io, x, Val{:zigzag})
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,UInt32}}
    encode_tag(e, i, FIXED32)
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Float32)
    encode_tag(e, i, FIXED32)
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int64,UInt64}}
    encode_tag(e, i, FIXED64)
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Float64)
    encode_tag(e, i, FIXED64)
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{T}) where {T<:Union{Bool,UInt8,Float32,Float64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Base.CodeUnits{UInt8, String})
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{String})
    Base.ensureroom(e.io, 9length(x))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{Vector{UInt8}})
    Base.ensureroom(e.io, sizeof(x) + length(x))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::String)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:fixed}}) where {T<:Union{UInt32,UInt64,Int32,Int64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int32,Int64}}
    _io = IOBuffer(sizehint=length(x), maxsize=10length(x)) # TODO: is sizehint necessary when we ensureroom in _encode?
    _encode(_io, x)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(position(_io)))
    seekstart(_io)
    write(e.io, _io)
    close(_io)
    return nothing
end

function encode(e::ProtoEncoder, i::Int, x::Dict{K,V}) where {K,V}
    _io = IOBuffer(sizehint=2length(x))
    _encode(_io, x)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(position(_io)))
    seekstart(_io)
    write(e.io, _io)
    close(_io)
    nothing
end

function encode(e::ProtoEncoder, i::Int, x::Dict{K,V}, ::Type{W}) where {K,V,W}
    _io = IOBuffer(sizehint=2length(x))
    _encode(_io, x, W)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(position(_io)))
    seekstart(_io)
    write(e.io, _io)
    close(_io)
    nothing
end

function encode(e::ProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    _io = IOBuffer(sizehint=cld(sizeof(x), _max_varint_size(T)))
    _encode(_io, x, Val{:zigzag})
    vbyte_encode(e.io, UInt32(position(_io)))
    seekstart(_io)
    write(e.io, _io)
    close(_io)
    return nothing
end
