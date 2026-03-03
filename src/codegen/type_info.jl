const BOXED = TypeInfo(true, false, 8, 8)

function _align(sz, al, fsz, fal)
    al = max(al, fal)
    remainder = sz % fal
    if remainder != 0
        sz += fal - remainder
    end
    sz += fsz
    return sz, al
end

query_typeinfo!(t::ReferencedType, ctx) = query_typeinfo!(_get_referenced_type(t, ctx), ctx)
query_typeinfo!(::DoubleType, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::FloatType, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::Int32Type, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::Int64Type, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::UInt32Type, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::UInt64Type, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::SInt32Type, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::SInt64Type, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::Fixed32Type, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::Fixed64Type, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::SFixed32Type, ctx) = TypeInfo(true, true, 4, 4)
query_typeinfo!(::SFixed64Type, ctx) = TypeInfo(true, true, 8, 8)
query_typeinfo!(::BoolType, ctx) = TypeInfo(true, true, 1, 1)
query_typeinfo!(::StringType, ctx) = BOXED
query_typeinfo!(::BytesType, ctx) = BOXED
query_typeinfo!(::MapType, ctx) = BOXED
query_typeinfo!(::EnumType, ctx) = TypeInfo(true, true, 4, 4) # Currently we only generate 4 byte enums
query_typeinfo!(f::AbstractProtoFieldType, ctx) = _is_repeated_field(f) ? BOXED : query_typeinfo!(f.type, ctx)
query_typeinfo!(f::GroupType, ctx) = _is_repeated_field(f) ? BOXED : query_typeinfo!(t.type, ctx)
function query_typeinfo!(t::OneOfType, ctx) # relies on the TaggedUnion layout!
    bits_size = Int8(0)
    bits_alignment = Int8(0)
    ptrs_size = Int8(0)
    ptrs_alignment = Int8(0)
    any_bits = false
    any_ptrs = false

    for f in t.fields
        tinfo = query_typeinfo!(f, ctx)
        if tinfo.isbits && tinfo.size <= 16 # check
            any_bits = true
            bits_size = max(bits_size, tinfo.size)
            bits_alignment = max(bits_alignment, tinfo.alignment)
        else
            any_ptrs = true
            ptrs_size = max(ptrs_size, tinfo.size)
            ptrs_alignment = max(ptrs_alignment, tinfo.alignment)
        end

    end

    _alignment = Int8(1) # the explicit tag field in the tagged oneof struct
    _size = Int8(1)      # the explicit tag field in the tagged oneof struct
    if any_bits
        # The tag used by Julia in the Union{Nothing, ...} field
        _size, _alignment = _align(_size, _alignment, Int8(1), Int8(1))
        _size, _alignment = _align(_size, _alignment, bits_size, bits_alignment)
    end
    if any_ptrs
        # The tag used by Julia in the Union{Nothing, ...} field
        _size, _alignment = _align(_size, _alignment, Int8(1), Int8(1))
        _size, _alignment = _align(_size, _alignment, ptrs_size, ptrs_alignment)
    end

    out = TypeInfo(true, !any_ptrs, _size, _alignment)
    return out
end

function query_typeinfo!(t::MessageType, ctx)
    tinfo = t.tinfo[]
    if !tinfo.known
        if t.is_self_referential[]
            tinfo = BOXED
        else
            _alignment = Int8(0)
            _size = Int8(0)
            _isbits = !t.is_self_referential[] # && !appears_in_cycle
            for f in t.fields
                f_tinfo = query_typeinfo!(f, ctx)
                _isbits &= f_tinfo.isbits
                _size, _alignment = _align(_size, _alignment, f_tinfo.size, f_tinfo.alignment)
            end
            tinfo = TypeInfo(true, _isbits, _size, _alignment)
        end

        t.tinfo[] = tinfo
    end
    return tinfo
end