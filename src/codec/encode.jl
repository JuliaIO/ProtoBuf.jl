function encode_tag(io::IO, field_number, wire_type::WireType)
    vbyte_encode(io, (UInt64(field_number) << 3) | UInt64(wire_type))
    return nothing
end
encode_tag(e::ProtoEncoder, field_number, wire_type::WireType) = encode_tag(e.io, field_number, wire_type)
# TODO: audit usage and composability of maybe_ensure_room
maybe_ensure_room(io::IOBuffer, n) = Base.ensureroom(io, min(io.maxsize, n))

maybe_ensure_room(::IO, n) = nothing

@noinline _incomplete_encode_error(io::IOBuffer, nb, target) = throw(ArgumentError("Failed to write to IOBuffer, only written $nb bytes out of $target (maxsize: $(io.maxsize), positiom : $(position(io))"))
@noinline _incomplete_encode_error(::IO, nb, target) = throw(ArgumentError("Failed to write to IO, only written $nb bytes out of $target"))

@inline function _with_size(f, io::IOBuffer, sink, x, V...)
    if io.seekable
        initpos = position(io)
        # We need to encode the encoded size of x before we know it. We first preallocate 1
        # byte as that is the mininum size of the encoded size.
        # If our guess is right, it will save us a copy, but we never want to preallocate too much
        # space for the size, because then we risk outgrowing the buffer that was allocated with exact size
        # needed to contain the message.
        # TODO: make the guess better (e.g. by incorporating maxsize)
        encoded_size_len_guess = 1
        truncate(io, initpos + encoded_size_len_guess)
        seek(io, initpos + encoded_size_len_guess)
        # Now we can encode the object itself
        f(sink, x, V...) # e.g. _encode(io, x) or _encode(io, x, Val{:zigzag})
        endpos = position(io)
        encoded_size = endpos - initpos - encoded_size_len_guess
        encoded_size_len = _encoded_size(UInt64(encoded_size))
        @assert (initpos + encoded_size_len + encoded_size) <= io.maxsize
        # If our initial guess on encoded size of the size was wrong, then we need to move the encoded data
        if encoded_size_len_guess < encoded_size_len
            truncate(io, initpos + encoded_size_len + encoded_size)
            # Move the data right after the correct size
            unsafe_copyto!(
                io.data,
                initpos + encoded_size_len + 1,
                io.data,
                initpos + encoded_size_len_guess + 1,
                encoded_size
            )
        end
        # Now we can encode the size
        seek(io, initpos)
        vbyte_encode(io, UInt64(encoded_size))
        seek(io, initpos + encoded_size_len + encoded_size)
    else
        # TODO: avoid quadratic behavior when estimating encoded size by providing a scratch buffer
        vbyte_encode(io, UInt64(_encoded_size(x, V...)))
        f(sink, x, V...)
    end
    return nothing
end

@inline function _with_size(f, io::IO, sink, x, V...)
    # TODO: avoid quadratic behavior when estimating encoded size by providing a scratch buffer
    vbyte_encode(io, UInt64(_encoded_size(x, V...)))
    f(sink, x, V...)
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
    nb = write(io, x)
    nb == sizeof(x) || _incomplete_encode_error(io, nb, sizeof(x))
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
    nb = write(io, x)
    nb == sizeof(x) || _incomplete_encode_error(io, nb, sizeof(x))
    return nothing
end

function _encode(io::IO, x::T) where {T<:Union{Bool,Float32,Float64}}
    _unsafe_write(io, Ref(x), Core.sizeof(x))
    return nothing
end

function _encode(io::IO, x::Vector{T}) where {T<:Union{Bool,UInt8,Float32,Float64}}
    nb = write(io, x)
    nb == sizeof(x) || _incomplete_encode_error(io, nb, sizeof(x))
    return nothing
end

function _encode(io::IO, x::Base.CodeUnits{UInt8, String})
    nb = write(io, x)
    nb == sizeof(x) || _incomplete_encode_error(io, nb, sizeof(x))
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
        vbyte_encode(e.io, UInt64(_encoded_size(k, 1) + _encoded_size(v, 2)))
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
            vbyte_encode(e.io, UInt64(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2)))
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
            vbyte_encode(e.io, UInt64(_encoded_size(k, 1) + _encoded_size(v, 2, Val{$(T)})))
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
            vbyte_encode(e.io, UInt64(_encoded_size(k, 1, Val{$(T)}) + _encoded_size(v, 2, Val{$(S)})))
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
    vbyte_encode(e.io, UInt64(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Base.CodeUnits{UInt8, String})
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt64(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{String})
    maybe_ensure_room(e.io, length(x) * (sizeof(first(x)) + 1))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt64(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{Vector{UInt8}})
    maybe_ensure_room(e.io, length(x) * (sizeof(first(x)) + 1))
    for el in x
        encode_tag(e, i, LENGTH_DELIMITED)
        vbyte_encode(e.io, UInt64(sizeof(el)))
        _encode(e.io, el)
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::String)
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt64(sizeof(x)))
    _encode(e.io, x)
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::Vector{T}, ::Type{Val{:fixed}}) where {T<:Union{UInt32,UInt64,Int32,Int64}}
    encode_tag(e, i, LENGTH_DELIMITED)
    vbyte_encode(e.io, UInt64(sizeof(x)))
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
        vbyte_encode(e.io, UInt64(END_GROUP))
    end
    return nothing
end

function encode(e::AbstractProtoEncoder, i::Int, x::T, ::Type{Val{:group}}) where {T}
    maybe_ensure_room(e.io, 2 + sizeof(T))
    encode_tag(e, i, START_GROUP)
    encode(e, x) # This method has to be generated by protojl
    vbyte_encode(e.io, UInt64(END_GROUP))
    return nothing
end

# Resolving a method ambiguity
function encode(::AbstractProtoEncoder, ::Int, ::Dict{K, V}, ::Type{Val{:group}}) where {K, V}
    throw(MethodError(encode, (AbstractProtoEncoder, Int, Dict{K, V}, Val{:group})))
end
