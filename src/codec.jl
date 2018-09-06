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

# TODO: wiretypes should become julia types, so that methods can be parameterized on them
const WIRETYPES = Dict{Symbol,Tuple}(
    :int32          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int32),
    :int64          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int64),
    :uint32         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   UInt32),
    :uint64         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   UInt64),
    :sint32         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int32),
    :sint64         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int64),
    :bool           => (WIRETYP_VARINT,     :write_bool,    :read_bool,     Bool),
    :enum           => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int32),

    :fixed64        => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    UInt64),
    :sfixed64       => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Int64),
    :double         => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),

    :string         => (WIRETYP_LENDELIM,   :write_string,  :read_string,   AbstractString),
    :bytes          => (WIRETYP_LENDELIM,   :write_bytes,   :read_bytes,    Vector{UInt8}),
    :obj            => (WIRETYP_LENDELIM,   :writeproto,    :readproto,     Any),
    :map            => (WIRETYP_LENDELIM,   :write_map,     :read_map,      Dict),

    :fixed32        => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    UInt32),
    :sfixed32       => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Int32),
    :float          => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32)
)

aliaswiretypes(wtype::Symbol) = wiretypes(WIRETYPES[wtype][4])

wiretypes(::Type{Int32})                            = [:int32, :sint32, :enum, :sfixed32]
wiretypes(::Type{Int64})                            = [:int64, :sint64, :sfixed64]
wiretypes(::Type{UInt32})                           = [:uint32, :fixed32]
wiretypes(::Type{UInt64})                           = [:uint64, :fixed64]
wiretypes(::Type{Bool})                             = [:bool]
wiretypes(::Type{Float64})                          = [:double]
wiretypes(::Type{Float32})                          = [:float]
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
        @debug("overflow reading $T. returning 0")
        return Int32(0)
    end

    res
end

function _read_uleb(io::IO, ::Type{T}) where T <: Integer
    n, res = _read_uleb_base(io, T)
    # in case of overflow, consider it as missing field and return default value
    if n > _max_n[sizeof(T)]
        @debug("overflow reading $T. returning 0")
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

##
# read and write protobuf structures

mutable struct ProtoMetaAttribs
    fldnum::Int             # the field number in the structure
    fld::Symbol
    ptyp::Symbol            # protobuf type
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

    ProtoMeta(jtype::Type, ordered::Vector{ProtoMetaAttribs}, oneofs::Vector{Int}=Int[], oneof_names::Vector{Symbol}=Symbol[]) = _setmeta(new(), jtype, ordered, oneofs, oneof_names)
end

function _setmeta(meta::ProtoMeta, jtype::Type, ordered::Vector{ProtoMetaAttribs}, oneofs::Vector{Int}, oneof_names::Vector{Symbol})
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

function write_map(io::IO, fldnum::Int, dict::Dict)
    dmeta = mapentry_meta(typeof(dict))
    iob = IOBuffer()

    n = 0
    for key in keys(dict)
        @debug("write_map writing key: $key")
        val = dict[key]
        writeproto(iob, key, dmeta.ordered[1])
        @debug("write_map writing val: $val")
        writeproto(iob, val, dmeta.ordered[2])
        n += _write_key(io, fldnum, WIRETYP_LENDELIM)
        n += write_bytes(io, take!(iob))
    end
    n
end

function writeproto(io::IO, val, attrib::ProtoMetaAttribs)
    fld = attrib.fldnum
    meta = attrib.meta
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    iob = IOBuffer()
    wfn = eval(write_fn)

    n = 0
    wfn(iob, convert(jtyp, val), meta)
    n += _write_key(io, fld, WIRETYP_LENDELIM)
    n += write_bytes(io, take!(iob))
    n
end

function writeproto(io::IO, val::T, attrib::ProtoMetaAttribs) where T<:Number
    fld = attrib.fldnum
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    wfn = eval(write_fn)

    n = 0
    n += _write_key(io, fld, wiretyp)
    n += wfn(io, convert(jtyp, val))
    n
end

function writeproto(io::IO, val::T, attrib::ProtoMetaAttribs) where T<:AbstractString
    fld = attrib.fldnum
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]

    n = 0
    n += _write_key(io, fld, wiretyp)
    n += write_string(io, val)
    n
end

writeproto(io::IO, val::Dict, attrib::ProtoMetaAttribs) = write_map(io, attrib.fldnum, convert(attrib.meta.jtype, val))

function writeproto(io::IO, val::Vector{UInt8}, attrib::ProtoMetaAttribs)
    fld = attrib.fldnum
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]

    n = 0
    n += _write_key(io, fld, wiretyp)
    n += write_bytes(io, val)
    n
end

function writeproto(io::IO, val::Array{T}, attrib::ProtoMetaAttribs) where T
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    wfn = eval(write_fn)

    writeproto(io, val, attrib, wfn)
end

function writeproto(io::IO, val::Array{T}, attrib::ProtoMetaAttribs, wfn::F) where {T,F}
    fld = attrib.fldnum
    meta = attrib.meta
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    iob = IOBuffer()

    n = 0
    (attrib.occurrence == 2) || error("expected meta attributes of $(attrib.fld) to specify an array")
    if attrib.packed
        # write elements as a length delimited field
        if ptyp == :obj
            error("can not write object field $fld as packed")
        else
            for eachval in val
                wfn(iob, convert(jtyp, eachval))
            end
        end
        n += _write_key(io, fld, WIRETYP_LENDELIM)
        n += write_bytes(io, take!(iob))
    else
        # write each element separately
        # maps can not be repeated
        if ptyp == :obj
            for eachval in val
                wfn(iob, convert(jtyp, eachval), meta)
                n += _write_key(io, fld, WIRETYP_LENDELIM)
                n += write_bytes(io, take!(iob))
            end
        else
            for eachval in val
                n += _write_key(io, fld, wiretyp)
                n += wfn(io, convert(jtyp, eachval))
            end
        end
    end
    n
end

function writeproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    n = 0
    @debug("writeproto writing an obj with meta: $meta")
    for attrib in meta.ordered
        fld = attrib.fld
        if isfilled(obj, fld)
            @debug("writeproto writing field: $fld")
            n += writeproto(io, getfield(obj, fld), attrib)
        else
            @debug("field not set: $fld")
            (attrib.occurrence == 1) && error("missing required field $fld (#$(attrib.fldnum))")
        end
    end
    n
end

function read_lendelim_packed(io, fld, reader, jtyp::Type)
    iob = IOBuffer(read_bytes(io))
    while !eof(iob)
        val = reader(iob, jtyp)
        push!(fld, val)
    end
    nothing
end

function read_lendelim_obj(io, val, meta::ProtoMeta, reader)
    fld_buf = read_bytes(io)
    reader(IOBuffer(fld_buf), val, meta)
    val
end

instantiate(t::Type) = ccall(:jl_new_struct_uninit, Any, (Any,), t)
instantiate(t::T) where {T <: ProtoType} = T()

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

function read_map(io, dict::Dict{K,V}) where {K,V}
    iob = IOBuffer(read_bytes(io))

    dmeta = mapentry_meta(Dict{K,V})
    key_wtyp, key_wfn, key_rfn, key_jtyp = WIRETYPES[dmeta.numdict[1].ptyp]
    val_wtyp, val_wfn, val_rfn, val_jtyp = WIRETYPES[dmeta.numdict[2].ptyp]
    key_val = Vector{Union{K,V}}(undef, 2)

    while !eof(iob)
        fldnum, wiretyp = _read_key(iob)
        @debug("reading map fldnum: $fldnum")

        fldnum = Int(fldnum)
        attrib = dmeta.numdict[fldnum]

        if fldnum == 1
            key_val[1] = read_field(iob, nothing, attrib, key_wtyp, K)
        elseif fldnum == 2
            key_val[2] = read_field(iob, nothing, attrib, val_wtyp, V)
        else
            skip_field(iob, wiretyp)
        end
    end
    @debug("read map key: $(key_val[1])=$(key_val[2])")
    dict[key_val[1]] = key_val[2]
    dict
end

function read_field(io, container, attrib::ProtoMetaAttribs, wiretyp, jtyp_specific)
    ptyp = attrib.ptyp
    fld = attrib.fld

    _wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    rfn = eval(read_fn)
    isrepeat = (attrib.occurrence == 2)

    if jtyp_specific != nothing
        jtyp = jtyp_specific
    elseif ptyp == :obj
        jtyp = attrib.meta.jtype
    elseif ptyp == :map
        jtyp = attrib.meta.jtype
    end

    if isrepeat
        arr_val = ((container != nothing) && isdefined(container, fld)) ? convert(Vector{jtyp}, getfield(container, fld)) : jtyp[]
        # Readers should accept repeated fields in both packed and expanded form.
        # Allows compatibility with old writers when [packed = true] is added later.
        # Only repeated fields of primitive numeric types (isbitstype == true) can be declared "packed".
        # Maps can not be repeated
        if isbitstype(jtyp) && (wiretyp == WIRETYP_LENDELIM)
            read_lendelim_packed(io, arr_val, rfn, jtyp)
        elseif ptyp == :obj
            push!(arr_val, read_lendelim_obj(io, instantiate(jtyp), attrib.meta, rfn))
        else
            push!(arr_val, rfn(io, jtyp))
        end
        return arr_val
    else
        (wiretyp != _wiretyp) && !isrepeat && error("cannot read wire type $wiretyp as $ptyp")

        if ptyp == :obj
            val_obj = ((container != nothing) && isdefined(container, fld)) ? getfield(container, fld) : instantiate(jtyp)
            return read_lendelim_obj(io, val_obj, attrib.meta, rfn)
        elseif ptyp == :map
            val_map = ((container != nothing) && isdefined(container, fld)) ? convert(jtyp, getfield(container, fld)) : jtyp()
            return read_map(io, val_map)
        else
            @debug("reading type $jtyp")
            return rfn(io, jtyp)
        end
    end
end

function readproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    @debug("readproto begin: $(typeof(obj))")
    fillunset(obj)
    fldnums = collect(keys(meta.numdict))
    while !eof(io)
        fldnum, wiretyp = _read_key(io)
        @debug("reading fldnum: $(typeof(obj)).$fldnum")

        fldnum = Int(fldnum)
        # ignore unknown fields
        if !(fldnum in fldnums)
            @debug("skipping unknown field: $(typeof(obj)).$fldnum")
            skip_field(io, wiretyp)
            continue
        end
        attrib = meta.numdict[fldnum]

        val = read_field(io, obj, attrib, wiretyp, nothing)
        fld = attrib.fld
        fillset(obj, fld)
        if (attrib.occurrence == 2) || (attrib.ptyp == :obj) || (attrib.ptyp == :map)
            setfield!(obj, fld, convert(fld_type(obj, fld), val))
        else
            setfield!(obj, fld, val)
        end
    end

    # populate defaults
    fnames = fld_names(typeof(obj))
    fill = filled(obj)
    for attrib in meta.ordered
        fld = attrib.fld
        idx = something(findfirst(isequal(fld), fnames))
        # TODO: do not fill if oneof the fields in the oneof
        if !isfilled(obj, fld) && (length(attrib.default) > 0) && !_isset_oneof(fill, meta.oneofs, idx)
            default = attrib.default[1]
            setfield!(obj, fld, convert(fld_type(obj, fld), deepcopy(default)))
            @debug("readproto set default: $(typeof(obj)).$fld = $default")
            fillset_default(obj, fld)
        end
    end
    @debug("readproto end: $(typeof(obj))")
    obj
end


##
# helpers
oiddict() = @static isdefined(Base, :IdDict) ? IdDict() : ObjectIdDict()
const _metacache = oiddict() # dict of Type => ProtoMeta
const _mapentry_metacache = oiddict()
const _fillcache = Dict{UInt,BitArray{2}}()

const DEF_REQ = Symbol[]
const DEF_FNUM = Int[]
const DEF_VAL = Dict{Symbol,Any}()
const DEF_PACK = Symbol[]
const DEF_WTYPES = Dict{Symbol,Symbol}()
const DEF_ONEOFS = Int[]
const DEF_ONEOF_NAMES = Symbol[]
const DEF_FIELD_TYPES = Dict{Symbol,String}()

meta(typ::Type) = haskey(_metacache, typ) ? _metacache[typ] : meta(typ, DEF_REQ, DEF_FNUM, DEF_VAL, true, DEF_PACK, DEF_WTYPES, DEF_ONEOFS, DEF_ONEOF_NAMES, DEF_FIELD_TYPES)
function meta(typ::Type, required::Array, numbers::Array, defaults::Dict, cache::Bool=true, pack::Array=DEF_PACK, wtypes::Dict=DEF_WTYPES,
                oneofs::Vector{Int}=DEF_ONEOFS, oneof_names::Vector{Symbol}=DEF_ONEOF_NAMES, field_types::Dict{Symbol,String}=DEF_FIELD_TYPES)
    haskey(_metacache, typ) && return _metacache[typ]
    d = Dict{Symbol,Any}()
    for (k,v) in defaults
        d[k] = v
    end
    meta(typ, convert(Vector{Symbol}, required), convert(Vector{Int}, numbers), d, cache, convert(Vector{Symbol}, pack), wtypes, oneofs, oneof_names, field_types)
end
function meta(typ::Type, required::Vector{Symbol}, numbers::Vector{Int}, defaults::Dict{Symbol,Any}, cache::Bool=true, pack::Vector{Symbol}=DEF_PACK,
                wtypes::Dict=DEF_WTYPES, oneofs::Vector{Int}=DEF_ONEOFS, oneof_names::Vector{Symbol}=DEF_ONEOF_NAMES, field_types::Dict{Symbol,String}=DEF_FIELD_TYPES)
    haskey(_metacache, typ) && return _metacache[typ]

    m = ProtoMeta(typ, ProtoMetaAttribs[])
    cache && (_metacache[typ] = m)

    attribs = ProtoMetaAttribs[]
    names = fld_names(typ)
    types = typ.types
    for fldidx in 1:length(names)
        fldname = names[fldidx]
        fldtyp = (fldname in keys(field_types)) ? Core.eval(typ.name.module, (@static (VERSION < v"0.7.0-alpha") ? parse : Meta.parse)(field_types[fldname])) : types[fldidx]
        fldnum = isempty(numbers) ? fldidx : numbers[fldidx]
        isarr = (fldtyp <: Array) && !(fldtyp === Vector{UInt8})
        repeat = isarr ? 2 : (fldname in required) ? 1 : 0

        elemtyp = isarr ? eltype(fldtyp) : fldtyp
        wtyp = get(wtypes, fldname, wiretype(elemtyp))
        packed = (isarr && (fldname in pack))
        default = haskey(defaults, fldname) ? Any[defaults[fldname]] : defaultval(fldtyp)

        fldmeta = (wtyp == :obj) ? meta(elemtyp) :
                  (wtyp == :map) ? mapentry_meta(elemtyp) : nothing
        push!(attribs, ProtoMetaAttribs(fldnum, fldname, wtyp, repeat, packed, default, fldmeta))
    end
    _setmeta(m, typ, attribs, oneofs, oneof_names)
    m
end

function mapentry_meta(typ::Type{Dict{K,V}}) where {K,V}
    m = ProtoMeta(typ, ProtoMetaAttribs[])
    _mapentry_metacache[typ] = m

    attribs = ProtoMetaAttribs[]
    push!(attribs, ProtoMetaAttribs(1, :key, wiretype(K), 0, false, defaultval(K), nothing))

    isarr = (V <: Array) && !(V === Vector{UInt8})
    repeat = isarr ? 2 : 0
    packed = isarr
    wtyp = wiretype(V)
    vmeta = (wtyp == :obj) ? meta(V) :
            (wtyp == :map) ? mapentry_meta(V) : nothing
    push!(attribs, ProtoMetaAttribs(2, :value, wtyp, repeat, packed, defaultval(V), vmeta))

    _setmeta(m, typ, attribs, DEF_ONEOFS, DEF_ONEOF_NAMES)
    m
end

function _unset_oneofs(fill::BitArray{2}, oneofs::Vector{Int}, idx::Int)
    oneofidx = isempty(oneofs) ? 0 : oneofs[idx]
    if oneofidx > 0
        # unset other fields in the oneof group
        for uidx = 1:length(oneofs)
            if (oneofs[uidx] == oneofidx) && (uidx !== idx)
                fill[1:2,uidx] .= false
            end
        end
    end
end

function _isset_oneof(fill::BitArray{2}, oneofs::Vector{Int}, idx::Int)
    oneofidx = isempty(oneofs) ? 0 : oneofs[idx]
    if oneofidx > 0
        # find if any field in the oneof group is set
        for uidx = 1:length(oneofs)
            if oneofs[uidx] == oneofidx
                fill[1,uidx] && (return true)
            end
        end
    end
    false
end

fillunset(obj) = (fill!(filled(obj), false); nothing)
fillunset(obj, fld::Symbol) = _fillset(obj, fld, false, false)
fillset(obj, fld::Symbol) = _fillset(obj, fld, true, false)
fillset_default(obj, fld::Symbol) = _fillset(obj, fld, true, true)
function _fillset(obj, fld::Symbol, val::Bool, isdefault::Bool)
    fill = filled(obj)
    fnames = fld_names(typeof(obj))
    idx = something(findfirst(isequal(fld), fnames))
    fill[1,idx] = val
    (!val || isdefault) && (fill[2,idx] = val)
    val && _unset_oneofs(fill, meta(typeof(obj)).oneofs, idx)
    nothing
end

function filled(obj)
    oid = objectid(obj)
    haskey(_fillcache, oid) && return _fillcache[oid]

    fnames = fld_names(typeof(obj))
    fill = fill!(BitArray(undef, 2, length(fnames)), false)
    oneofs = meta(typeof(obj)).oneofs
    for idx in 1:length(fnames)
        if isdefined(obj, fnames[idx])
            fill[1,idx] = true
            _unset_oneofs(fill, oneofs, idx)
        end
    end
    if !isimmutable(obj)
        _fillcache[oid] = fill
        finalizer(obj->delete!(_fillcache, objectid(obj)), obj)
    end
    fill
end

isfilled(obj, fld::Symbol) = _isfilled(obj, fld, false)
isfilled_default(obj, fld::Symbol) = _isfilled(obj, fld, true)
function _isfilled(obj, fld::Symbol, isdefault::Bool)
    fnames = fld_names(typeof(obj))
    idx = something(findfirst(isequal(fld), fnames))
    filled(obj)[isdefault ? 2 : 1, idx]
end

function isfilled(obj)
    fill = filled(obj)
    flds = meta(typeof(obj)).ordered
    for idx in 1:length(flds)
        fld = flds[idx]
        if fld.occurrence == 1
            fill[1,idx] || (return false)
            (fld.meta != nothing) && !isfilled(getfield(obj, fld.fld)) && (return false)
        end
    end
    true
end

function which_oneof(obj, oneof::Symbol)
    m = meta(typeof(obj))
    fill = filled(obj)
    fnames = fld_names(typeof(obj))
    oneofs = m.oneofs
    oneof_idx = something(findfirst(isequal(oneof), m.oneof_names))

    for idx in 1:length(oneofs)
        (oneofs[idx] == oneof_idx) && fill[1,idx] && (return fnames[idx])
    end
    Symbol()
end

function show(io::IO, m::ProtoMeta)
    println(io, "ProtoMeta for $(m.jtype)")
    println(io, m.ordered)
end


##
# Enum Lookup

abstract type ProtoEnum end

function lookup(en::ProtoEnum, val)
    for name in fld_names(typeof(en))
        (val == getfield(en, name)) && return name
    end
    error("Enum $(typeof(en)) has no value: $val")
end
