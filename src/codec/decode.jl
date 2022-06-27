function decode_tag(d::ProtoDecoder)
    b = vbyte_decode(d.io, UInt32)
    field_number = b >> 3
    wire_type = WireType(b & 0x07)
    return field_number, wire_type
end

# uint32, uint64
decode(d::ProtoDecoder, ::Type{T}) where {T <: Union{UInt32,UInt64}} = vbyte_decode(d.io, T)
# int32: Negative int32 are encoded in 10 bytes...
# TODO: add check the int is negative if larger thatn typemax UInt32
decode(d::ProtoDecoder, ::Type{Int32}) = reinterpret(Int32, UInt32(vbyte_decode(d.io, UInt64) % UInt32))
# int64
decode(d::ProtoDecoder, ::Type{Int64}) = reinterpret(Int64, vbyte_decode(d.io, UInt64))
# sfixed32, sfixed64, # fixed32, fixed64
decode(d::ProtoDecoder, ::Type{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64,UInt32,UInt64}} = read(d.io, T)
# sint32, sint64
function decode(d::ProtoDecoder, ::Type{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
    v = vbyte_decode(d.io, unsigned(T))
    z = zigzag_decode(v)
    return reinterpret(T, z)
end
decode(d::ProtoDecoder, ::Type{Bool}) = Bool(read(d.io, UInt8))
decode(d::ProtoDecoder, ::Type{T}) where {T <: Union{Enum{Int32},Enum{UInt32}}} = T(vbyte_decode(d.io, UInt32))
decode(d::ProtoDecoder, ::Type{T}) where {T <: Union{Float64,Float32}} = read(d.io, T)
function decode!(d::ProtoDecoder, buffer::Dict{K,V}) where {K,V}
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

function decode!(d::ProtoDecoder, buffer::Dict{K,Vector{V}}) where {K,V}
    len = vbyte_decode(d.io, UInt32)
    endpos = position(d.io) + len
    vals_buffer = BufferedVector{V}()
    while position(d.io) < endpos
        field_number, wire_type = decode_tag(d)
        key = decode(d, K)
        field_number, wire_type = decode_tag(d)
        decode!(d, wire_type, vals_buffer)
        buffer[key] = copy(vals_buffer[])
        empty!(vals_buffer)
    end
    @assert position(d.io) == endpos
    nothing
end

for T in (:(:fixed), :(:zigzag))
    @eval function decode!(d::ProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{Nothing,$(T)}}}) where {K,V}
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

    @eval function decode!(d::ProtoDecoder, buffer::Dict{K,Vector{V}}, ::Type{Val{Tuple{Nothing,$(T)}}}) where {K,V}
        len = vbyte_decode(d.io, UInt32)
        endpos = position(d.io) + len
        vals_buffer = BufferedVector{V}()
        while position(d.io) < endpos
            field_number, wire_type = decode_tag(d)
            key = decode(d, K)
            field_number, wire_type = decode_tag(d)
            decode!(d, wire_type, vals_buffer, Val{$(T)})
            buffer[key] = copy(vals_buffer[])
            empty!(vals_buffer)
        end
        @assert position(d.io) == endpos
        nothing
    end

    @eval function decode!(d::ProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{$(T),Nothing}}}) where {K,V}
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
    @eval function decode!(d::ProtoDecoder, buffer::Dict{K,V}, ::Type{Val{Tuple{$(T),$(S)}}}) where {K,V}
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

function decode(d::ProtoDecoder, ::Type{String})
    bytelen = vbyte_decode(d.io, UInt32)
    bytes = Base.StringVector(bytelen)
    read!(d.io, bytes)
    return String(bytes)
end
function decode!(d::ProtoDecoder, buffer::BufferedVector{String})
    buffer[] = decode(d, String)
    return nothing
end

function decode(d::ProtoDecoder, ::Type{Vector{UInt8}})
    bytelen = vbyte_decode(d.io, UInt32)
    return read(d.io, bytelen)
end
function decode(d::ProtoDecoder, ::Type{Base.CodeUnits{UInt8, String}})
    bytelen = vbyte_decode(d.io, UInt32)
    return read(d.io, bytelen)
end
function decode!(d::ProtoDecoder, buffer::BufferedVector{Vector{UInt8}})
    buffer[] = decode(d, Vector{UInt8})
    return nothing
end

function decode!(d::ProtoDecoder, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Int32,Int64,UInt32,UInt64,Enum{Int32},Enum{UInt32}}}
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

function decode!(d::ProtoDecoder, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
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

function decode!(d::ProtoDecoder, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64,UInt32,UInt64}}
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

function decode!(d::ProtoDecoder, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Bool,Float32,Float64}}
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

function decode!(d::ProtoDecoder, buffer::Base.RefValue{T}) where {T}
    bytelen = vbyte_decode(d.io, UInt32)
    endpos = bytelen + position(d.io)
    if isassigned(buffer)
        buffer[] =_merge_structs(buffer[], decode(d, T))
    else
        buffer[] = decode(d, T)
    end
    @assert position(d.io) == endpos
    return nothing
end

# This method handles messages decoded as OneOf. We expect `decode(d, T)`
# to be generated / provided by the user. We do this so that we can conditionally
# eat the length varint (which is not present when decoding a toplevel message).
# We don't reuse the decode!(d::ProtoDecoder, buffer::Base.RefValue{T}) method above
# as with OneOf fields, we can't be sure that the previous OneOf value was also T.
function decode(d::ProtoDecoder, ::Type{Ref{T}}) where {T}
    bytelen = vbyte_decode(d.io, UInt32)
    endpos = bytelen + position(d.io)
    out = decode(d, T)
    @assert position(d.io) == endpos
    return out
end

function decode!(d::ProtoDecoder, buffer::Vector{T}) where {T}
    bytelen = vbyte_decode(d.io, UInt32)
    endpos = bytelen + position(d.io)
    if isbitstype(T)
        # sizeof isbitstypes is the upper bound, it includes padding
        sizehint!(buffer, length(buffer) + div(bytelen, sizeof(T)))
    end
    while position(d.io) < endpos
        push!(buffer, decode(d, T))
    end
    @assert position(d.io) == endpos
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

# @generated function _merge_structs!(s1::Union{Nothing,T}, s2::T) where {T}
#     isnothing(s1) && return s2
#     isnothing(s2) && return s2
#     # TODO: Error gracefully on unsuported types like Missing, Matrices...
#     #       Would be easier if we have a HolyTrait for user defined structs
#     merged_values = Tuple(
#         (
#             type <: AbstractVector ? :(append!(s2.$name, s1.$name)) :
#             :(_merge_structs!(s1.$name, s2.$name))
#         )
#         for (name, type)
#         in zip(fieldnames(T), fieldtypes(T))
#         if !(type <: Union{Float64,Float32,Int32,Int64,UInt64,UInt32,Bool,String,Vector{UInt8})
#     )
#     return quote
#         T($(merged_values...))
#         return s2
#     end
# end

@inline function Base.skip(d::ProtoDecoder, wire_type::WireType)
    if wire_type == VARINT
        while read(d.io, UInt8) >= 0x80 end
    elseif wire_type == FIXED64
        skip(d.io, 8)
    elseif wire_type == LENGTH_DELIMITED
        bytelen = vbyte_decode(d, UInt32)
        skip(d.io, bytelen)
    elseif wire_type == START_GROUP
        #TODO: this is not verified
        bytelen = vbyte_decode(d, UInt32)
        skip(d.io, bytelen)
    elseif wire_type == FIXED32
        skip(d.io, 4)
    else wire_type == END_GROUP
        error("Encountered END_GROUP wiretype while skipping")
    end
    return nothing
end
