mutable struct ProtoMetaLock
    lck::Union{Nothing,ReentrantLock}
end

function Base.lock(f, l::ProtoMetaLock)
    (l.lck === nothing) && (return f())
    lock(l.lck) do
        f()
    end
end

const MetaLock = ProtoMetaLock(ReentrantLock())

function enable_async_safety(dolock::Bool)
    if dolock
        (MetaLock.lck === nothing) && (MetaLock.lck = ReentrantLock())
    else
        (MetaLock.lck !== nothing) && (MetaLock.lck = nothing)
    end
    MetaLock.lck
end

const MSB = 0x80
const MASK7 = 0x7f
const MASK8 = 0xff
const MASK3 = 0x07

const WIRETYP_VARINT   = 0
const WIRETYP_64BIT    = 1
const WIRETYP_LENDELIM = 2
const WIRETYP_GRPSTART = 3   # deprecated
const WIRETYP_GRPEND   = 4   # deprecated
const WIRETYP_32BIT    = 5

"""
The abstract type from which all generated protobuf structs extend.
"""
abstract type ProtoType end

struct FixedSizeNumber{T<:Union{UInt32,UInt64,Int32,Int64}}
    number::T
end
Base.convert(::Type{FixedSizeNumber{S}}, x::T) where {S<:Integer,T<:Integer} = FixedSizeNumber{S}(x)
Base.convert(::Type{S}, x::FixedSizeNumber{T}) where {S<:Integer,T<:Integer} = S(x.number)

struct SignedNumber{T<:Union{Int32,Int64}}
    number::T
end
Base.convert(::Type{SignedNumber{S}}, x::T) where {S<:Integer,T<:Integer} = SignedNumber{S}(x)
Base.convert(::Type{S}, x::SignedNumber{T}) where {S<:Integer,T<:Integer} = S(x.number)

const _wiretype_dict = Dict{Symbol,Type}(
    :enum => Int32,
    :int32 => Int32,
    :int64 => Int64,
    :uint32 => UInt32,
    :uint64 => UInt64,
    :sint32 => SignedNumber{Int32},
    :sint64 => SignedNumber{Int64},
    :bool => Bool,
    :fixed64 => FixedSizeNumber{UInt64},
    :sfixed64 => FixedSizeNumber{Int64},
    :double => Float64,
    :float => Float32,
    :fixed32 => FixedSizeNumber{UInt32},
    :sfixed32 => FixedSizeNumber{Int32},
    :string => AbstractString,
    :bytes => Vector{UInt8},
    :map => Dict,
    :obj => Any
    )

julia_wiretype(s::Symbol) = _wiretype_dict[s]

wiretypes(::Type{Int32})                            = [:int32, :enum]
wiretypes(::Type{Int64})                            = [:int64]
wiretypes(::Type{UInt32})                           = [:uint32]
wiretypes(::Type{UInt64})                           = [:uint64]
wiretypes(::Type{SignedNumber{Int32}})              = [:sint32]
wiretypes(::Type{SignedNumber{Int64}})              = [:sint64]
wiretypes(::Type{Bool})                             = [:bool]
wiretypes(::Type{FixedSizeNumber{UInt64}})          = [:fixed64]
wiretypes(::Type{FixedSizeNumber{Int64}})           = [:sfixed64]
wiretypes(::Type{Float64})                          = [:double]
wiretypes(::Type{Float32})                          = [:float]
wiretypes(::Type{FixedSizeNumber{UInt32}})          = [:fixed32]
wiretypes(::Type{FixedSizeNumber{Int32}})           = [:sfixed32]
wiretypes(::Type{T}) where {T<:AbstractString}      = [:string]
wiretypes(::Type{Vector{UInt8}})                    = [:bytes]
wiretypes(::Type{Dict{K,V}}) where {K,V}            = [:map]
wiretypes(::Type)                                   = [:obj]
wiretypes(::Type{Vector{T}}) where {T}              = wiretypes(T)

wiretype(::Type{T}) where {T}                       = wiretypes(T)[1]

defaultval(::Type{T}) where {T<:Number}             = [zero(T)]
defaultval(::Type{T}) where {T<:AbstractString}     = [convert(T,"")]
defaultval(::Type{Bool})                            = [false]
defaultval(::Type{Vector{T}}) where {T}             = Any[T[]]
defaultval(::Type{Dict{K,V}}) where {K,V}           = [Dict{K,V}()]
defaultval(::Type)                                  = []

function _write_uleb(io::IO, x::T) where T <: Integer
    nw = 0
    cont = true
    while cont
        byte = x & MASK7
        if (x >>>= 7) != 0
            byte |= MSB
        else
            cont = false
        end
        nw += write(io, UInt8(byte))
    end
    nw
end

# max number of 7bit blocks for reading n bytes
# d,r = divrem(sizeof(T)*8, 7)
# (r > 0) && (d += 1)
const _max_n = [2, 3, 4, 5, 6, 7, 8, 10]

function _read_uleb_base(io::IO, ::Type{T}) where T <: Integer
    res = zero(T)
    n = 0
    byte = UInt8(MSB)
    while (byte & MSB) != 0
        byte = read(io, UInt8)
        res |= (convert(T, byte & MASK7) << (7*n))
        n += 1
    end
    n, res
end

function _read_uleb(io::IO, ::Type{Int32})
    n, res = _read_uleb_base(io, Int32)

    # negative int32 are encoded in 10 bytes (ref: https://developers.google.com/protocol-buffers/docs/encoding)
    # > if you use int32 or int64 as the type for a negative number, the resulting varint is always ten bytes long
    #
    # but Julia can be tolerant like the C protobuf implementation (unlike python)

    if n > _max_n[sizeof(res < 0 ? Int64 : Int32)]
        @debug("overflow reading Int32. returning 0")
        return Int32(0)
    end

    res
end

function _read_uleb(io::IO, ::Type{T}) where T <: Integer
    n, res = _read_uleb_base(io, T)
    # in case of overflow, consider it as missing field and return default value
    if n > _max_n[sizeof(T)]
        @debug("overflow reading integer type. returning 0", T)
        return zero(T)
    end
    res
end

function _write_zigzag(io::IO, x::T) where T <: Integer
    nbits = 8*sizeof(x)
    zx = (x << 1) ⊻ (x >> (nbits-1))
    _write_uleb(io, zx)
end

function _read_zigzag(io::IO, ::Type{T}) where T <: Integer
    zx = _read_uleb(io, UInt64)
    # result is positive if zx is even
    convert(T, iseven(zx) ? (zx >>> 1) : -signed((zx+1) >>> 1))
end

##
# read and write field keys
_write_key(io::IO, fld::Int, wiretyp::Int) = _write_uleb(io, (fld << 3) | wiretyp)
function _read_key(io::IO)
    key = _read_uleb(io, UInt64)
    wiretyp = key & MASK3
    fld = key >>> 3
    (fld, wiretyp)
end

##
# read and write field values
write_varint(io::IO, x::T) where {T <: Integer} = _write_uleb(io, x)
write_varint(io::IO, x::Int32) = _write_uleb(io, x < 0 ? Int64(x) : x)
write_bool(io::IO, x::Bool) = _write_uleb(io, x ? 1 : 0)
write_svarint(io::IO, x::T) where {T <: Integer} = _write_zigzag(io, x)

read_varint(io::IO, ::Type{T}) where {T <: Integer} = _read_uleb(io, T)
read_bool(io::IO) = Bool(_read_uleb(io, UInt64))
read_bool(io::IO, ::Type{Bool}) = read_bool(io)
read_svarint(io::IO, ::Type{T}) where {T <: Integer} = _read_zigzag(io, T)

write_fixed(io::IO, x::UInt32) = _write_fixed(io, x)
write_fixed(io::IO, x::UInt64) = _write_fixed(io, x)
write_fixed(io::IO, x::Int32) = _write_fixed(io, reinterpret(UInt32, x))
write_fixed(io::IO, x::Int64) = _write_fixed(io, reinterpret(UInt64, x))
write_fixed(io::IO, x::Float32) = _write_fixed(io, reinterpret(UInt32, x))
write_fixed(io::IO, x::Float64) = _write_fixed(io, reinterpret(UInt64, x))
function _write_fixed(io::IO, ux::T) where T <: Unsigned
    N = sizeof(ux)
    for n in 1:N
        write(io, UInt8(ux & MASK8))
        ux >>>= 8
    end
    N
end

read_fixed(io::IO, typ::Type{UInt32}) = _read_fixed(io, convert(UInt32,0), 4)
read_fixed(io::IO, typ::Type{UInt64}) = _read_fixed(io, convert(UInt64,0), 8)
read_fixed(io::IO, typ::Type{Int32}) = reinterpret(Int32, _read_fixed(io, convert(UInt32,0), 4))
read_fixed(io::IO, typ::Type{Int64}) = reinterpret(Int64, _read_fixed(io, convert(UInt64,0), 8))
read_fixed(io::IO, typ::Type{Float32}) = reinterpret(Float32, _read_fixed(io, convert(UInt32,0), 4))
read_fixed(io::IO, typ::Type{Float64}) = reinterpret(Float64, _read_fixed(io, convert(UInt64,0), 8))
function _read_fixed(io::IO, ret::T, N::Int) where T <: Unsigned
    for n in 0:(N-1)
        byte = convert(T, read(io, UInt8))
        ret |= (byte << (8*n))
    end
    ret
end

function write_bytes(io::IO, data::Vector{UInt8})
    n = _write_uleb(io, sizeof(data))
    n += write(io, data)
    n
end

function read_bytes(io::IO)
    n = _read_uleb(io, UInt64)
    data = Vector{UInt8}(undef, n)
    read!(io, data)
    data
end
read_bytes(io::IO, ::Type{Vector{UInt8}}) = read_bytes(io)

write_string(io::IO, x::AbstractString) = write_string(io, String(x))
write_string(io::IO, x::String) = write_bytes(io, @static isdefined(Base, :codeunits) ? unsafe_wrap(Vector{UInt8}, x) : Vector{UInt8}(x))

read_string(io::IO) = String(read_bytes(io))
read_string(io::IO, ::Type{T}) where {T <: AbstractString} = convert(T, read_string(io))

writeproto() = 0
readproto() = nothing

wire_type(::Type{Int32})                                        = WIRETYP_VARINT
wire_type(::Type{Int64})                                        = WIRETYP_VARINT
wire_type(::Type{UInt32})                                       = WIRETYP_VARINT
wire_type(::Type{UInt64})                                       = WIRETYP_VARINT
wire_type(::Type{SignedNumber{Int32}})                          = WIRETYP_VARINT
wire_type(::Type{SignedNumber{Int64}})                          = WIRETYP_VARINT
wire_type(::Type{Bool})                                         = WIRETYP_VARINT
wire_type(::Type{Enum})                                         = WIRETYP_VARINT
wire_type(::Type{FixedSizeNumber{UInt64}})                      = WIRETYP_64BIT
wire_type(::Type{FixedSizeNumber{Int64}})                       = WIRETYP_64BIT
wire_type(::Type{Float64})                                      = WIRETYP_64BIT
wire_type(::Type{T}) where {T<:AbstractString}                  = WIRETYP_LENDELIM
wire_type(::Type{Vector{UInt8}})                                = WIRETYP_LENDELIM
wire_type(::Type{Dict{K,V}}) where {K,V}                        = WIRETYP_LENDELIM
wire_type(::Type)                                               = WIRETYP_LENDELIM
wire_type(::Type{FixedSizeNumber{UInt32}})                      = WIRETYP_32BIT
wire_type(::Type{FixedSizeNumber{Int32}})                       = WIRETYP_32BIT
wire_type(::Type{Float32})                                      = WIRETYP_32BIT
wire_type(::Type{Vector{T}}) where {T}                          = wire_type(T)

_read_value(io::IO, ::Type{FixedSizeNumber{T}}) where T<:Number = read_fixed(io, T)
_read_value(io::IO, ::Type{SignedNumber{T}}) where T<:Number    = read_svarint(io, T)
_read_value(io::IO, ::Type{T}) where T<:Number                  = read_varint(io, T)
_read_value(io::IO, ::Type{T}) where T<:Union{Float32,Float64}  = read_fixed(io, T)
_read_value(io::IO, ::Type{T}) where T<:AbstractString          = read_string(io, T)
_read_value(io::IO, ::Type{Vector{UInt8}})                      = read_bytes(io, Vector{UInt8})

_write_value(io::IO, val::FixedSizeNumber{T}) where T<:Number   = write_fixed(io, val.number)
_write_value(io::IO, val::SignedNumber{T}) where T<:Number      = write_svarint(io, val.number)
_write_value(io::IO, val::T) where T<:Number                    = write_varint(io, val)
_write_value(io::IO, val::T) where T<:Union{Float32,Float64}    = write_fixed(io, val)
_write_value(io::IO, val::T) where T<:AbstractString            = write_string(io, val)
_write_value(io::IO, val::Vector{UInt8})                        = write_bytes(io, val)

##
# read and write protobuf structures

mutable struct ProtoMetaAttribs{P}
    fldnum::Int             # the field number in the structure
    fld::Symbol             # field name
    ptyp::Type{P}           # protobuf type
    jtyp::Type              # Julia type
    occurrence::Int         # 0: optional, 1: required, 2: repeated
    packed::Bool            # if repeated, whether packed
    default::Array          # the default value, empty array if none is specified, first element is used if something is specified
    meta::Any               # the ProtoMeta if this is a nested type
end

mutable struct ProtoMeta
    jtype::Type
    symdict::Dict{Symbol,ProtoMetaAttribs}
    numdict::Dict{Int,ProtoMetaAttribs}
    ordered::Vector{ProtoMetaAttribs}
    oneofs::Vector{Int}
    oneof_names::Vector{Symbol}

    function ProtoMeta(jtype::Type, ordered::Vector{ProtoMetaAttribs}, oneofs::Vector{Int}=Int[], oneof_names::Vector{Symbol}=Symbol[])
        setprotometa!(new(), jtype, ordered, oneofs, oneof_names)
    end

    function ProtoMeta(jtype::Type)
        new(jtype)
    end
end

function setprotometa!(meta::ProtoMeta, jtype::Type, ordered::Vector{ProtoMetaAttribs}, oneofs::Vector{Int}, oneof_names::Vector{Symbol})
    symdict = Dict{Symbol,ProtoMetaAttribs}()
    numdict = Dict{Int,ProtoMetaAttribs}()
    for attrib in ordered
        symdict[attrib.fld] = numdict[attrib.fldnum] = attrib
    end
    meta.jtype = jtype
    meta.symdict = symdict
    meta.numdict = numdict
    meta.ordered = ordered
    meta.oneofs = oneofs
    meta.oneof_names = oneof_names
    meta
end

ConcreteTypes = Union{Number,FixedSizeNumber,SignedNumber,AbstractString,Vector{UInt8}}
function writeproto(io::IO, val::T, attrib::ProtoMetaAttribs{P}) where {T<:ConcreteTypes,P}
    fldnum = attrib.fldnum
    value = convert(P, val)

    n = 0
    n += _write_key(io, fldnum, wire_type(P))
    n += _write_value(io, value)
    n
end

function writeproto(io::IO, dict::Dict{K,V}, attrib::ProtoMetaAttribs) where {K,V}
    fldnum = attrib.fldnum
    dmeta = mapentry_meta(typeof(dict))
    iob = IOBuffer()

    n = 0
    for key in keys(dict)
        @debug("write_map", key)
        val = dict[key]
        writeproto(iob, key, dmeta.ordered[1])
        @debug("write_map", val)
        writeproto(iob, val, dmeta.ordered[2])
        n += _write_key(io, fldnum, WIRETYP_LENDELIM)
        n += write_bytes(io, take!(iob))
    end
    n
end

function writeproto(io::IO, val::Array{T}, attrib::ProtoMetaAttribs{P}) where {T,P}
    fldnum = attrib.fldnum
    meta = attrib.meta
    iob = IOBuffer()

    n = 0
    (attrib.occurrence == 2) || error("expected meta attributes of $(attrib.fldnum) to specify an array")
    if attrib.packed
        # write elements as a length delimited field
        if P == Any
            error("can not write object field $fldnum as packed")
        else
            for eachval in val
                _write_value(iob, convert(P, eachval))
            end
        end
        n += _write_key(io, fldnum, WIRETYP_LENDELIM)
        n += write_bytes(io, take!(iob))
    else
        # write each element separately
        # maps can not be repeated
        if P == Any
            for eachval in val
                writeproto(iob, eachval, meta)
                n += _write_key(io, fldnum, WIRETYP_LENDELIM)
                n += write_bytes(io, take!(iob))
            end
        else
            for eachval in val
                n += _write_key(io, fldnum, wire_type(typeof(val)))
                n += _write_value(io, convert(P, eachval))
            end
        end
    end
    n
end

function writeproto(io::IO, obj::T, attrib::ProtoMetaAttribs) where {T}
    fld = attrib.fldnum
    meta = attrib.meta

    iob = IOBuffer()
    n = 0
    writeproto(iob, obj, meta)
    n += _write_key(io, fld, WIRETYP_LENDELIM)
    n += write_bytes(io, take!(iob))
    n
end

function writeproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    n = 0
    @debug("writeproto writing an obj", meta)
    for attrib in meta.ordered
        fld = attrib.fld
        if hasproperty(obj, fld)
            @debug("writeproto", field=fld)
            n += writeproto(io, getproperty(obj, fld), attrib)
        else
            @debug("not set", field=fld)
            (attrib.occurrence == 1) && error("missing required field $fld (#$(attrib.fldnum))")
        end
    end
    n
end

function read_lendelim_packed(io, fld::Vector{T}) where {T}
    iob = IOBuffer(read_bytes(io))
    while !eof(iob)
        val = _read_value(iob, T)
        push!(fld, val)
    end
    nothing
end

function read_lendelim_obj(io, obj, meta::ProtoMeta)
    fld_buf = read_bytes(io)
    readproto(IOBuffer(fld_buf), obj, meta)
    obj
end

instantiate(t::Type) = ccall(:jl_new_struct_uninit, Any, (Any,), t)
instantiate(t::Type{T}) where {T <: ProtoType} = T()

function skip_field(io::IO, wiretype::Integer)
    if wiretype == WIRETYP_LENDELIM
        read_bytes(io)
    elseif wiretype == WIRETYP_64BIT
        read_fixed(io, UInt64)
    elseif wiretype == WIRETYP_32BIT
        read_fixed(io, UInt32)
    elseif wiretype == WIRETYP_VARINT
        read_varint(io, UInt64)
    end
    nothing
end

function read_field(io, container, attrib::ProtoMetaAttribs, wiretyp, jtyp::Type{T}) where T<:ConcreteTypes
    return _read_value(io, attrib.ptyp)
end

function read_field(io, container, attrib::ProtoMetaAttribs, wiretyp, typ::Type{Vector{T}}) where T
    fld = attrib.fld
    ptyp = attrib.ptyp

    arr_val = ((container !== nothing) && hasproperty(container, fld)) ? convert(typ, getproperty(container, fld)) : ptyp[]
    # Readers should accept repeated fields in both packed and expanded form.
    # Allows compatibility with old writers when [packed = true] is added later.
    # Only repeated fields of primitive numeric types (isbitstype == true) can be declared "packed".
    # Maps can not be repeated
    if isbitstype(ptyp) && (wiretyp == WIRETYP_LENDELIM)
        read_lendelim_packed(io, arr_val)
    elseif T <: ConcreteTypes
        push!(arr_val, _read_value(io, ptyp))
    else
        push!(arr_val, read_lendelim_obj(io, instantiate(T), attrib.meta))
    end
    return arr_val
end

function read_field(io, container, attrib::ProtoMetaAttribs, wiretyp, jtyp::Type{Dict{K,V}}) where {K,V}
    fld = attrib.fld

    (wiretyp != wire_type(jtyp)) && error("cannot read wire type $wiretyp as $(wire_type(jtyp))")
    dict = ((container !== nothing) && hasproperty(container, fld)) ? convert(jtyp, getproperty(container, fld)) : jtyp()

    iob = IOBuffer(read_bytes(io))
    dmeta = mapentry_meta(jtyp)
    key_val = Vector{Union{K,V}}(undef, 2)

    while !eof(iob)
        fldnum, wiretyp = _read_key(iob)
        @debug("reading map", fldnum)

        fldnum = Int(fldnum)
        attrib = dmeta.numdict[fldnum]

        if fldnum == 1
            key_val[1] = read_field(iob, nothing, attrib, wire_type(attrib.ptyp), K)
        elseif fldnum == 2
            key_val[2] = read_field(iob, nothing, attrib, wire_type(attrib.ptyp), V)
        else
            skip_field(iob, wiretyp)
        end
    end
    @debug("read map", key=key_val[1], val=key_val[2])
    dict[key_val[1]] = key_val[2]
    dict
end

function read_field(io, container, attrib::ProtoMetaAttribs, wiretyp, jtyp_object)
    fld = attrib.fld

    (wiretyp != wire_type(jtyp_object)) && error("cannot read wire type $wiretyp as $(wire_type(jtyp_object))")
    val_obj = ((container !== nothing) && hasproperty(container, fld)) ? getproperty(container, fld) : instantiate(jtyp_object)
    return read_lendelim_obj(io, val_obj, attrib.meta)
end

function readproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    @debug("readproto begin", typ=typeof(obj))
    clear(obj)
    while !eof(io)
        fldnum, wiretyp = _read_key(io)
        @debug("reading", typ=typeof(obj), fldnum)

        fldnum = Int(fldnum)
        attrib = get(meta.numdict, fldnum, nothing)

        # ignore unknown fields
        if attrib === nothing
            @debug("skipping unknown field", typ=typeof(obj), fldnum)
            skip_field(io, wiretyp)
            continue
        end

        val = read_field(io, obj, attrib, wiretyp, attrib.jtyp)
        fld = attrib.fld
        setproperty!(obj, fld, convert(attrib.jtyp, val))
    end

    setdefaultproperties!(obj, meta)
    @debug("readproto end", typ=typeof(obj))

    obj
end

function setdefaultproperties!(obj::ProtoType, meta::ProtoMeta=meta(typeof(obj)))
    for (idx,attrib) in enumerate(meta.ordered)
        fld = attrib.fld
        # TODO: do not fill if oneof the fields in the oneof
        if !hasproperty(obj, fld) && !isempty(attrib.default) && !_isset_oneof(obj, idx)
            default = attrib.default[1]
            setproperty!(obj, fld, convert(attrib.jtyp, deepcopy(default)))
            @debug("readproto set default", typ=typeof(obj), fld, default)
            _markdefaultproperty!(obj, fld)
        end
    end
    obj
 end

##
# helpers
const DEF_REQ = Symbol[]
const DEF_FNUM = Int[]
const DEF_VAL = Dict{Symbol,Any}()
const DEF_PACK = Symbol[]
const DEF_WTYPES = Dict{Symbol,Symbol}()
const DEF_ONEOFS = Int[]
const DEF_ONEOF_NAMES = Symbol[]
const DEF_FIELD_TYPES = Dict{Symbol,String}()

function metalock(f)
    lock(MetaLock) do
        f()
    end
end

_resolve_type(relativeto::Type, typ::Type) = typ
_resolve_type(relativeto::Type, typ::String) = Core.eval(relativeto.name.module, Meta.parse(typ))

function meta(target::ProtoMeta, typ::Type, all_fields::Vector{Pair{Symbol,Union{Type,String}}}, required::Vector{Symbol}, numbers::Vector{Int}, defaults::Dict{Symbol,Any},
        pack::Vector{Symbol}=DEF_PACK, wtypes::Dict=DEF_WTYPES, oneofs::Vector{Int}=DEF_ONEOFS, oneof_names::Vector{Symbol}=DEF_ONEOF_NAMES)
    attribs = ProtoMetaAttribs[]
    for fldidx in 1:length(all_fields)
        fldname = first(all_fields[fldidx])
        fldtyp = _resolve_type(typ, last(all_fields[fldidx]))
        fldnum = isempty(numbers) ? fldidx : numbers[fldidx]
        isarr = (fldtyp <: Array) && !(fldtyp === Vector{UInt8})
        repeat = isarr ? 2 : (fldname in required) ? 1 : 0

        elemtyp = isarr ? eltype(fldtyp) : fldtyp
        wtyp = julia_wiretype(get(wtypes, fldname, wiretype(elemtyp)))
        packed = (isarr && (fldname in pack))
        default = haskey(defaults, fldname) ? Any[defaults[fldname]] : defaultval(fldtyp)

        fldmeta = (wtyp == Any) ? meta(elemtyp) :
                  (wtyp == Dict) ? mapentry_meta(elemtyp) : nothing
        push!(attribs, ProtoMetaAttribs(fldnum, fldname, wtyp, fldtyp, repeat, packed, default, fldmeta))
    end
    setprotometa!(target, typ, attribs, oneofs, oneof_names)
end

function mapentry_meta(typ::Type{Dict{K,V}}) where {K,V}
    target = ProtoMeta(typ)
    attribs = ProtoMetaAttribs[]
    push!(attribs, ProtoMetaAttribs(1, :key, julia_wiretype(wiretype(K)), K, 0, false, defaultval(K), nothing))

    isarr = (V <: Array) && !(V === Vector{UInt8})
    repeat = isarr ? 2 : 0
    packed = isarr
    wtyp = julia_wiretype(wiretype(V))
    vmeta = (wtyp == Any) ? meta(V) :
            (wtyp == Dict) ? mapentry_meta(V) : nothing
    push!(attribs, ProtoMetaAttribs(2, :value, wtyp, V, repeat, packed, defaultval(V), vmeta))

    setprotometa!(target, typ, attribs, DEF_ONEOFS, DEF_ONEOF_NAMES)
end

function isfilled(obj)
    fldattribs = meta(typeof(obj)).ordered
    for idx in 1:length(fldattribs)
        fldattrib = fldattribs[idx]
        if fldattrib.occurrence == 1
            fldname = fldattrib.fld
            hasproperty(obj, fldname) || (return false)
            (fldattrib.meta !== nothing) && !isfilled(getproperty(obj, fldname)) && (return false)
        end
    end
    true
end

function _isset_oneof(obj, idx::Int)
    m = meta(typeof(obj))
    oneofs = m.oneofs
    oneof_idx = isempty(oneofs) ? 0 : oneofs[idx]
    (oneof_idx > 0) || (return false)
    _which_oneof(obj, m, oneof_idx) !== Symbol()
end

function which_oneof(obj, oneof::Symbol)
    m = meta(typeof(obj))
    oneof_idx = something(findfirst(isequal(oneof), m.oneof_names))
    _which_oneof(obj, m, oneof_idx)
end

function _which_oneof(obj, m, oneof_idx)
    oneofs = m.oneofs
    for idx in 1:length(oneofs)
        if oneofs[idx] == oneof_idx
            fldname = m.ordered[idx].fld
            hasproperty(obj, fldname) && (return fldname)
        end
    end
    Symbol()
end

function _unset_oneof(obj, objmeta, fld)
    if !isempty(objmeta.oneofs)
        fldidx = 1
        while fldidx <= length(objmeta.ordered)
            if objmeta.ordered[fldidx].fld === fld
                break
            else
                fldidx += 1
            end
        end
        nameidx = objmeta.oneofs[fldidx]
        if nameidx > 0
            oneofprop = _which_oneof(obj, objmeta, nameidx)
            (oneofprop === Symbol()) || clear(obj, oneofprop)
        end
    end
end

function show(io::IO, m::ProtoMeta)
    println(io, "ProtoMeta for $(m.jtype)")
    println(io, m.ordered)
end

propertynames(obj::ProtoType) = [attrib.fld for attrib in obj.__protobuf_jl_internal_meta.ordered]
hasproperty(obj::ProtoType, fld::Symbol) = haskey(obj.__protobuf_jl_internal_values, fld)
function setproperty!(obj::ProtoType, fld::Symbol, val)
    objmeta = obj.__protobuf_jl_internal_meta
    symdict = objmeta.symdict
    if fld in keys(symdict)
        _unset_oneof(obj, objmeta, fld)
        fldtype = symdict[fld].jtyp
        obj.__protobuf_jl_internal_values[fld] = isa(val, fldtype) ? val : convert(fldtype, val)
        delete!(obj.__protobuf_jl_internal_defaultset, fld)
    else
        setfield!(obj, fld, val)
    end
end
_markdefaultproperty!(obj::ProtoType, fld::Symbol) = push!(obj.__protobuf_jl_internal_defaultset, fld)
isdefaultproperty(obj::ProtoType, fld::Symbol) = fld in obj.__protobuf_jl_internal_defaultset

function clear(obj::ProtoType)
    empty!(obj.__protobuf_jl_internal_values)
    nothing
end

function clear(obj::ProtoType, fld::Symbol)
    delete!(obj.__protobuf_jl_internal_values, fld)
    nothing
end

##
# Enum Lookup
function lookup(en::T, val) where {T <: NamedTuple}
    for name in propertynames(en)
        (val == getproperty(en, name)) && return name
    end
    error("Enum has no value $val")
end
