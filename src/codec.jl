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

# TODO: wiretypes should become julia types, so that methods can be parameterized on them
const WIRETYPES = Dict{Symbol,Tuple}([
    :int32          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int32),
    :int64          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int64),
    :uint32         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Uint32),
    :uint64         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Uint64),
    :sint32         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int32),
    :sint64         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int64),
    :bool           => (WIRETYP_VARINT,     :write_bool,    :read_bool,     Bool),
    :enum           => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int32),

    :fixed64        => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),
    :sfixed64       => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),
    :double         => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),

    :string         => (WIRETYP_LENDELIM,   :write_string,  :read_string,   String),
    :bytes          => (WIRETYP_LENDELIM,   :write_bytes,   :read_bytes,    Array{Uint8,1}),
    :obj            => (WIRETYP_LENDELIM,   :writeproto,    :readproto,     Any),

    :fixed32        => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32),
    :sfixed32       => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32),
    :float          => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32)
])


wiretypes(::Type{Int32})                    = [:int32, :sint32, :enum]
wiretypes(::Type{Int64})                    = [:int64, :sint64]
wiretypes(::Type{Uint32})                   = [:uint32]
wiretypes(::Type{Uint64})                   = [:uint64]
wiretypes(::Type{Bool})                     = [:bool]
wiretypes(::Type{Float64})                  = [:double, :fixed, :sfixed64]
wiretypes(::Type{Float32})                  = [:float, :fixed32, :sfixed32]
wiretypes{T<:String}(::Type{T})             = [:string]
wiretypes(::Type{Array{Uint8,1}})           = [:bytes]
wiretypes(::Type)                           = [:obj]
wiretypes{T}(::Type{Array{T,1}})            = wiretypes(T)

wiretype(t::Type) = wiretypes(t)[1]

defaultval{T<:Number}(::Type{T})            = [convert(T,0)]
defaultval{T<:String}(::Type{T})            = [convert(T,"")]
defaultval(::Type{Bool})                    = [false]
defaultval{T}(::Type{Array{T,1}})           = [T[]]
defaultval(::Type)                          = []


function _write_uleb{T <: Integer}(io::IO, x::T)
    nw = 0
    cont = true
    while cont
        byte = x & MASK7
        if (x >>>= 7) != 0
            byte |= MSB
        else
            cont = false
        end
        nw += write(io, uint8(byte))
    end
    nw
end

function _read_uleb{T <: Integer}(io::IO, typ::Type{T})
    res = convert(typ, 0) 
    n = 0
    byte = uint8(MSB)
    while (byte & MSB) != 0
        byte = read(io, Uint8)
        res |= (convert(typ, byte & MASK7) << (7*n))
        n += 1
    end
    res
end

function _write_zigzag{T <: Integer}(io::IO, x::T)
    nbits = 8*sizeof(x)
    zx = (x << 1) $ (x >> (nbits-1))
    _write_uleb(io, zx)
end

function _read_zigzag{T <: Integer}(io::IO, typ::Type{T})
    zx = _read_uleb(io, Uint64)
    # result is positive if zx is even
    convert(typ, iseven(zx) ? (zx >>> 1) : -((zx+1) >>> 1))
end


##
# read and write field keys
_write_key(io::IO, fld::Int, wiretyp::Int) = _write_uleb(io, (fld << 3) | wiretyp)
function _read_key(io::IO)
    key = _read_uleb(io, Uint64)
    wiretyp = key & MASK3
    fld = key >>> 3
    (fld, wiretyp)
end


##
# read and write field values
write_varint{T <: Integer}(io::IO, x::T) = _write_uleb(io, x)
write_bool(io::IO, x::Bool) = _write_uleb(io, x ? 1 : 0)
write_svarint{T <: Integer}(io::IO, x::T) = _write_zigzag(io, x)

read_varint{T <: Integer}(io::IO, typ::Type{T}) = _read_uleb(io, typ)
read_bool(io::IO) = bool(_read_uleb(io, Uint64))
read_bool(io::IO, ::Type{Bool}) = read_bool(io)
read_svarint{T <: Integer}(io::IO, typ::Type{T}) = _read_zigzag(io, typ)

write_fixed(io::IO, x::Float32) = _write_fixed(io, reinterpret(Uint32, x))
write_fixed(io::IO, x::Float64) = _write_fixed(io, reinterpret(Uint64, x))
function _write_fixed{T <: Unsigned}(io::IO, ux::T)
    N = sizeof(ux)
    for n in 1:N
        write(io, uint8(ux & MASK8))
        ux >>>= 8
    end
    N
end

read_fixed(io::IO, typ::Type{Float32}) = reinterpret(Float32, _read_fixed(io, uint32(0), 4))
read_fixed(io::IO, typ::Type{Float64}) = reinterpret(Float64, _read_fixed(io, uint64(0), 8))
function _read_fixed{T <: Unsigned}(io::IO, ret::T, N::Int)
    for n in 0:(N-1)
        byte = convert(T, read(io, Uint8))
        ret |= (byte << 8*n)
    end
    ret
end

function write_bytes(io::IO, data::Array{Uint8,1})
    n = _write_uleb(io, sizeof(data))
    n += write(io, data)
    n
end

function read_bytes(io::IO)
    n = _read_uleb(io, Uint64)
    data = Array(Uint8, n)
    read!(io, data)
    data
end
read_bytes(io::IO, ::Type{Array{Uint8,1}}) = read_bytes(io)

write_string(io::IO, x::String) = write_string(io, bytestring(x))
write_string(io::IO, x::ByteString) = write_bytes(io, x.data)

read_string(io::IO) = bytestring(read_bytes(io))
read_string(io::IO, ::Type{String}) = read_string(io)
read_string{T <: ByteString}(io::IO, ::Type{T}) = convert(T, read_string(io))

##
# read and write protobuf structures

type ProtoMetaAttribs
    fldnum::Int             # the field number in the structure
    fld::Symbol
    ptyp::Symbol            # protobuf type
    occurrence::Int         # 0: optional, 1: required, 2: repeated
    packed::Bool            # if repeated, whether packed
    default::Array          # the default value, empty array if none is specified, first element is used if something is specified
    meta::Any               # the ProtoMeta if this is a nested type
end

type ProtoMeta
    jtype::Type
    symdict::Dict{Symbol,ProtoMetaAttribs}
    numdict::Dict{Int,ProtoMetaAttribs}
    ordered::Array{ProtoMetaAttribs,1}

    ProtoMeta(jtype::Type, ordered::Array{ProtoMetaAttribs,1}) = _setmeta(new(), jtype, ordered)
end

function _setmeta(meta::ProtoMeta, jtype::Type, ordered::Array{ProtoMetaAttribs,1})
    symdict = Dict{Symbol,ProtoMetaAttribs}()
    numdict = Dict{Int,ProtoMetaAttribs}()
    for attrib in ordered
        symdict[attrib.fld] = numdict[attrib.fldnum] = attrib
    end
    meta.jtype = jtype
    meta.symdict = symdict
    meta.numdict = numdict
    meta.ordered = ordered
    meta
end

function writeproto(io::IO, val, attrib::ProtoMetaAttribs)
    !isempty(attrib.default) && isequal(val, attrib.default[1]) && (return 0)
    fld = attrib.fldnum
    meta = attrib.meta
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    iob = IOBuffer()
    wfn = eval(write_fn)

    n = 0
    if attrib.occurrence == 2
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
            n += write_bytes(io, takebuf_array(iob))
        else
            # write each element separately
            if ptyp == :obj
                for eachval in val
                    wfn(iob, convert(jtyp, eachval), meta)
                    n += _write_key(io, fld, WIRETYP_LENDELIM)
                    n += write_bytes(io, takebuf_array(iob))
                end
            else
                for eachval in val
                    n += _write_key(io, fld, wiretyp)
                    n += wfn(io, convert(jtyp, eachval))
                end
            end
        end
    else
        if ptyp == :obj
            wfn(iob, convert(jtyp, val), meta)
            n += _write_key(io, fld, WIRETYP_LENDELIM)
            n += write_bytes(io, takebuf_array(iob))
        else
            n += _write_key(io, fld, wiretyp)
            n += wfn(io, convert(jtyp, val))
        end
    end
    n
end

function writeproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    n = 0
    for attrib in meta.ordered 
        fld = attrib.fld
        if isfilled(obj, fld)
            n += writeproto(io, getfield(obj, fld), attrib)
        else
            (attrib.occurrence == 1) && error("missing required field $fld (#$(attrib.fldnum))")
        end
    end
    n
end

function read_lendelim_packed(io::IO, fld::Array, reader::Symbol, jtyp::Type)
    iob = IOBuffer(read_bytes(io))
    rfn = eval(reader)
    while !eof(iob)
        val = rfn(iob, jtyp)
        push!(fld, val)
    end
    nothing
end

function read_lendelim_obj(io::IO, val, meta::ProtoMeta, reader::Symbol)
    fld_buf = read_bytes(io)
    eval(reader)(IOBuffer(fld_buf), val, meta)
    val
end

instantiate(t::Type) = ccall(:jl_new_struct_uninit, Any, (Any,), t)

function readproto(io::IO, obj, meta::ProtoMeta=meta(typeof(obj)))
    #logmsg("readproto begin: $(typeof(obj))")
    fillunset(obj)
    while !eof(io)
        fldnum, wiretyp = _read_key(io)
        #logmsg("reading fldnum: $(typeof(obj)).$fldnum")

        attrib = meta.numdict[int(fldnum)]
        ptyp = attrib.ptyp
        fld = attrib.fld
        fillset(obj, fld)
        #logmsg("readproto fld: $(typeof(obj)).$fld")

        _wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
        rfn = eval(read_fn)
        isrepeat = (attrib.occurrence == 2)

        (ptyp == :obj) && (jtyp = attrib.meta.jtype)

        if isrepeat 
            ofld = isdefined(obj, fld) ? getfield(obj, fld) : jtyp[]
            if attrib.packed
                (wiretyp != WIRETYP_LENDELIM) && error("unexpected wire type for repeated packed field $fld (#$fldnum)")
                read_lendelim_packed(io, ofld, read_fn, jtyp)
            else
                push!(ofld, (ptyp == :obj) ? read_lendelim_obj(io, instantiate(jtyp), attrib.meta, read_fn) : rfn(io, jtyp))
            end
            setfield!(obj, fld, ofld)
            #logmsg("readproto set repeated: $(typeof(obj)).$fld = $ofld")
        else
            (wiretyp != _wiretyp) && !isrepeat && error("cannot read wire type $wiretyp as $ptyp")

            if ptyp == :obj
                val = isdefined(obj, fld) ? getfield(obj, fld) : instantiate(jtyp)
                val = read_lendelim_obj(io, val, attrib.meta, read_fn)
            else
                val = rfn(io, jtyp)
            end
            #logmsg("readproto set: $(typeof(obj)).$fld = $val")
            setfield!(obj, fld, val)
        end
    end

    # populate defaults
    for attrib in meta.ordered
        fld = attrib.fld
        if !isfilled(obj, fld) && (length(attrib.default) > 0)
            default = attrib.default[1]
            setfield!(obj, fld, deepcopy(default))
            fillset(obj, fld)
        end
    end
    #logmsg("readproto end: $(typeof(obj))")
    obj
end


##
# helpers
const _metacache = ObjectIdDict() #Dict{Type, ProtoMeta}()
const _fillcache = Dict{Uint, Array{Symbol,1}}()

const DEF_REQ = Symbol[]
const DEF_FNUM = Int[]
const DEF_VAL = Dict{Symbol,Any}()
const DEF_PACK = Symbol[]
const DEF_WTYPES = Dict{Symbol,Symbol}()

meta(typ::Type) = haskey(_metacache, typ) ? _metacache[typ] : meta(typ, DEF_REQ, DEF_FNUM, DEF_VAL, true, DEF_PACK, DEF_WTYPES)
function meta(typ::Type, required::Array, numbers::Array, defaults::Dict, cache::Bool=true, pack::Array=DEF_PACK, wtypes::Dict=DEF_WTYPES) 
    haskey(_metacache, typ) && return _metacache[typ]
    d = Dict{Symbol,Any}()
    for (k,v) in defaults
        d[k] = v
    end
    meta(typ, convert(Array{Symbol,1}, required), convert(Array{Int,1}, numbers), d, cache, convert(Array{Symbol,1}, pack), wtypes)
end
function meta(typ::Type, required::Array{Symbol,1}, numbers::Array{Int,1}, defaults::Dict{Symbol,Any}, cache::Bool=true, pack::Array{Symbol,1}=DEF_PACK, wtypes::Dict=DEF_WTYPES)
    haskey(_metacache, typ) && return _metacache[typ]

    m = ProtoMeta(typ, ProtoMetaAttribs[])
    cache ? (_metacache[typ] = m) : m

    attribs = ProtoMetaAttribs[]
    names = typ.names
    types = typ.types
    for fldidx in 1:length(names)
        fldtyp = types[fldidx]
        fldname = names[fldidx]
        fldnum = isempty(numbers) ? fldidx : numbers[fldidx]
        isarr = (fldtyp.name === Array.name) && !(fldtyp === Array{Uint8,1})
        repeat = isarr ? 2 : (fldname in required) ? 1 : 0
        elemtyp = isarr ? fldtyp.parameters[1] : fldtyp
        wtyp = get(wtypes, fldname, wiretype(elemtyp))
        packed = (isarr && (fldname in pack))
        default = haskey(defaults, fldname) ? Any[defaults[fldname]] : defaultval(fldtyp)

        push!(attribs, ProtoMetaAttribs(fldnum, fldname, wtyp, repeat, packed, default, (wtyp == :obj) ? meta(elemtyp) : nothing))
    end
    _setmeta(m, typ, attribs)
    m
end

fillunset(obj) = (empty!(filled(obj)); nothing)
function fillunset(obj, fld::Symbol)
    fill = filled(obj)
    idx = findfirst(fill, fld)
    (idx > 0) && splice!(fill, idx)
    nothing
end

function fillset(obj, fld::Symbol)
    fill = filled(obj)
    idx = findfirst(fill, fld)
    (idx > 0) && return
    push!(fill, fld)
    nothing
end

function filled(obj)
    oid = object_id(obj)
    haskey(_fillcache, oid) && return _fillcache[oid]

    fill = Symbol[]
    for fldname in names(typeof(obj))
        isdefined(obj, fldname) && push!(fill, fldname)
    end
    if !isimmutable(obj)
        _fillcache[oid] = fill
        finalizer(obj, obj->delete!(_fillcache, object_id(obj)))
    end
    fill
end

isfilled(obj, fld::Symbol) = (fld in filled(obj))
function isfilled(obj)
    fill = filled(obj)
    for fld in meta(typeof(obj)).ordered
        if fld.occurrence == 1
            !(fld.fld in fill) && (return false)
            (fld.meta != nothing) && !isfilled(getfield(obj, fld.fld)) && (return false)
        end
    end
    true
end

function show(io::IO, m::ProtoMeta)
    println(io, "ProtoMeta for $(m.jtype)")
    println(io, m.ordered)
end


##
# Enum Lookup

abstract ProtoEnum

function lookup(en::ProtoEnum, val::Integer)
    for name in typeof(en).names
        (val == getfield(en, name)) && return name
    end
    error("Enum $(typeof(en)) has no value: $val")
end
