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
const WIRETYPES = {
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
}


wiretypes(::Type{Int32})            = [:int32, :sint32, :enum]
wiretypes(::Type{Int64})            = [:int64, :sint64]
wiretypes(::Type{Uint32})           = [:uint32]
wiretypes(::Type{Uint64})           = [:uint64]
wiretypes(::Type{Bool})             = [:bool]
wiretypes(::Type{Float64})          = [:double, :fixed, :sfixed64]
wiretypes(::Type{Float32})          = [:float, :fixed32, :sfixed32]
wiretypes{T<:String}(::Type{T})     = [:string]
wiretypes(::Type{Array{Uint8,1}})   = [:bytes]
wiretypes(::Type)                   = [:obj]

wiretype(t::Type) = wiretypes(t)[1]


function _write_uleb{T <: Integer}(io, x::T)
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

function _read_uleb{T <: Integer}(io, typ::Type{T})
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

function _write_zigzag{T <: Integer}(io, x::T)
    nbits = 8*sizeof(x)
    zx = (x << 1) $ (x >> (nbits-1))
    _write_uleb(io, zx)
end

function _read_zigzag{T <: Integer}(io, typ::Type{T})
    zx = _read_uleb(io, Uint64)
    # result is positive if zx is even
    convert(typ, iseven(zx) ? (zx >>> 1) : -((zx+1) >>> 1))
end


##
# read and write field keys
_write_key(io, fld::Int, wiretyp::Int) = _write_uleb(io, (fld << 3) | wiretyp)
function _read_key(io)
    key = _read_uleb(io, Uint64)
    wiretyp = key & MASK3
    fld = key >>> 3
    (fld, wiretyp)
end


##
# read and write field values
write_varint{T <: Integer}(io, x::T) = _write_uleb(io, x)
write_bool(io, x::Bool) = _write_uleb(io, x ? 1 : 0)
write_svarint{T <: Integer}(io, x::T) = _write_zigzag(io, x)

read_varint{T <: Integer}(io, typ::Type{T}) = _read_uleb(io, typ)
read_bool(io) = bool(_read_uleb(io, Uint64))
read_bool(io, ::Type{Bool}) = read_bool(io)
read_svarint{T <: Integer}(io, typ::Type{T}) = _read_zigzag(io, typ)

write_fixed(io, x::Float32) = _write_fixed(io, reinterpret(Uint32, x))
write_fixed(io, x::Float64) = _write_fixed(io, reinterpret(Uint64, x))
function _write_fixed{T <: Unsigned}(io, ux::T)
    N = sizeof(ux)
    for n in 1:N
        write(io, uint8(ux & MASK8))
        ux >>>= 8
    end
    N
end

read_fixed(io, typ::Type{Float32}) = reinterpret(Float32, _read_fixed(io, uint32(0), 4))
read_fixed(io, typ::Type{Float64}) = reinterpret(Float64, _read_fixed(io, uint64(0), 8))
function _read_fixed{T <: Unsigned}(io, ret::T, N::Int)
    for n in 0:(N-1)
        byte = convert(T, read(io, Uint8))
        ret |= (byte << 8*n)
    end
    ret
end

function write_bytes(io, data::Array{Uint8,1})
    n = _write_uleb(io, sizeof(data))
    n += write(io, data)
    n
end

function read_bytes(io)
    n = _read_uleb(io, Uint64)
    data = Array(Uint8, n)
    read(io, data)
    data
end
read_bytes(io, ::Type{Array{Uint8,1}}) = read_bytes(io)

write_string(io, x::String) = write_string(io, bytestring(x))
write_string(io, x::ByteString) = write_bytes(io, x.data)

read_string(io) = bytestring(read_bytes(io))
read_string(io, ::Type{String}) = read_string(io)
read_string{T <: ByteString}(io, ::Type{T}) = convert(T, read_string(io))

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

    function ProtoMeta(jtype::Type, ordered::Array{ProtoMetaAttribs,1})
        symdict = Dict{Symbol,ProtoMetaAttribs}()
        numdict = Dict{Int,ProtoMetaAttribs}()
        for attrib in ordered
            symdict[attrib.fld] = numdict[attrib.fldnum] = attrib
        end
        new(jtype, symdict, numdict, ordered)
    end
end

type ProtoFill
    jtype::Type
    filled::Dict{Symbol, Union(Bool,ProtoFill)}
end

function writeproto(io, val, attrib::ProtoMetaAttribs, fill)
    fld = attrib.fldnum
    meta = attrib.meta
    ptyp = attrib.ptyp
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]

    n = 0
    if attrib.occurrence == 2
        if attrib.packed
            # write elements as a length delimited field
            iob = IOBuffer()
            if ptyp == :obj
                error("can not write object field $fld as packed")
            else
                for eachval in val
                    eval(write_fn)(iob, convert(jtyp, eachval))
                end
            end
            n += _write_key(io, fld, WIRETYP_LENDELIM)
            n += write_bytes(io, takebuf_array(iob))
        else
            # write each field separately
            if ptyp == :obj
                # TODO: optimize IOBuffer creation
                for eachval in val
                    iob = IOBuffer()
                    eval(write_fn)(iob, convert(jtyp, eachval), meta, nothing)
                    n += _write_key(io, fld, WIRETYP_LENDELIM)
                    n += write_bytes(io, takebuf_array(iob))
                end
            else
                for eachval in val
                    n += _write_key(io, fld, wiretyp)
                    n += eval(write_fn)(io, convert(jtyp, eachval))
                end
            end
        end
    else
        if ptyp == :obj
            iob = IOBuffer()
            eval(write_fn)(iob, convert(jtyp, val), meta, fill)
            n += _write_key(io, fld, WIRETYP_LENDELIM)
            n += write_bytes(io, takebuf_array(iob))
        else
            n += _write_key(io, fld, wiretyp)
            n += eval(write_fn)(io, convert(jtyp, val))
        end
    end
    n
end

writeproto(io, obj) = writeproto(io, obj, meta(typeof(obj)))
writeproto(io, obj, fill::ProtoFill) = writeproto(io, obj, meta(typeof(obj)), fill)
function writeproto(io, obj, meta::ProtoMeta, fill=nothing)
    n = 0
    for attrib in meta.ordered 
        fld = attrib.fld
        filled = (fill == nothing) ? nothing : get(fill.filled, fld, false)
        if isdefined(obj, fld) && (filled != false)
            val = getfield(obj, fld)
            n += writeproto(io, val, attrib, filled)
        elseif attrib.occurrence == 1
            error("missing required field $fld (#$(attrib.fldnum))")
        end
    end
    n
end

function read_lendelim_packed(io, fld::Array, reader::Symbol, jtyp::Type)
    iob = IOBuffer(read_bytes(io))
    while !eof(iob)
        val = eval(reader)(iob, jtyp)
        push!(fld, val)
    end
    nothing
end

function read_lendelim_obj(io, val, meta::ProtoMeta, filled, reader::Symbol)
    fld_buf = read_bytes(io)
    eval(reader)(IOBuffer(fld_buf), val, meta, filled)
    val
end

readproto(io, obj) = readproto(io, obj, meta(typeof(obj)))
readproto(io, obj, fill::ProtoFill) = readproto(io, obj, meta(typeof(obj)), fill)
function readproto(io, obj, meta::ProtoMeta, fill=nothing)
    while !eof(io)
        fldnum, wiretyp = _read_key(io)

        attrib = meta.numdict[int(fldnum)]
        ptyp = attrib.ptyp
        fld = attrib.fld

        _wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
        isrepeat = (attrib.occurrence == 2)

        (ptyp == :obj) && (jtyp = attrib.meta.jtype)

        if isrepeat 
            ofld = getfield(obj, fld)
            if attrib.packed
                (wiretyp != WIRETYP_LENDELIM) && error("unexpected wire type for repeated packed field $fld (#$fldnum)")
                filled = true
                read_lendelim_packed(io, ofld, read_fn, jtyp)
            else
                filled = true
                push!(ofld, (ptyp == :obj) ? read_lendelim_obj(io, eval(jtyp)(), attrib.meta, nothing, read_fn) : eval(read_fn)(io, jtyp))
            end
        else
            (wiretyp != _wiretyp) && !isrepeat && error("cannot read wire type $wiretyp as $ptyp")

            if ptyp == :obj
                val = getfield(obj, fld)
                filled = (fill == nothing) ? nothing : ProtoFill(typeof(val), Dict{Symbol, Union(Bool,ProtoFill)}())
                val = read_lendelim_obj(io, getfield(obj, fld), attrib.meta, filled, read_fn)
            else
                filled = true
                val = eval(read_fn)(io, jtyp)
            end
            setfield!(obj, fld, val)
        end

        (nothing != fill) && (fill.filled[fld] = filled)
    end
end


##
# helpers
const _metacache = Dict{Type, ProtoMeta}()

meta(typ::Type) = meta(typ, true, Symbol[], Int[], Dict{Symbol,Any}())
function meta(typ::Type, cache::Bool, required::Array{Symbol,1}, numbers::Array{Int,1}, defaults::Dict{Symbol,Any})
    haskey(_metacache, typ) && return _metacache[typ]

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
        wtyp = wiretype(elemtyp)
        packed = (isarr && issubtype(elemtyp, Number))
        default = get(defaults, fldname, [])

        push!(attribs, ProtoMetaAttribs(fldnum, fldname, wtyp, repeat, packed, default, (wtyp == :obj) ? meta(elemtyp) : nothing))
    end
    m = ProtoMeta(typ, attribs)
    cache ? (_metacache[typ] = m) : m
end

function show(io::IO, m::ProtoMeta)
    println(io, "ProtoMeta for $(m.jtype)")
    println(io, m.ordered)
end

