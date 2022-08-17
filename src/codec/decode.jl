function decode_tag(d::AbstractProtoDecoder)
    b = vbyte_decode(d.io, UInt32)
    field_number = b >> 3
    wire_type = WireType(b & 0x07)
    return field_number, wire_type
end

const _ScalarTypes = Union{Float64,Float32,Int32,Int64,UInt64,UInt32,Bool,String,Vector{UInt8}}
const _ScalarTypesEnum = Union{_ScalarTypes,Enum}

# uint32, uint64
decode(d::AbstractProtoDecoder, ::Type{T}) where {T <: Union{UInt32,UInt64}} = vbyte_decode(d.io, T)
# int32: Negative int32 are encoded in 10 bytes...
# TODO: add check the int is negative if larger than typemax UInt32
decode(d::AbstractProtoDecoder, ::Type{Int32}) = reinterpret(Int32, UInt32(vbyte_decode(d.io, UInt64) % UInt32))
# int64
decode(d::AbstractProtoDecoder, ::Type{Int64}) = reinterpret(Int64, vbyte_decode(d.io, UInt64))
# sfixed32, sfixed64, # fixed32, fixed64
decode(d::AbstractProtoDecoder, ::Type{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64,UInt32,UInt64}} = read(d.io, T)
# sint32, sint64
function decode(d::AbstractProtoDecoder, ::Type{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
    v = vbyte_decode(d.io, unsigned(T))
    z = zigzag_decode(v)
    return reinterpret(T, z)
end
decode(d::AbstractProtoDecoder, ::Type{Bool}) = Bool(read(d.io, UInt8))
function decode(d::AbstractProtoDecoder, ::Type{T}) where {T <: Union{Enum{Int32},Enum{UInt32}}}
    val = vbyte_decode(d.io, UInt32)
    return val in keys(Base.Enums.namemap(T)) ? T(val) : T(0)
end
decode(d::AbstractProtoDecoder, ::Type{T}) where {T <: Union{Float64,Float32}} = read(d.io, T)
function decode!(d::AbstractProtoDecoder, buffer::Dict{K,V}) where {K,V<:_ScalarTypesEnum}
    len = vbyte_decode(d.io, UInt32)
    endpos = position(d.io) + len
    while position(d.io) < endpos
        field_number, wire_type = decode_tag(d)
        key = decode(d, K)
        field_number, wire_type = decode_tag(d)
        val = decode(d, V)
        buffer[key] = val
    end
    @assert position(d.io) == endpos
    nothing
end

function decode!(d::AbstractProtoDecoder, buffer::Dict{K,V}) where {K,V}
    len = vbyte_decode(d.io, UInt32)
    endpos = position(d.io) + len
    while position(d.io) < endpos
        field_number, wire_type = decode_tag(d)
        key = decode(d, K)
        field_number, wire_type = decode_tag(d)
        val = decode(d, Ref{V})
        buffer[key] = val
    end
    @assert position(d.io) == endpos
    nothing
end

for T in (:(:fixed), :(:zigzag))
    @eval function decode!(d::AbstractProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{Nothing,$(T)}}}) where {K,V}
        len = vbyte_decode(d.io, UInt32)
        endpos = position(d.io) + len
        while position(d.io) < endpos
            field_number, wire_type = decode_tag(d)
            key = decode(d, K)
            field_number, wire_type = decode_tag(d)
            val = decode(d, V, Val{$(T)})
            buffer[key] = val
        end
        @assert position(d.io) == endpos
        nothing
    end

    @eval function decode!(d::AbstractProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{$(T),Nothing}}}) where {K,V}
        len = vbyte_decode(d.io, UInt32)
        endpos = position(d.io) + len
        while position(d.io) < endpos
            field_number, wire_type = decode_tag(d)
            key = decode(d, K, Val{$(T)})
            field_number, wire_type = decode_tag(d)
            val = decode(d, V)
            buffer[key] = val
        end
        @assert position(d.io) == endpos
        nothing
    end
end

for T in (:(:fixed), :(:zigzag)), S in (:(:fixed), :(:zigzag))
    @eval function decode!(d::AbstractProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{$(T),$(S)}}}) where {K,V}
        len = vbyte_decode(d.io, UInt32)
        endpos = position(d.io) + len
        while position(d.io) < endpos
            field_number, wire_type = decode_tag(d)
            key = decode(d, K, Val{$(T)})
            field_number, wire_type = decode_tag(d)
            val = decode(d, V, Val{$(S)})
            buffer[key] = val
        end
        @assert position(d.io) == endpos
        nothing
    end
end

function decode(d::AbstractProtoDecoder, ::Type{String})
    bytelen = vbyte_decode(d.io, UInt32)
    str = Base._string_n(bytelen)
    Base.unsafe_read(d.io, pointer(str), bytelen)
    return str
end
function decode!(d::AbstractProtoDecoder, buffer::BufferedVector{String})
    buffer[] = decode(d, String)
    return nothing
end

function decode(d::AbstractProtoDecoder, ::Type{Vector{UInt8}})
    bytelen = vbyte_decode(d.io, UInt32)
    return read(d.io, bytelen)
end
function decode(d::AbstractProtoDecoder, ::Type{Base.CodeUnits{UInt8, String}})
    bytelen = vbyte_decode(d.io, UInt32)
    return read(d.io, bytelen)
end
function decode!(d::AbstractProtoDecoder, buffer::BufferedVector{Vector{UInt8}})
    buffer[] = decode(d, Vector{UInt8})
    return nothing
end

function decode!(d::AbstractProtoDecoder, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Int32,Int64,UInt32,UInt64,Enum{Int32},Enum{UInt32}}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(d.io, UInt32)
        endpos = bytelen + position(d.io)
        while position(d.io) < endpos
            buffer[] = decode(d, T)
        end
        @assert position(d.io) == endpos
    else
        buffer[] = decode(d, T)
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(d.io, UInt32)
        endpos = bytelen + position(d.io)
        while position(d.io) < endpos
            buffer[] = decode(d, T, Val{:zigzag})
        end
        @assert position(d.io) == endpos
    else
        buffer[] = decode(d, T, Val{:zigzag})
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64,UInt32,UInt64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(d.io, UInt32)
        n_incoming = div(bytelen, sizeof(T))
        n_current = length(buffer.elements)
        resize!(buffer.elements, n_current + n_incoming)
        endpos = bytelen + position(d.io)
        for i in (n_current+1):(n_current + n_incoming)
            buffer.occupied += 1
            @inbounds buffer.elements[i] = decode(d, T, Val{:fixed})
        end
        @assert position(d.io) == endpos
    else
        buffer[] = decode(d, T, Val{:fixed})
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Bool,Float32,Float64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(d.io, UInt32)
        n_incoming = div(bytelen, sizeof(T))
        n_current = length(buffer.elements)
        resize!(buffer.elements, n_current + n_incoming)
        endpos = bytelen + position(d.io)
        for i in (n_current+1):(n_current + n_incoming)
            buffer.occupied += 1
            @inbounds buffer.elements[i] = decode(d, T)
        end
        @assert position(d.io) == endpos
    else
        buffer[] = decode(d, T)
    end
    return nothing
end

# This method handles messages decoded as OneOf / repeated. We expect `decode(d, T)`
# to be generated / provided by the user. We do this so that we can conditionally
# eat the length varint (which is not present when decoding a toplevel message).
# We don't reuse the decode!(d::AbstractProtoDecoder, buffer::Base.RefValue{T}) method above
# as with OneOf fields, we can't be sure that the previous OneOf value was also T.
function decode(d::AbstractProtoDecoder, ::Type{Ref{T}}) where {T}
    bytelen = vbyte_decode(d.io, UInt32)
    endpos = bytelen + position(d.io)
    out = decode(LengthDelimitedProtoDecoder(d.io, endpos), T)
    @assert position(d.io) == endpos
    return out
end

function decode!(d::AbstractProtoDecoder, buffer::BufferedVector{T}) where {T}
    buffer[] = decode(d, Ref{T})
    return nothing
end

function decode(d::AbstractProtoDecoder, ::Type{Ref{T}}, ::Type{Val{:group}}) where {T}
    out = decode(GroupProtoDecoder(d.io), T)
    return out
end

function decode!(d::AbstractProtoDecoder, buffer::BufferedVector{T}, ::Type{Val{:group}}) where {T}
    buffer[] = decode(d, Ref{T}, Val{:group})
    return nothing
end

# When the type signature on buffer was Base.RefValue{Union{T,Nothing}} where T,
# Aqua was complaining about an unbound type parameter.
function decode!(d::AbstractProtoDecoder, buffer::Base.RefValue{S}) where {S>:Nothing}
    T = Core.Compiler.typesubtract(S, Nothing, 2)
    if !isnothing(buffer[])
        buffer[] = _merge_structs(getindex(buffer)::T, decode(d, Ref{T}))
    else
        buffer[] = decode(d, Ref{T})
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, buffer::Base.RefValue{T}) where {T}
    if isassigned(buffer)
        buffer[] = _merge_structs(buffer[], decode(d, Ref{T}))
    else
        buffer[] = decode(d, Ref{T})
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, buffer::Base.RefValue{S}, ::Type{Val{:group}}) where {S>:Nothing}
    T = Core.Compiler.typesubtract(S, Nothing, 2)
    if !isnothing(buffer[])
        buffer[] = _merge_structs(getindex(buffer)::T, decode(d, Ref{T}, Val{:group}))
    else
        buffer[] = decode(d, Ref{T}, Val{:group})
    end
    return nothing
end

function decode!(d::AbstractProtoDecoder, buffer::Base.RefValue{T}, ::Type{Val{:group}}) where {T}
    if isassigned(buffer)
        buffer[] = _merge_structs(buffer[], decode(d, Ref{T}, Val{:group}))
    else
        buffer[] = decode(d, Ref{T}, Val{:group})
    end
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
    isbitstype(s1) && return :(return s2)
    # TODO: Error gracefully on unsuported types like Missing, Matrices...
    #       Would be easier if we have a HolyTrait for user defined structs
    merged_values = Tuple(
        (
            type <: _ScalarTypesEnum ? :(s2.$(name)) :
            type <: AbstractVector ? :(vcat(s1.$(name), s2.$(name))) :
            :(_merge_structs(s1.$(name), s2.$(name)))
        )
        for (name, type)
        in zip(fieldnames(T), fieldtypes(T))
    )
    return quote T($(merged_values...)) end
end

@generated function _merge_structs!(s1::Union{Nothing,T}, s2::T) where {T}
    isbitstype(s1) && :(return nothing)
    exprs = Expr[]
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        (type <: _ScalarTypesEnum) && continue
        if (type <: AbstractVector)
            push!(exprs, :(prepend!(s2.$(name), s1.$(name));))
        else
            push!(exprs, :(_merge_structs!(s1.$(name), s2.$(name));))
        end
    end
    return quote
        $(exprs...)
        return nothing
    end
end

@inline function Base.skip(d::AbstractProtoDecoder, wire_type::WireType)
    if wire_type == VARINT
        while read(d.io, UInt8) >= 0x80 end
    elseif wire_type == FIXED64
        skip(d.io, 8)
    elseif wire_type == LENGTH_DELIMITED
        bytelen = vbyte_decode(d.io, UInt32)
        skip(d.io, bytelen)
    elseif wire_type == START_GROUP
        while peek(d.io) != UInt8(END_GROUP)
            skip(d, decode_tag(d)[2])
        end
        skip(d.io, 1)
    elseif wire_type == FIXED32
        skip(d.io, 4)
    else wire_type == END_GROUP
        error("Encountered END_GROUP wiretype while skipping")
    end
    return nothing
end
