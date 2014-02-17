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

const WIRETYPES = {
    :int32          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int32),
    :int64          => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int64),
    :uint32         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Uint32),
    :uint64         => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Uint64),
    :sint32         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int32),
    :sint64         => (WIRETYP_VARINT,     :write_svarint, :read_svarint,  Int64),
    :bool           => (WIRETYP_VARINT,     :write_bool,    :read_bool,     Bool),
    :enum           => (WIRETYP_VARINT,     :write_varint,  :read_varint,   Int),

    :fixed64        => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),
    :sfixed64       => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),
    :double         => (WIRETYP_64BIT,      :write_fixed,   :read_fixed,    Float64),

    :string         => (WIRETYP_LENDELIM,   :write_string,  :read_string,   String),
    :bytes          => (WIRETYP_LENDELIM,   :write_bytes,   :read_bytes,    Array{Uint8,1}),
    #embedded messages, packed repeated fields

    :fixed32        => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32),
    :sfixed32       => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32),
    :float          => (WIRETYP_32BIT,      :write_fixed,   :read_fixed,    Float32)
}

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

write_string(io, x::String) = write_string(io, bytestring(x))
write_string(io, x::ByteString) = write_bytes(io, x.data)
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
read_string(io) = bytestring(read_bytes(io))
read_string(io, ::Type{String}) = read_string(io)
read_string{T <: ByteString}(io, ::Type{T}) = convert(T, read_string(io))

##
# read and write protobuf structures
function writeproto(io, fld::Int, ptyp::Symbol, val)
    wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    n = _write_key(io, fld, wiretyp)
    eval(write_fn)(io, convert(jtyp, val))
end

function readproto(io, ptyp::Symbol)
    fld, wiretyp = _read_key(io)
    _wiretyp, write_fn, read_fn, jtyp = WIRETYPES[ptyp]
    (wiretyp != _wiretyp) && error("cannot read wire type $wiretyp as $ptyp")
    eval(read_fn)(io, jtyp)
end

