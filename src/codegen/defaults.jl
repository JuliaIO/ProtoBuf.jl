function jl_default_value(field::FieldType, ctx)
    if _is_repeated_field(field)
        return "PB.BufferedVector{$(jl_typename(field.type, ctx))}()"
    else
        return jl_type_default(field, ctx)
    end
end
jl_type_default(f::FieldType{StringType}, ctx) = get(f.options, "default", "\"\"")
jl_type_default(f::FieldType{BoolType}, ctx)   = get(f.options, "default", "false")
function jl_type_default(f::FieldType{<:AbstractProtoFloatType}, ctx)
    type_name = jl_typename(f, ctx)
    default = get(f.options, "default", nothing)
    if default === nothing
        return "zero($(jl_typename(f.type, ctx)))"
    end
    ldefault = lowercase(default)
    if ldefault == "inf"
        default = "Inf"
    elseif ldefault == "-inf"
        default = "-Inf"
    elseif ldefault == "nan"
        default = "NaN"
    elseif ldefault == "-nan"
        default = "-NaN"
    elseif ldefault == "+inf"
        default = "+Inf"
    elseif ldefault == "+nan"
        default = "+NaN"
    end
    return string(type_name, '(', default, ')')
end
_jl_parse_default_int(::Union{Int32Type,SInt32Type,SFixed32Type}, s::String) = parse(Int32, s)
_jl_parse_default_int(::Union{Int64Type,SInt64Type,SFixed64Type}, s::String) = parse(Int64, s)
_jl_parse_default_int(::Union{UInt32Type,Fixed32Type}, s::String) = parse(UInt32, s)
_jl_parse_default_int(::Union{UInt64Type,Fixed64Type}, s::String) = parse(UInt64, s)
function jl_type_default(f::FieldType{<:AbstractProtoNumericType}, ctx)
    type_name = jl_typename(f, ctx)
    default = get(f.options, "default", nothing)
    if default === nothing
        return "zero($(jl_typename(f.type, ctx)))"
    end
    return string(type_name, '(', repr(_jl_parse_default_int(f.type, default)), ')')
end
function jl_type_default(f::FieldType{BytesType}, ctx)
    out = get(f.options, "default", nothing)
    return isnothing(out) ? "UInt8[]" : "b$(out)"
end
function jl_type_default(f::FieldType{ReferencedType}, ctx)
    if _is_enum(f.type, ctx)
        default = get(f.options, "default", "0")
        if default == "0"
            return "$(jl_typename(f.type, ctx))(0)"
        else
            return "$(jl_typename(f.type, ctx)[1:end-2]).$(default)"
        end
    else # message, AFAIK services shouldn't be referenced
        return "Ref{$(jl_typename(f.type, ctx))}()"
    end
end
# end
function jl_type_default(f::FieldType{MapType}, ctx)
    return "Dict{$(jl_typename(f.type.keytype, ctx)),$(jl_typename(f.type.valuetype, ctx))}()"
end
function jl_default_value(::OneOfType, ctx)
    return "nothing"
end
function jl_default_value(f::GroupType, ctx)
    if _is_repeated_field(f)
        return "PB.BufferedVector{$(jl_typename(f.type, ctx))}()"
    else
        return "Ref{$(jl_typename(f.type, ctx))}()"
    end
end