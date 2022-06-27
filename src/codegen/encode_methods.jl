function encode_condition(f::FieldType, ctx)
    if _is_repeated_field(f)
        return "!isempty(x.$(jl_fieldname(f)))"
    else
        return _encode_condition(f, ctx)
    end
end
_encode_condition(f::FieldType, ctx) = "x.$(jl_fieldname(f)) != $(jl_default_value(f, ctx))"
function _encode_condition(f::FieldType{T}, ctx) where {T<:Union{StringType,BytesType}}
    default = get(f.options, "default", nothing)
    if default === nothing
        return "!isempty(x.$(jl_fieldname(f)))"
    end
    return "x.$(jl_fieldname(f)) != $(jl_default_value(f, ctx))"
end
_encode_condition(f::OneOfType, ctx) = "!isnothing(x.$(jl_fieldname(f)))"
function _encode_condition(f::FieldType{ReferencedType}, ctx)
    if _is_message(f.type, ctx)
        return "!isnothing(x.$(jl_fieldname(f)))"
    else
        return "x.$(jl_fieldname(f)) != $(jl_default_value(f, ctx))"
    end
end

field_encode_expr(f::GroupType, ctx) = "PB.encode(e, $(f.number), x.$(jl_fieldname(f)))"
function field_encode_expr(f::FieldType, ctx)
    if _is_repeated_field(f)
        encoding_val_type = _decoding_val_type(f.type)
        !isempty(encoding_val_type) && (encoding_val_type = ", $encoding_val_type")
        # TODO: do we want to allow unpacked representation? Docs say that parsers must always handle both cases
        # and since packed is strictly more efficient, currently we don't allow that.
        # is_packed = parse(Bool, get(f.options, "packed", "false"))
        # if is_packed
            return "PB.encode(e, $(f.number), x.$(jl_fieldname(f))$(encoding_val_type))"
        # else
        #     return """
        #     for el in x.$(jl_fieldname(f))
        #                 PB.encode(e, $(f.number), el$(encoding_val_type))
        #             end"""
        # end
    else
        return _field_encode_expr(f, ctx)
    end
end

_field_encode_expr(f::FieldType, ctx) = "PB.encode(e, $(f.number), x.$(jl_fieldname(f)))"
_field_encode_expr(f::GroupType, ctx) = "PB.encode(e, $(f.number), x.$(jl_fieldname(f)))"
_field_encode_expr(f::FieldType{<:AbstractProtoFixedType}, ctx) = "PB.encode(e, $(f.number), x.$(jl_fieldname(f)), Val{:fixed})"
_field_encode_expr(f::FieldType{<:Union{SInt32Type,SInt64Type}}, ctx) = "PB.encode(e, $(f.number), x.$(jl_fieldname(f)), Val{:zigzag})"
function _field_encode_expr(f::FieldType{<:MapType}, ctx)
    K = _decoding_val_type(f.type.keytype)
    V = _decoding_val_type(f.type.valuetype)
    isempty(V) && isempty(K) && return "PB.encode(e, $(f.number), $(jl_fieldname(f)))"
    !isempty(V) && isempty(K) && return "PB.encode(e, $(f.number), $(jl_fieldname(f)), Val{Tuple{Nothing,$(V)}})"
    isempty(V) && !isempty(K) && return "PB.encode(e, $(f.number), $(jl_fieldname(f)), Val{Tuple{$(K),Nothing}})"
    return "PB.encode(e, $(f.number), $(jl_fieldname(f)), Val{Tuple{$(K),$(V)}})"
end

function print_field_encode_expr(io, f::FieldType, ctx)
    println(io, "    ", encode_condition(f, ctx), " && ", field_encode_expr(f, ctx))
end

function print_field_encode_expr(io, f::GroupType, ctx)
    println(io, "    isnothing!($(jl_fieldname(f))) && ", field_encode_expr(f, ctx))
end

function print_field_encode_expr(io, fs::OneOfType, ctx)
    println(io, "    if isnothing(x.$(safename(fs)));")
    for f in fs.fields
        println(io, "    elseif ", "x.$(safename(fs)).name == :", jl_fieldname(f))
        println(io, "    " ^ 2, "PB.encode(e, $(f.number), x.$(safename(fs))[])")
    end
    println(io, "    end")
end

function generate_encode_method(io, t::MessageType, ctx)
    println(io, "function PB.encode(e::PB.ProtoEncoder, x::$(safename(t)))")
    println(io, "    initpos = position(e.io)")
    for field in t.fields
        print_field_encode_expr(io, field, ctx)
    end
    println(io, "    return position(e.io) - initpos", )
    println(io, "end")
end

function generate_encode_method(io, t::GroupType, ctx)
    generate_encode_method(io, t.type, ctx)
end
