function encode_tag(io::IO, field_number, wire_type::WireType)
    vbyte_encode(io, (UInt32(field_number) << 3) | UInt32(wire_type))
    return nothing
end
encode_tag(e::ProtoEncoder, field_number, wire_type::WireType) = encode_tag(e.io, field_number, wire_type)
# TODO: audit usage and composability of maybe_ensure_room
maybe_ensure_room(io::IOBuffer, n) = Base.ensureroom(io, n)
maybe_ensure_room(::IO, n) = nothing

# When we don't know the lenght beforehand we
# 1. Allocate 5 bytes for the length
# 2. encode data
# 3. come back to beginning and encode the length
# 4. shift the encoded data in case we didn't use all 5 bytes allocated for length
@inline function _with_size(f, io::IOBuffer, sink, x)
    if io.seekable
        MAX_LENGTH_VARINT_BYTES = 5  # max size of a UInt32 as vbyte
        initpos = position(io)
        truncate(io, initpos + MAX_LENGTH_VARINT_BYTES) # 1.
        seek(io, initpos + MAX_LENGTH_VARINT_BYTES)
        f(sink, x) # e.g. _encode(io, x) # 2.
        endpos = position(io)
        data_len = endpos - initpos - MAX_LENGTH_VARINT_BYTES
        seek(io, initpos)                  # 3.
        vbyte_encode(io, UInt32(data_len)) # --||--
        lenght_len = position(io) - initpos
        unsafe_copyto!(io.data, initpos + lenght_len + 1, io.data, initpos + MAX_LENGTH_VARINT_BYTES + 1, data_len) # 4.
        seek(io, initpos + lenght_len + data_len)
        truncate(io, initpos + lenght_len + data_len)
    else
        vbyte_encode(io, UInt32(_encoded_size(x)))
        f(sink, x)
    end
    return nothing
end

@inline function _with_size(f, io::IOBuffer, sink, x, V)
    if io.seekable
        MAX_LENGTH_VARINT_BYTES = 5  # max size of a UInt32 as vbyte
        initpos = position(io)
        truncate(io, initpos + MAX_LENGTH_VARINT_BYTES) # 1.
        seek(io, initpos + MAX_LENGTH_VARINT_BYTES)
        f(sink, x, V) # e.g. _encode(io, x, Val{:zigzag}) # 2.
        endpos = position(io)
        data_len = endpos - initpos - MAX_LENGTH_VARINT_BYTES
        seek(io, initpos)                  # 3.
        vbyte_encode(io, UInt32(data_len)) # --||--
        lenght_len = position(io) - initpos
        unsafe_copyto!(io.data, initpos + lenght_len + 1, io.data, initpos + MAX_LENGTH_VARINT_BYTES + 1, data_len) # 4.
        seek(io, initpos + lenght_len + data_len)
        truncate(io, initpos + lenght_len + data_len)
    else
        vbyte_encode(io, UInt32(_encoded_size(x, V)))
        f(sink, x, V)
    end
    return nothing
end

@inline function _with_size(f, io::IO, sink, x)
    vbyte_encode(io, UInt32(_encoded_size(x)))
    f(sink, x)
    return nothing
end

@inline function _with_size(f, io::IO, sink, x, V)
    vbyte_encode(io, UInt32(_encoded_size(x, V)))
    f(sink, x, V)
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{UInt32,UInt64}}
    vbyte_encode(io, x)
    return nothing
end

function _encode(io::IO, x::Int64)
    vbyte_encode(io, reinterpret(UInt64, x))
    return nothing
end

function _encode(io::IO, x::Int32)
    x < 0 ? vbyte_encode(io, reinterpret(UInt64, Int64(x))) : vbyte_encode(io, reinterpret(UInt32, x))
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{Enum{Int32},Enum{UInt32}}}
    vbyte_encode(io, reinterpret(UInt32, x))
    return nothing
end

function _encode(io::IO, x::Vector{T}, ::Type{Val{:fixed}}) where {T<:Union{Int32,Int64,UInt32,UInt64}}
    write(io, x)
    return nothing
end

function _encode(io::IO, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,Int64,UInt32,UInt64}}
    _unsafe_write(io, Ref(x), Core.sizeof(x))
    return nothing
end

function _encode(io::IO, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    vbyte_encode(io, reinterpret(unsigned(T), zigzag_encode(x)))
    return nothing
end

function _encode(io::IO, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    maybe_ensure_room(io, length(x))
    for el in x
        _encode(io, el, Val{:zigzag})
    end
    return nothing
end

function _encode(io::IO, x::String)
    write(io, x)
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{Bool,Float32,Float64}}
    _unsafe_write(io, Ref(x), Core.sizeof(x))
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

function _encode(io::IO, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int32,Int64,Enum{Int32},Enum{UInt32}}}
    maybe_ensure_room(io, length(x))
    for el in x
        _encode(io, el)
    end
    return nothing
end

function _encode(_e::ProtoEncoder, x::Dict{K,V}) where {K,V}
    maybe_ensure_room(_e.io, 2*(length(x)+1))
    for (k, v) in x
        # encode header for key-value pair message
        encode_tag(_e, 1, LENGTH_DELIMITED)
        vbyte_encode(_e.io, UInt32(_encoded_size(k, 1) + _encoded_size(v, 2)))
        encode(_e, 1, k)
        encode(_e, 2, v)
    end
    nothing
end

for T in (:(:fixed), :(:zigzag))
    @eval function _encode(_e::ProtoEncoder, x::Dict{K,V}, ::Type{Val{Tuple{$(T),Nothing}}}) where {K,V}
        maybe_ensure_room(_e.io, 2*(length(x)+1))
        for (k, v) in x
            encode_tag(_e, 1, LENGTH_DELIMITED)
            vbyte_encode(_e.io, UInt32(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2)))
            encode(_e, 1, k, Val{$(T)})
            encode(_e, 2, v)
        end
        nothing
    end
    @eval function _encode(_e::ProtoEncoder, x::Dict{K,V}, ::Type{Val{Tuple{Nothing,$(T)}}}) where {K,V}
        maybe_ensure_room(_e.io, 2*(length(x)+1))
        for (k, v) in x
            encode_tag(_e, 1, LENGTH_DELIMITED)
            vbyte_encode(_e.io, UInt32(_encoded_size(k, 1) + _encoded_size(v, 2, Val{$(T)})))
            encode(_e, 1, k)
            encode(_e, 2, v, Val{$(T)})
        end
        nothing
    end
end

for T in (:(:fixed), :(:zigzag)), S in (:(:fixed), :(:zigzag))
    @eval function _encode(_e::AbstractProtoEncoder, x::Dict{K,V}, ::Type{Val{Tuple{$(T),$(S)}}}) where {K,V}
        maybe_ensure_room(_e.io, 2*(length(x)+1))
        for (k, v) in x
            encode_tag(_e, 1, LENGTH_DELIMITED)
            vbyte_encode(_e.io, UInt32(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2, Val{$(S)})))
            encode(_e, 1, k, Val{$(T)})
            encode(_e, 2, v, Val{$(S)})
        end
        nothing
    end
end


function encode(e::AbstractProtoEncoder, i::Int, x::T) where {T<:Union{Bool,Int32,Int64,UInt32,UInt64,Enum{Int32},Enum{UInt32}}}
    encode_tag(e, i, VARINT)
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(e, i, VARINT)
    _encode(e.io, x, Val{:zigzag})
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,UInt32}}
    encode_tag(e, i, FIXED32)
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Float32)
    encode_tag(e, i, FIXED32)
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T, ::Type{Val{:fixed}}) where {T<:Union{Int64,UInt64}}
    encode_tag(e, i, FIXED64)
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Float64)
    encode_tag(e, i, FIXED64)
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}) where {T<:Union{Bool,UInt8,Float32,Float64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Base.CodeUnits{UInt8, String})
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{String})
    maybe_ensure_room(e.io, length(x) * (sizeof(first(x)) + 1))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{Vector{UInt8}})
    maybe_ensure_room(e.io, length(x) * (sizeof(first(x)) + 1))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::String)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:fixed}}) where {T<:Union{UInt32,UInt64,Int32,Int64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt32(sizeof(x)))
    _encode(e.io, x, Val{:fixed})
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}) where {T<:Union{UInt32,UInt64,Int32,Int64,Enum{Int32},Enum{UInt32}}}
    encode_tag(e, i, LENGTH_DELIMITED)
    _with_size(_encode, e.io, e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Dict{K,V}) where {K,V}
    encode_tag(e, i, LENGTH_DELIMITED)
    _with_size(_encode, e.io, e, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Dict{K,V}, ::Type{W}) where {K,V,W}
    encode_tag(e, i, LENGTH_DELIMITED)
    _with_size(_encode, e.io, e, x, W)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    _with_size(_encode, e.io, e.io, x, Val{:zigzag})
    return nothing
end

# T is a struct/message type
function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}) where {T}
    @assert !isempty(x)
    maybe_ensure_room(e.io, length(x) * (1 + sizeof(typeof(first(x)))))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        _with_size(encode, e.io, e, el)
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T) where {T}
    encode_tag(e, i, LENGTH_DELIMITED)
    _with_size(encode, e.io, e, x)
    return nothing
end

# Groups
function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:group}}) where {T}
    @assert !isempty(x)
    maybe_ensure_room(e.io, length(x) * (2 + sizeof(typeof(first(x)))))
    for el in x
        encode_tag(e, i, START_GROUP)
        encode(e, el) # This method has to be generated by protojl
        vbyte_encode(e.io, UInt32(END_GROUP))
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T, ::Type{Val{:group}}) where {T}
    maybe_ensure_room(e.io, 2 + sizeof(T))
    encode_tag(e, i, START_GROUP)
    encode(e, x) # This method has to be generated by protojl
    vbyte_encode(e.io, UInt32(END_GROUP))
    return nothing
end

# Resolving a method ambiguity
function encode(::AbstractProtoEncoder, ::Int, ::Dict{K, V}, ::Type{Val{:group}}) where {K, V}
    throw(MethodError(encode, (AbstractProtoEncoder, Int, Dict{K, V}, Val{:group})))
end
