_decoding_val_type(t::AbstractProtoType) = ""
_decoding_val_type(t::AbstractProtoFixedType) = ":fixed"
_decoding_val_type(t::T) where {T<:Union{SInt32Type,SInt64Type}} = ":zigzag"

jl_type_decode_expr(f::FieldType{<:AbstractProtoType}, ctx) = "$(jl_fieldname(f)) = PB.decode(d, $(jl_typename(f.type, ctx)))"
jl_type_decode_expr(f::FieldType{SFixed32Type}, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int32, Val{:fixed})"
jl_type_decode_expr(f::FieldType{SFixed64Type}, ctx) = "$(jl_fieldname(f)) = PB.decode(d, Int64, Val{:fixed})"
jl_type_decode_expr(f::FieldType{Fixed32Type}, ctx)  = "$(jl_fieldname(f)) = PB.decode(d, UInt32, Val{:fixed})"
jl_type_decode_expr(f::FieldType{Fixed64Type}, ctx)  = "$(jl_fieldname(f)) = PB.decode(d, UInt64, Val{:fixed})"
jl_type_decode_expr(f::FieldType{SInt32Type}, ctx)   = "$(jl_fieldname(f)) = PB.decode(d, Int32, Val{:zigzag})"
jl_type_decode_expr(f::FieldType{SInt64Type}, ctx)   = "$(jl_fieldname(f)) = PB.decode(d, Int64, Val{:zigzag})"
function jl_type_decode_expr(f::FieldType{MapType}, ctx)
    K = _decoding_val_type(f.type.keytype)
    V = _decoding_val_type(f.type.valuetype)
    isempty(V) && isempty(K)  && return "PB.decode!(d, $(jl_fieldname(f)))"
    !isempty(V) && isempty(K) && return "PB.decode!(d, $(jl_fieldname(f)), Val{Tuple{Nothing,$(V)}})"
    isempty(V) && !isempty(K) && return "PB.decode!(d, $(jl_fieldname(f)), Val{Tuple{$(K),Nothing}})"
    return "PB.decode!(d, $(jl_fieldname(f)), Val{Tuple{$(K),$(V)}})"
end

function jl_type_decode_repeated_expr(f::FieldType{T}, ctx) where {T<:Union{StringType,BytesType}}
    return "PB.decode!(d, $(jl_fieldname(f)))"
end
function jl_type_decode_repeated_expr(f::FieldType{T}, ctx) where {T<:AbstractProtoNumericType}
    return "PB.decode!(d, wire_type, $(jl_fieldname(f)))"
end
function jl_type_decode_repeated_expr(f::FieldType{T}, ctx) where {T<:AbstractProtoFixedType}
    return "PB.decode!(d, wire_type, $(jl_fieldname(f)), Var{:fixed})"
end
function jl_type_decode_repeated_expr(f::FieldType{T}, ctx) where {T<:Union{SInt32Type,SInt64Type}}
    return "PB.decode!(d, wire_type, $(jl_fieldname(f)), Var{:zigzag})"
end
function jl_type_decode_repeated_expr(f::FieldType{ReferencedType}, ctx)
    _is_message(f.type, ctx) && return "PB.decode!(d, $(jl_fieldname(f)))"
    return "PB.decode!(d, wire_type, $(jl_fieldname(f)))"
end
function jl_type_decode_expr(f::FieldType{ReferencedType}, ctx)
    _is_message(f.type, ctx) && return "PB.decode!(d, $(jl_fieldname(f)))"
    return "$(jl_fieldname(f)) = PB.decode(d, $(jl_typename(f.type, ctx)))"
end

function field_decode_expr(io, f::FieldType, i, ctx)
    if _is_repeated_field(f)
        decode_expr = jl_type_decode_repeated_expr(f, ctx)
    else
        decode_expr = jl_type_decode_expr(f, ctx)
    end
    println(io, "    " ^ 2, i == 1 ? "if " : "elseif ", "field_number == ", f.number)
    println(io, "    " ^ 3, decode_expr)
    return nothing
end

jl_type_oneof_decode_expr(f::FieldType, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, $(jl_typename(f.type, ctx))))"
jl_type_oneof_decode_expr(f::GroupType, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, $(jl_typename(f.type, ctx))))"
jl_type_oneof_decode_expr(f::FieldType{SFixed32Type}, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int32, Val{:fixed}))"
jl_type_oneof_decode_expr(f::FieldType{SFixed64Type}, ctx) = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int64, Val{:fixed}))"
jl_type_oneof_decode_expr(f::FieldType{Fixed32Type}, ctx)  = "OneOf(:$(jl_fieldname(f)), PB.decode(d, UInt32, Val{:fixed}))"
jl_type_oneof_decode_expr(f::FieldType{Fixed64Type}, ctx)  = "OneOf(:$(jl_fieldname(f)), PB.decode(d, UInt64, Val{:fixed}))"
jl_type_oneof_decode_expr(f::FieldType{SInt32Type}, ctx)   = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int32, Val{:zigzag}))"
jl_type_oneof_decode_expr(f::FieldType{SInt64Type}, ctx)   = "OneOf(:$(jl_fieldname(f)), PB.decode(d, Int64, Val{:zigzag}))"
function jl_type_oneof_decode_expr(f::FieldType{ReferencedType}, ctx)
      _is_message(f.type, ctx) && return "OneOf(:$(jl_fieldname(f)), PB.decode(d, Ref{$(jl_typename(f.type, ctx))}))"
      return "OneOf(:$(jl_fieldname(f)), PB.decode(d, $(jl_typename(f.type, ctx))))"
end
function field_decode_expr(io, field::OneOfType, i, ctx)
    field_name = jl_fieldname(field)
    for (j, case) in enumerate(field.fields)
        j += i
        println(io, "    " ^ 2, j == 2 ? "if " : "elseif ", "field_number == ", case.number)
        println(io, "    " ^ 3, field_name, " = ", jl_type_oneof_decode_expr(case, ctx))
    end
    return nothing
end

function field_decode_expr(io, field::GroupType, i, ctx)
    field_name = jl_fieldname(field)
    println(io, "    " ^ 2, i == 1 ? "if " : "elseif ", "field_number == ", field.number)
    println(io, "    " ^ 3, field_name, " = PB.decode(d, ", field_name, ")")
    return nothing
end

jl_fieldname_deref(f, ctx) = _is_repeated_field(f) ? "$(jl_fieldname(f))[]" : jl_fieldname(f)
function jl_fieldname_deref(f::FieldType{ReferencedType}, ctx)
    should_deref = _is_repeated_field(f) | _is_message(f.type, ctx)
    return should_deref ? "$(jl_fieldname(f))[]" : jl_fieldname(f)
end

function generate_decode_method(io, t::MessageType, ctx)
    println(io, "function PB.decode(d::PB.ProtoDecoder, ::Type{$(safename(t))})")
    # defaults
    for field in t.fields
        println(io, "    ", jl_fieldname(field), " = ", jl_default_value(field, ctx))
    end
    println(io, "    while !PB.message_done(d)")
    println(io, "        field_number, wire_type = PB.decode_tag(d)")
    for (i, field) in enumerate(t.fields)
        field_decode_expr(io, field, i, ctx)
    end
    println(io, "        else")
    println(io, "            PB.skip(d, wire_type)")
    println(io, "        end")
    println(io, "        PB.try_eat_end_group(d, wire_type)")
    println(io, "    end")
    print(io, "    return ", jl_typename(t, ctx), "(")
    print(io, join(map(f->jl_fieldname_deref(f, ctx), t.fields), ", "))
    println(io, ")")
    println(io, "end")
end