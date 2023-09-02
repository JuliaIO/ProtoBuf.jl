function encode_tag(io::IO, field_number, wire_type::WireType)
    vbyte_encode(io, (UInt32(field_number) << 3) | UInt32(wire_type))
    return nothing
end
encode_tag(e::ProtoEncoder, field_number, wire_type::WireType) = encode_tag(e.io, field_number, wire_type)
# TODO: audit usage and composability of maybe_ensure_room
maybe_ensure_room(io::IOBuffer, n) = Base.ensureroom(io, n)
maybe_ensure_room(::IO, n) = nothing

# When we don't know the length beforehand we
# 1. encode data and learn its length
# 2. make space for the length at the end of the buffer
# 3. shift the data to the right, moving the space for the length to the beginning
# 4. encode the length
@inline function _with_size(f, io::IOBuffer, sink, x)
    if io.seekable
        initpos = position(io)
        f(sink, x) # e.g. _encode(io, x)                # 1.
        endpos = position(io)
        data_len = endpos - initpos
        data_len_len = _encoded_size(UInt32(data_len))
        truncate(io, initpos + data_len_len + data_len) # 2.
        unsafe_copyto!(                                 # 3.
            io.data, initpos + data_len_len + 1,
            io.data, initpos + 1,
            data_len
        )
        seek(io, initpos)
        vbyte_encode(io, UInt32(data_len))              # 4.
        seek(io, initpos + data_len_len + data_len)
    else
        vbyte_encode(io, UInt32(_encoded_size(x)))
        f(sink, x)
    end
    return nothing
end

@inline function _with_size(f, io::IOBuffer, sink, x, V)
    if io.seekable
        initpos = position(io)
        f(sink, x, V) # e.g. _encode(io, x)             # 1.
        endpos = position(io)
        data_len = endpos - initpos
        data_len_len = _encoded_size(UInt32(data_len))
        truncate(io, initpos + data_len_len + data_len) # 2.
        unsafe_copyto!(                                 # 3.
            io.data, initpos + data_len_len + 1,
            io.data, initpos + 1,
            data_len
        )
        seek(io, initpos)
        vbyte_encode(io, UInt32(data_len))              # 4.
        seek(io, initpos + data_len_len + data_len)
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

function encode(e::ProtoEncoder, i::Int, x::Dict{K,V}) where {K,V}
    maybe_ensure_room(e.io, 2*(length(x)+1))
    for (k, v) in x
        # encode header for key-value pair message
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt32(_encoded_size(k, 1) + _encoded_size(v, 2)))
        encode(e, 1, k)
        encode(e, 2, v)
    end
    nothing
end

for T in (:(:fixed), :(:zigzag))
    @eval function encode(e::ProtoEncoder, i::Int, x::Dict{K,V}, ::Type{Val{Tuple{$(T),Nothing}}}) where {K,V}
        maybe_ensure_room(e.io, 2*(length(x)+1))
        for (k, v) in x
            # encode header for key-value pair message
            encode_tag(e, i, LENGTH_DELIMITED)
            vbyte_encode(e.io, UInt32(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2)))
            encode(e, 1, k, Val{$(T)})
            encode(e, 2, v)
        end
        nothing
    end
    @eval function encode(e::ProtoEncoder, i::Int, x::Dict{K,V}, ::Type{Val{Tuple{Nothing,$(T)}}}) where {K,V}
        maybe_ensure_room(e.io, 2*(length(x)+1))
        for (k, v) in x
            # encode header for key-value pair message
            encode_tag(e, i, LENGTH_DELIMITED)
            vbyte_encode(e.io, UInt32(_encoded_size(k, 1) + _encoded_size(v, 2, Val{$(T)})))
            encode(e, 1, k)
            encode(e, 2, v, Val{$(T)})
        end
        nothing
    end
end

for T in (:(:fixed), :(:zigzag)), S in (:(:fixed), :(:zigzag))
    @eval function encode(e::AbstractProtoEncoder, i::Int, x::Dict{K,V}, ::Type{Val{Tuple{$(T),$(S)}}}) where {K,V}
        maybe_ensure_room(e.io, 2*(length(x)+1))
        for (k, v) in x
            # encode header for key-value pair message
            encode_tag(e, i, LENGTH_DELIMITED)
            vbyte_encode(e.io, UInt32(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2, Val{$(S)})))
            encode(e, 1, k, Val{$(T)})
            encode(e, 2, v, Val{$(S)})
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
