_max_varint_size(::Type{T}) where {T} = (sizeof(T) + (sizeof(T) >> 2))

_varint_size(x) = cld((8sizeof(x) - leading_zeros(x)), 7)
_varint_size(x::Enum) = _varint_size(reinterpret(UInt32, x))
_varint_size(x::Int32) = x < 0 ? _varint_size(Int64(x)) : _varint_size(reinterpret(UInt32, x))
_varint_size1(x) = max(1, _varint_size(x))

# We don't include the field number and tag into the size, it is the responsibility of the
# per-struct generated methods to account for them.

# For scalars, we can't be sure about their size as they could be omitted completely
# (we're not sending default values over the wire)
_encoded_size(x::Nothing) = 0 # this shouldn't really happen
_encoded_size(x::T) where {T<:Union{Int32,UInt32,Int64,UInt64,Enum}} = _varint_size1(x)
_encoded_size(x::T, ::Type{Val{:zigzag}}) where {T<:Union{UInt32,UInt64}} = _varint_size1(zigzag_encode(x))
_encoded_size(x::T, ::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}} = _varint_size1(reinterpret(unsigned(T), zigzag_encode(x)))
_encoded_size(x::T) where {T<:Union{Bool,Float64,Float32}} = sizeof(x)
_encoded_size(x::T, ::Type{Val{:fixed}}) where {T<:Union{Int32,UInt32,Int64,UInt64}} = sizeof(x)

# For Length-Delimited fields we don't include the encoded number of bytes
# unless we also provide the field number in which case we encode both the
# tag and length
_with_size(n::Int) = (n + _encoded_size(n))
_encoded_size(x::String) = sizeof(x)

_encoded_size(xs::AbstractVector{T}) where {T<:Union{Int32,UInt32,Int64,UInt64,Enum}} = sum(_varint_size1, xs, init=0)
_encoded_size(xs::AbstractVector{T}, ::Type{Val{:zigzag}}) where {T<:Union{Int32,UInt32,Int64,UInt64}} = sum(x->_encoded_size(x, Val{:zigzag}), xs, init=0)
_encoded_size(xs::AbstractVector{T}) where {T<:Union{UInt8,Bool,Float64,Float32}} = sizeof(xs)
_encoded_size(xs::AbstractVector{T}) where {T<:Union{String,AbstractVector{UInt8}}} = sum(x->_with_size(_encoded_size(x)), xs, init=0)
_encoded_size(xs::AbstractVector{T}, ::Type{Val{:fixed}}) where {T<:Union{Int32,UInt32,Int64,UInt64}} = sizeof(xs)

# Dicts add dummy tags to both keys and values and to each pair
# _encoded_size(::AbstractDict) does not include the "pair" tag and field number
# those are added in the _encoded_size(::AbstractDict, ::Int) methods below because the field number
# is not known at this point
function _encoded_size(d::AbstractDict)
    mapreduce(x->begin
        total_size = _encoded_size(x.first, 1) + _encoded_size(x.second, 2)
        return _varint_size(total_size) + total_size
    end, +, d, init=0)
end
_encoded_size(xs::AbstractDict, i::Int)  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs)

for T in (:(:fixed), :(:zigzag))
    @eval _encoded_size(d::AbstractDict, ::Type{Val{Tuple{$(T),Nothing}}}) = mapreduce(x->begin
        total_size = _encoded_size(x.first, 1, Val{$(T)}) + _encoded_size(x.second, 2)
        return _varint_size(total_size) + total_size
    end, +, d, init=0)
    @eval _encoded_size(xs::AbstractDict, i::Int, ::Type{Val{Tuple{$(T),Nothing}}})  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs, Val{Tuple{$(T),Nothing}})

    @eval _encoded_size(d::AbstractDict, ::Type{Val{Tuple{Nothing,$(T)}}}) = mapreduce(x->begin
        total_size = _encoded_size(x.first, 1) + _encoded_size(x.second, 2, Val{$(T)})
        return _varint_size(total_size) + total_size
    end, +, d, init=0)
    @eval _encoded_size(xs::AbstractDict, i::Int, ::Type{Val{Tuple{Nothing,$(T)}}})  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs, Val{Tuple{Nothing,$(T)}})

    @eval _encoded_size(xs::AbstractVector, i::Int, ::Type{Val{$(T)}}) = _encoded_size(i << 3) + _with_size(_encoded_size(xs, Val{$(T)}))
    @eval _encoded_size(xs::Union{Int32,Int64,UInt64,UInt32}, i::Int, ::Type{Val{$(T)}}) = _encoded_size(i << 3) + _encoded_size(xs, Val{$(T)})
end

for T in (:(:fixed), :(:zigzag)), S in (:(:fixed), :(:zigzag))
    @eval _encoded_size(d::AbstractDict, ::Type{Val{Tuple{$(T),$(S)}}}) = mapreduce(x->begin
        total_size = _encoded_size(x.first, 1, Val{$(T)}) + _encoded_size(x.second, 2, Val{$(S)})
        return _varint_size(total_size) + total_size
    end, +, d, init=0)
    @eval _encoded_size(xs::AbstractDict, i::Int, ::Type{Val{Tuple{$(T),$(S)}}})  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs, Val{Tuple{$(T),$(S)}})
end

# These methods handle fields that refer to messages/groups
_encoded_size(xs, i::Int)                      = _encoded_size(i << 3) + _with_size(_encoded_size(xs))
_encoded_size(xs, i::Int, ::Type{Val{:group}}) = _encoded_size(i << 3) + _encoded_size(xs) + 2

# These methods handle vectors of messages, these (like strings and bytes) are not "packed"
_encoded_size(xs::AbstractArray)          = sum(x->_with_size(_encoded_size(x)), xs, init=0)
_encoded_size(xs::AbstractArray, i::Int)  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs)

_encoded_size(xs::AbstractArray, ::Type{Val{:group}})          = sum(x->_encoded_size(x) + 2, xs, init=0)
_encoded_size(xs::AbstractArray, i::Int, ::Type{Val{:group}})  = _encoded_size(i << 3) * length(xs) + _encoded_size(xs, Val{:group})

_encoded_size(xs::Union{AbstractString,AbstractVector{UInt8}}, i::Int) = _encoded_size(i << 3) + _with_size(_encoded_size(xs))
function _encoded_size(xs::AbstractVector{T}, i::Int) where {T<:Union{Float64,Float32,Int32,Int64,UInt64,UInt32,Bool,Enum}}
    return _encoded_size(i << 3) + _with_size(_encoded_size(xs))
end
function _encoded_size(xs::Union{Float64,Float32,Int32,Int64,UInt64,UInt32,Bool,Enum}, i::Int)
    return _encoded_size(i << 3) + _encoded_size(xs)
end


