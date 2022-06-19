# Any of the following decode statements can appear in a translated
# decode method.
decode(d::ProtoDecoder, ::Type{T}) where {T} = decode(d.io, T)
decode(d::ProtoDecoder, ::Type{T}, ::Type{V}) where {T,V} = decode(d.io, T, V)
decode!(d::ProtoDecoder, buffer::Base.RefValue) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, wire_type::WireType, buffer::BufferedVector) = decode!(d.io, wire_type, buffer)
decode!(d::ProtoDecoder, wire_type::WireType, buffer::BufferedVector, ::Type{V}) where {V} = decode!(d.io, wire_type, buffer, V)
decode!(d::ProtoDecoder, buffer::BufferedVector) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, buffer::Dict) = decode!(d.io, buffer)
decode!(d::ProtoDecoder, buffer::Dict, ::Type{V}) where {V} = decode!(d.io, buffer, V)

function decode_tag(d::ProtoDecoder)
    b = vbyte_decode(d.io, UInt32)
    field_number = b >> 3
    wire_type = WireType(b & 0x07)
    return field_number, wire_type
end

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
    bytelen = vbyte_decode(io, UInt32) + position(io)
    while position(io) < bytelen
        key = decode(io, K)
        val = decode(io, V)
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Nothing,W}}}) where {K,V,W}
    bytelen = vbyte_decode(io, UInt32) + position(io)
    while position(io) < bytelen
        key = decode(io, K)
        val = decode(io, V, Var{W})
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Q,Nothing}}}) where {K,V,Q}
    bytelen = vbyte_decode(io, UInt32) + position(io)
    while position(io) < bytelen
        key = decode(io, K, Var{Q})
        val = decode(io, V)
        buffer[key] = val
    end
    nothing
end

function decode!(io::IO, buffer::Dict{K,V}, ::Type{Val{Tuple{Q,W}}}) where {K,V,Q,W}
    bytelen = vbyte_decode(io, UInt32) + position(io)
    while position(io) < bytelen
        key = decode(io, K, Var{Q})
        val = decode(io, V, Var{W})
        buffer[key] = val
    end
    nothing
end

function decode(io::IO, ::Type{String})
    bytelen = vbyte_decode(io, UInt32)
    bytes = Base.StringVector(bytelen)
    read!(io, bytes)
    return String(bytes)
end
function decode!(io::IO, buffer::BufferedVector{String})
    buffer[] = decode(io, String)
    return nothing
end

function decode(io::IO, ::Type{Vector{UInt8}})
    bytelen = vbyte_decode(io, UInt32)
    return read(io, bytelen)
end
function decode!(io::IO, buffer::BufferedVector{Vector{UInt8}})
    buffer[] = decode(io, Vector{UInt8})
    return nothing
end

function decode!(io::IO, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Int32,Int64,UInt32,UInt32,Base.Enum}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(io, UInt32)
        endpos = bytelen + position(io)
        while position(io) < endpos
            buffer[] = decode(io, T)
        end
        @assert position(io) == endpos
    else
        buffer[] = decode(io, T)
    end
    return nothing
end

function decode!(io::IO, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:zigzag}}) where {T <: Union{Int32,Int64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(io, UInt32)
        endpos = bytelen + position(io)
        while position(io) < endpos
            buffer[] = decode(io, T, Val{:zigzag})
        end
        @assert position(io) == endpos
    else
        buffer[] = decode(io, T, Val{:zigzag})
    end
    return nothing
end

function decode!(io::IO, w::WireType, buffer::BufferedVector{T}, ::Type{Val{:fixed}}) where {T <: Union{Int32,Int64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(io, UInt32)
        n_incoming = div(bytelen, sizeof(T))
        n_current = length(buffer.elements)
        resize!(buffer.elements, n_current + n_incoming)
        endpos = bytelen + position(io)
        for i in (n_current+1):n_incoming
            buffer.occupied += 1
            @inbounds buffer.elements[i] = decode(io, T, Val{:fixed})
        end
        @assert position(io) == endpos
    else
        buffer[] = decode(io, T, Val{:fixed})
    end
    return nothing
end

function decode!(io::IO, w::WireType, buffer::BufferedVector{T}) where {T <: Union{Bool,Float32,Float64}}
    if w == LENGTH_DELIMITED
        bytelen = vbyte_decode(io, UInt32)
        n_incoming = div(bytelen, sizeof(T))
        n_current = length(buffer.elements)
        resize!(buffer.elements, n_current + n_incoming)
        endpos = bytelen + position(io)
        for i in (n_current+1):n_incoming
            buffer.occupied += 1
            @inbounds buffer.elements[i] = decode(io, T)
        end
        @assert position(io) == endpos
    else
        buffer[] = decode(io, T)
    end
    return nothing
end

function decode!(io::IO, buffer::Base.RefValue{T}) where {T}
    bytelen = vbyte_decode(io, UInt32)
    endpos = bytelen + position(io)
    if isassigned(buffer)
        buffer[] =_merge_structs(buffer[], decode(d, T))
    else
        buffer[] = decode(d, T)
    end
    @assert position(io) == endpos
    return nothing
end

function decode!(io::IO, buffer::Vector{T}) where {T}
    bytelen = vbyte_decode(io, UInt32)
    endpos = bytelen + position(io)
    if isbitstype(T)
        # sizeof isbitstypes is the upper bound, it includes padding
        sizehint!(buffer, length(buffer) + div(bytelen, sizeof(T)))
    end
    while position(io) < endpos
        push!(buffer, decode(io, T))
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
