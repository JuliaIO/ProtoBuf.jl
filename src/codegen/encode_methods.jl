function encode_condition(f::FieldType, ctx::Context)
    if _is_repeated_field(f)
        return "!isempty(x.$(jl_fieldname(f)))"
    else
        return _encode_condition(f, ctx)
    end
end
_encode_condition(@nospecialize(f::FieldType), ctx::Context) = "x.$(jl_fieldname(f)) != $(jl_init_value(f, ctx))"
_encode_condition(f::FieldType{<:AbstractProtoFloatType}, ctx:: Context) = "x.$(jl_fieldname(f)) !== $(jl_init_value(f, ctx))"
_encode_condition(f::FieldType{<:MapType}, ::Context) = "!isempty(x.$(jl_fieldname(f)))"
function _encode_condition(f::FieldType{T}, ctx::Context) where {T<:Union{StringType,BytesType}}
    default = get(f.options, "default", nothing)
    if default === nothing
        return "!isempty(x.$(jl_fieldname(f)))"
    end
    return "x.$(jl_fieldname(f)) != $(jl_init_value(f, ctx))"
end
_encode_condition(f::OneOfType, ::Context) = "!isnothing(x.$(jl_fieldname(f)))"
function _encode_condition(f::FieldType{ReferencedType}, ctx::Context)
    if _is_message(f.type, ctx)
        return "!isnothing(x.$(jl_fieldname(f)))"
    else
        return "x.$(jl_fieldname(f)) != $(jl_init_value(f, ctx))"
    end
end

field_encode_expr(f::GroupType, ::Context) = "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{:group})"
function field_encode_expr(@nospecialize(f::FieldType), ctx::Context)
    if _is_repeated_field(f)
        encoding_val_type = _decoding_val_type(f.type)
        !isempty(encoding_val_type) && (encoding_val_type = ", Val{$encoding_val_type}")
        # TODO: do we want to allow unpacked representation? Docs say that parsers must always handle both cases
        # and since packed is strictly more efficient, currently we don't allow that.
        is_packed = parse(Bool, get(f.options, "packed", "false"))
        if is_packed
            return "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f))$(encoding_val_type))"
        else
	        return """
		        for el in x.$(jl_fieldname(f))
			        PB.encode(e, $(string(f.number)), el$(encoding_val_type))
		        end
	        """
        end
    else
        return _field_encode_expr(f, ctx)
    end
end

_field_encode_expr(f::FieldType, ::Context) = "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)))"
_field_encode_expr(f::GroupType, ::Context) = "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)))"
_field_encode_expr(f::FieldType{<:AbstractProtoFixedType}, ::Context) = "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{:fixed})"
_field_encode_expr(f::FieldType{<:Union{SInt32Type,SInt64Type}}, ::Context) = "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{:zigzag})"
function _field_encode_expr(f::FieldType{<:MapType}, ::Context)
    K = _decoding_val_type(f.type.keytype)
    V = _decoding_val_type(f.type.valuetype)
    isempty(V) && isempty(K) && return "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)))"
    !isempty(V) && isempty(K) && return "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{Tuple{Nothing,$(V)}})"
    isempty(V) && !isempty(K) && return "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{Tuple{$(K),Nothing}})"
    return "PB.encode(e, $(string(f.number)), x.$(jl_fieldname(f)), Val{Tuple{$(K),$(V)}})"
end

function print_field_encode_expr(io, f::FieldType, ctx::Context)
    print(io, "    ")
    _needs_encoding_condition(f, ctx) && print(io, encode_condition(f, ctx), " && ")
    println(io, field_encode_expr(f, ctx))
end

function print_field_encode_expr(io, f::GroupType, ctx::Context)
    println(io, "    !isnothing(x.$(jl_fieldname(f))) && ", field_encode_expr(f, ctx))
end

function print_field_encode_expr(io, fs::OneOfType, ctx::Context)
    println(io, "    if isnothing(x.$(safename(fs)));")
    for f in fs.fields
        V = _decoding_val_type(f.type)
        V = isempty(V) ? "" : ", Val{$V}"
        println(io, "    elseif ", "x.$(safename(fs)).name === :", jl_fieldname(f))
        println(io, "    " ^ 2, "PB.encode(e, $(string(f.number)), x.$(safename(fs))[]::$(jl_typename(f, ctx))$V)")
    end
    println(io, "    end")
end

function generate_encode_method(io, t::MessageType, ctx::Context)
    println(io, "function PB.encode(e::PB.AbstractProtoEncoder, x::$(safename(t)))")
    println(io, "    initpos = position(e.io)")
    for field in t.fields
        print_field_encode_expr(io, field, ctx)
    end
    println(io, "    return position(e.io) - initpos", )
    println(io, "end")
end


function print_field_encoded_size_expr(io, f::FieldType, ctx::Context)
    print(io, "    ")
    is_optional = _needs_encoding_condition(f, ctx)
    is_optional && print(io, encode_condition(f, ctx), " && (")
    print(io, "encoded_size += ", field_encoded_size_expr(f))
    println(io, is_optional ? ")" : "")
end

function print_field_encoded_size_expr(io, f::GroupType, ::Context)
    println(io, "    !isnothing(x.$(jl_fieldname(f))) && (encoded_size += ", field_encoded_size_expr(f), ")")
end

function print_field_encoded_size_expr(io, fs::OneOfType, ctx::Context)
    println(io, "    if isnothing(x.$(safename(fs)));")
    for f in fs.fields
        V = _decoding_val_type(f.type)
        V = isempty(V) ? "" : ", Val{$V}"
        println(io, "    elseif ", "x.$(safename(fs)).name === :", jl_fieldname(f))
        println(io, "    " ^ 2, "encoded_size += PB._encoded_size(x.$(safename(fs))[]::$(jl_typename(f, ctx)), $(string(f.number))$V)")
    end
    println(io, "    end")
end

field_encoded_size_expr(f::FieldType) = "PB._encoded_size(x.$(jl_fieldname(f)::String), $(string(f.number)))"
field_encoded_size_expr(f::GroupType) = "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)))"
field_encoded_size_expr(f::FieldType{<:AbstractProtoFixedType}) = "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)), Val{:fixed})"
field_encoded_size_expr(f::FieldType{<:Union{SInt32Type,SInt64Type}}) = "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)), Val{:zigzag})"
function field_encoded_size_expr(f::FieldType{<:MapType})
    K = _decoding_val_type(f.type.keytype)
    V = _decoding_val_type(f.type.valuetype)
    isempty(V) && isempty(K) && return "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)))"
    !isempty(V) && isempty(K) && return "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)), Val{Tuple{Nothing,$(V)}})"
    isempty(V) && !isempty(K) && return "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)), Val{Tuple{$(K),Nothing}})"
    return "PB._encoded_size(x.$(jl_fieldname(f)), $(string(f.number)), Val{Tuple{$(K),$(V)}})"
end

function generate__encoded_size_method(io, t::MessageType, ctx::Context)
    println(io, "function PB._encoded_size(x::$(safename(t)))")
    println(io, "    encoded_size = 0")
    for field in t.fields
        print_field_encoded_size_expr(io, field, ctx)
    end
    println(io, "    return encoded_size")
    println(io, "end")
end
