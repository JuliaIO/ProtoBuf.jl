function maybe_generate_tagged_oneofs(io, t::MessageType, ctx::Context)
    !(t.has_oneof_field && ctx.options.tagged_oneofs) && return nothing
    for field in fields
        field isa OneOfType || continue
        _generate_tagged_oneof(io, t, field::OneOfType, ctx)
    end
    return nothing
end

function _generate_tagged_oneof(io, t::MessageType, f::OneOfType, ctx::Context)
    println(io, "struct ",
        t.name, replace(titlecase(f.name), "_"=>""),
        t.is_self_referential ? "{T}" : "",
        " <: AbstractOneOf",
    )
    println(io, "    tag::", length(t.fields) > 256 ? "UInt16", "UInt8")
    println(io, "    bit::Union{Nothing, ", ,"}")
    println(io, "    ptr::Union{Nothing, ", ,"}")
end

function _split_oneof_types(fields)
    bittypes = NTuple{2,String}[]
    ptrtypes = NTuple{2,String}[]

    for f in fields
        f.
    end
end

query_isbits!(t::ReferencedType, ctx) = query_isbits!(_get_referenced_type(t, ctx))
query_isbits!(t::AbstractProtoNumericType, ctx) = true
query_isbits!(t::AbstractProtoNumericType, ctx) = true
query_isbits!(t::EnumType, ctx) = true
query_isbits!(t::StringType, ctx) = false
query_isbits!(t::BytesType, ctx) = false
query_isbits!(t::MapType, ctx) = false
query_isbits!(f::AbstractProtoFieldType, ctx) = !_is_repeated_field(f) && query_isbits!(f.type)
query_isbits!(f::GroupType, ctx) = !_is_repeated_field(f) && query_isbits!(t.type, ctx)
query_isbits!(t::OneOfType, ctx) = all(query_isbits!, t.fields)
function query_isbits!(t::MessageType, ctx)
    out = t.isbits[]
    if out == UNKNOWN
        out = (!t.is_self_referential[] && all(query_isbits!, t.fields)) ? ISBITS : NONISBITS
        t.isbits[] = out
    end

    return out == ISBITS
end
