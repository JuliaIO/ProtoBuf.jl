function jl_init_value(@nospecialize(field::FieldType), ctx::Context)
    if _is_repeated_field(field)
        return "PB.BufferedVector{$(jl_typename(field.type, ctx))}()"
    else
        return jl_type_init_value(field, ctx::Context)
    end
end

function jl_default_value(@nospecialize(field::FieldType), ctx::Context)
    if _is_repeated_field(field)
        return "Vector{$(jl_typename(field.type, ctx))}()"
    else
        return jl_type_default_value(field, ctx)
    end
end

function _is_optional_referenced_message(field::Union{FieldType{ReferencedType},GroupType}, ctx::Context)
    struct_name = ctx._toplevel_raw_name[]
    (field.type.name == struct_name || field.type.name in ctx._remaining_cyclic_defs) && return true
    if field.label == Parsers.OPTIONAL || field.label == Parsers.DEFAULT
        return !_should_force_required(string(struct_name, ".", jl_fieldname(field)), ctx)
    end
    return false
end

_needs_encoding_condition(field::Union{FieldType{ReferencedType},GroupType}, ctx::Context) = field.label === Parsers.REPEATED || _is_optional_referenced_message(field, ctx)
_needs_encoding_condition(field::FieldType, _::Context) = field.label !== Parsers.REQUIRED

jl_type_default_value(f::FieldType{StringType}, ::Context) = get(f.options, "default", "\"\"")
jl_type_default_value(f::FieldType{BoolType}, ::Context)   = get(f.options, "default", "false")
function jl_type_default_value(@nospecialize(f::FieldType{<:AbstractProtoFloatType}), ctx::Context)
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
function jl_type_default_value(@nospecialize(f::FieldType{<:AbstractProtoNumericType}), ctx::Context)
    type_name = jl_typename(f, ctx)
    default = get(f.options, "default", nothing)
    if default === nothing
        return "zero($(jl_typename(f.type, ctx)))"
    end
    return string(type_name, '(', repr(_jl_parse_default_int(f.type, default)), ')')
end
function jl_type_default_value(f::FieldType{BytesType}, ::Context)
    out = get(f.options, "default", nothing)
    return isnothing(out) ? "UInt8[]" : "b$(out)"
end
function jl_type_default_value(f::FieldType{MapType}, ctx::Context)
    return "Dict{$(jl_typename(f.type.keytype, ctx)),$(jl_typename(f.type.valuetype, ctx))}()"
end

function jl_type_init_value(f::FieldType{ReferencedType}, ctx::Context)
    if _is_enum(f.type, ctx)
        default = get(f.options, "default") do
            definition = _get_referenced_type(f.type, ctx)::EnumType
            string(first(definition.element_names))
        end
        return "$(jl_typename(f.type, ctx)[1:end-2]).$(default)"
    else # message
        if _is_optional_referenced_message(f, ctx)
            return "Ref{Union{Nothing,$(jl_typename(f.type, ctx))}}(nothing)"
        end
        return "Ref{$(jl_typename(f.type, ctx))}()"
    end
end

jl_init_value(::OneOfType, ctx::Context) = "nothing"
jl_default_value(::OneOfType, ctx::Context) = "nothing"

function jl_init_value(f::GroupType, ctx::Context)
    if _is_repeated_field(f)
        return "PB.BufferedVector{$(jl_typename(f.type, ctx))}()"
    else
        if _is_optional_referenced_message(f, ctx)
            return "Ref{Union{Nothing,$(jl_typename(f.type, ctx))}}(nothing)"
        end
        return "Ref{$(jl_typename(f.type, ctx))}()"
    end
end

jl_type_init_value(@nospecialize(field), ctx::Context) = jl_type_default_value(field, ctx)

function jl_type_default_value(f::FieldType{ReferencedType}, ctx::Context)
    if _is_enum(f.type, ctx)
        default = get(f.options, "default") do
            definition = _get_referenced_type(f.type, ctx)::EnumType
            string(first(definition.element_names))
        end
        return "$(jl_typename(f.type, ctx)[1:end-2]).$(default)"
    else # message
        if _is_optional_referenced_message(f, ctx)
            return "nothing"
        end
        return nothing
    end
end

function jl_default_value(f::GroupType, ctx::Context)
    if _is_repeated_field(f)
        return "Vector{$(jl_typename(f.type, ctx))}()"
    else
        if _is_optional_referenced_message(f, ctx)
            return "nothing"
        end
        return nothing
    end
end
