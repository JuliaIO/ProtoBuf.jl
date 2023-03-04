abstract type AbstractProtoType end
abstract type AbstractProtoNumericType <: AbstractProtoType end
abstract type AbstractProtoFixedType <: AbstractProtoNumericType end
abstract type AbstractProtoFloatType <: AbstractProtoNumericType end
abstract type AbstractProtoFieldType <: AbstractProtoType end

struct DoubleType   <: AbstractProtoFloatType end
struct FloatType    <: AbstractProtoFloatType end
struct Int32Type    <: AbstractProtoNumericType end
struct Int64Type    <: AbstractProtoNumericType end
struct UInt32Type   <: AbstractProtoNumericType end
struct UInt64Type   <: AbstractProtoNumericType end
struct SInt32Type   <: AbstractProtoNumericType end
struct SInt64Type   <: AbstractProtoNumericType end
struct Fixed32Type  <: AbstractProtoFixedType end
struct Fixed64Type  <: AbstractProtoFixedType end
struct SFixed32Type <: AbstractProtoFixedType end
struct SFixed64Type <: AbstractProtoFixedType end
struct BoolType     <: AbstractProtoNumericType end
struct StringType <: AbstractProtoType end
struct BytesType  <: AbstractProtoType end
struct MapType <: AbstractProtoType
    keytype::AbstractProtoType
    valuetype::AbstractProtoType
end

@enum(TypeOfReference, UNKNOWN, MESSAGE, ENUM, SERVICE, RPC)
# NOTE: mutable so we can figure out the actual type being referenced later
#       when the rest of the file (and other, imported files) are parsed.
mutable struct ReferencedType <: AbstractProtoType
    name::String
    package_namespace::Union{Nothing,String}
    package_import_path::Union{Nothing,String}
    reference_type::TypeOfReference
    resolve_from_innermost::Bool
    resolved::Bool
end

function ReferencedType(name::String)
    if startswith(name, '.')
        return ReferencedType(name[2:end], nothing, nothing, UNKNOWN, false, false)
    else
        return ReferencedType(name, nothing, nothing, UNKNOWN, true, false)
    end
end
struct RPCType <: AbstractProtoType
    name::String
    request_stream::Bool
    request_type::ReferencedType
    response_stream::Bool
    response_type::ReferencedType
    options::Dict{String,Union{String,Dict{String}}}
end

function lowercase_first(s)
    b = IOBuffer()
    i = Iterators.Stateful(s)
    print(b, lowercase(popfirst!(i)))
    for c in i
        print(b, c)
    end
    return String(take!(b))
end

_dot_join(prefix, s) = isempty(prefix) ? s : string(prefix, '.', s)

@enum(FieldLabel, DEFAULT, REQUIRED, OPTIONAL, REPEATED)

# We're reusing the same FieldType for both Message and OneOf fields
# OneOf fields don't use the label field
struct FieldType{T<:AbstractProtoType} <: AbstractProtoFieldType
    label::FieldLabel
    type::AbstractProtoType
    name::String
    number::Int
    options::Dict{String,Union{String,Dict{String}}}
end

struct OneOfType <: AbstractProtoFieldType
    name::String
    fields::Vector{AbstractProtoFieldType}
    options::Dict{String,Union{String,Dict{String}}}
end

struct ExtendType <: AbstractProtoFieldType
    type::ReferencedType
    field_extensions::Vector{AbstractProtoFieldType}
end

struct MessageType <: AbstractProtoType
    name::String
    fields::Vector{AbstractProtoFieldType}
    options::Dict{String,Union{String,Dict{String}}}
    reserved_nums::Vector{Union{Int,UnitRange{Int}}}
    reserved_names::Vector{String}
    extensions::Vector{Union{Int,UnitRange{Int}}}
    extends::Vector{ExtendType}
    has_oneof_field::Bool
end

struct GroupType <: AbstractProtoFieldType
    label::FieldLabel
    name::String
    field_name::String
    type::MessageType
    number::Int
end

struct ServiceType <: AbstractProtoType
    name::String
    rpcs::Vector{RPCType}
    options::Dict{String,Union{String,Dict{String}}}
end

struct EnumType <: AbstractProtoType
    name::String
    element_names::Vector{Symbol}
    element_values::Vector{Int}
    options::Dict{String,Union{String,Dict{String}}}
    reserved_nums::Vector{Union{Int,UnitRange{Int}}}
    reserved_names::Vector{String}
    field_options::Dict{String,Union{String,Dict{String}}}
end

function unsafe_name(ps)
    pk = peekkind(ps)
    if Tokens.isident(pk) || Tokens.is_reserved_word(pk)
        return val(readtoken(ps))
    else
        ps.errored = true
        error("Invalid name token $(peektoken(ps))")
    end
end

function parse_label(ps)
    return accept(ps, Tokens.REPEATED) ? REPEATED :
           accept(ps, Tokens.OPTIONAL) ? OPTIONAL :
           accept(ps, Tokens.REQUIRED) ? REQUIRED :
                                         DEFAULT
end
# Called in parse_oneof_type, parse_message_type and parse_extend_type
# after we handled GROUP, EXTEND, OPTION, RESERVED and EXTENSIONS
function parse_field(ps::ParserState, labelable::Bool=true)
    label = labelable ? parse_label(ps) : Parsers.DEFAULT
    type = parse_type(ps)
    labelable = labelable & !isa(type, MapType)
    name = unsafe_name(ps)
    labelable && ps.is_proto3 && label == REQUIRED && (ps.errored = true) && error("Field `$(name)` has a `required` label which is not supported in proto3 syntax.")
    labelable && !ps.is_proto3 && label == DEFAULT && (ps.errored = true) && error("Field `$(name)` is missing a label (`required`, `optional` or `repeated`), this is not supported in proto2 syntax.")
    expectnext(ps, Tokens.EQ)
    number = parse(Int, val(expectnext(ps, kind -> (kind == Tokens.DEC_INT_LIT || kind == Tokens.HEX_INT_LIT))))
    if !(1 <= number <= MAX_FIELD_NUMBER) || (19000 <= number <= 19999)
        ps.errored = true
        error("Invalid field number $number for field $name")
    end

    options = Dict{String,Union{String,Dict{String}}}()
    if label == REPEATED && type isa AbstractProtoNumericType
        options["packed"] = "true"
    end
    accept(ps, Tokens.LBRACKET) && parse_field_options!(ps, options)
    expectnext(ps, Tokens.SEMICOLON)
    return FieldType{typeof(type)}(label, type, name, number, options)
end

function peek_group(ps)
    nk, nnk = dpeekkind(ps)
    return (nk in (Tokens.OPTIONAL, Tokens.REQUIRED, Tokens.REPEATED) && nnk == Tokens.GROUP) ||
           (nk == Tokens.GROUP && (Tokens.isident(nnk) || Tokens.is_reserved_word(nnk)))
end

# Can appear in parse_message_type, parse_oneof_type and parse_extend_type
function parse_group(ps, definitions=Dict{String,Union{MessageType, EnumType, ServiceType}}(), name_prefix="", labelable::Bool=true)
    ps.is_proto3 && (ps.errored = true) && error("`group` fields are not supported in proto3 syntax.")
    label = parse_label(ps)
    expectnext(ps, Tokens.GROUP)
    name = unsafe_name(ps)
    labelable && !ps.is_proto3 && label == DEFAULT && (ps.errored = true) && error("Group field `$(name)` is missing a label (`required`, `optional` or `repeated`), this is not supported in proto2 syntax.")
    !isuppercase(first(name)) && error("Group fields must start with a capital letter, got $name")
    expectnext(ps, Tokens.EQ)
    number = parse(Int, val(expectnext(ps, Tokens.DEC_INT_LIT)))
    message = _parse_message_body(ps, name, definitions, name_prefix)
    return GroupType(label, message.name, lowercase_first(name), message, number)
end

# We consumed RESERVED
function _parse_reserved_statement!(ps::ParserState, nums, names)
    while true
        if accept(ps, Tokens.DEC_INT_LIT)
            num = parse(Int, val(token(ps)))
            if accept(ps, Tokens.TO)
                if peekkind(ps) == Tokens.DEC_INT_LIT
                    num_end = parse(Int, val(readtoken(ps)))
                elseif accept(ps, Tokens.MAX)
                    num_end = MAX_FIELD_NUMBER
                else
                    ps.errored = true
                    error("Unexpected token in `reserved` statement: $(peektoken(ps))")
                end
                push!(nums, num:num_end)
            else
                push!(nums, num)
            end
        elseif accept(ps, Tokens.STRING_LIT)
            push!(names, val(token(ps))[2:end-1])
        else
            ps.errored = true
            error("Unexpected token in `reserved` statement: $(peektoken(ps))")
        end
        accept(ps, Tokens.COMMA) || break
    end
    expectnext(ps, Tokens.SEMICOLON)
end

# We consumed EXTENSIONS
function _parse_extensions_statement!(ps::ParserState, extensions)
    num = parse(Int, val(expectnext(ps, Tokens.DEC_INT_LIT)))
    if accept(ps, Tokens.TO)
        if peekkind(ps) == Tokens.DEC_INT_LIT
            num_end = parse(Int, val(readtoken(ps)))
        elseif accept(ps, Tokens.MAX)
            num_end = MAX_FIELD_NUMBER
        else
            ps.errored = true
            error("Unexpected token in `extensions` statement: $(peektoken(ps))")
        end
        push!(extensions, num:num_end)
    else
        push!(extensions, num)
    end
    expectnext(ps, Tokens.SEMICOLON)
end

# We consumed MAP
function parse_map_type(ps::ParserState)
    expectnext(ps, Tokens.LESS)
    keytype = parse_type(ps)
    expectnext(ps, Tokens.COMMA)
    valuetype = parse_type(ps)
    expectnext(ps, Tokens.GREATER)
    return MapType(keytype, valuetype)
end

# We consumed ONEOF
function parse_oneof_type(ps::ParserState, definitions, name_prefix="")
    name = unsafe_name(ps)

    fields = AbstractProtoFieldType[]
    options = Dict{String,Union{String,Dict{String}}}()

    expectnext(ps, Tokens.LBRACE)
    while !accept(ps, Tokens.RBRACE)
        nk, nnk = dpeekkind(ps)
        if accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        elseif (nk == Tokens.GROUP && (Tokens.isident(nnk) || Tokens.is_reserved_word(nnk)))
            group = parse_group(ps, definitions, _dot_join(name_prefix, name), false)
            push!(fields, group)
            definitions[group.type.name] = group.type
        else
            push!(fields, parse_field(ps, false))
        end
    end
    accept(ps, Tokens.SEMICOLON)
    return OneOfType(name, fields, options)
end

# We consumed ENUM
function parse_enum_type(ps::ParserState, name_prefix="")
    name = unsafe_name(ps)

    options = Dict{String,Union{String,Dict{String}}}()
    reserved_nums = Vector{Union{Int,UnitRange{Int}}}()
    reserved_names = Vector{String}()
    field_options = Dict{String,Union{String,Dict{String}}}()
    element_names = Symbol[]
    element_values = Int[]

    expectnext(ps, Tokens.LBRACE)
    while true
        if accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.IDENTIFIER)
            element_name = val(token(ps))
            push!(element_names, Symbol(element_name))
            expectnext(ps, Tokens.EQ)
            push!(element_values, parse_integer_value(ps))
            if accept(ps, Tokens.LBRACKET)
                parse_field_options!(ps, get!(field_options, element_name, Dict{String,Union{String,Dict{String}}}()))
            end
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.RESERVED)
            _parse_reserved_statement!(ps, reserved_nums, reserved_names)
        else
            expectnext(ps, Tokens.RBRACE)
            break
        end
    end
    accept(ps, Tokens.SEMICOLON)
    if !parse(Bool, get(options, "allow_alias", "false"))
        !allunique(element_values) && (ps.errored = true) && error("Duplicates in enumeration $name. You can allow multiple keys mapping to the same number with `option allow_alias = true;`")
    end
    if ps.is_proto3 && first(element_values) != 0
        ps.errored = true
        error("In proto3, enums' first element must map to zero, $name has `$(first(element_names)) = $(first(element_values))` as first element.")
    end
    # TODO: validate field_numbers
    return EnumType(_dot_join(name_prefix, name), element_names, element_values, options, reserved_nums, reserved_names, field_options)
end

# We consumed EXTEND
function parse_extend_type(ps::ParserState, definitions, name_prefix="")
    type = parse_type(ps, definitions)
    field_extensions = AbstractProtoFieldType[]

    expectnext(ps, Tokens.LBRACE)
    while !accept(ps, Tokens.RBRACE)
        if peek_group(ps)
            group = parse_group(ps, definitions, name_prefix)
            definitions[group.name] = group.type
        else
            push!(field_extensions, parse_field(ps))
        end
    end
    return ExtendType(type, field_extensions)
end

# We consumed MESSAGE
function parse_message_type(ps::ParserState, definitions=Dict{String,Union{MessageType, EnumType, ServiceType}}(), name_prefix="")
    name = unsafe_name(ps)
    return _parse_message_body(ps, name, definitions, name_prefix)
end

function _parse_message_body(ps::ParserState, name, definitions, name_prefix)
    fields = []
    options = Dict{String,Union{String,Dict{String}}}()
    reserved_nums = Vector{Union{Int,UnitRange{Int}}}()
    reserved_names = Vector{String}()
    extensions = Vector{Union{Int,UnitRange{Int}}}()
    extends = Vector{ExtendType}()
    has_oneof_field = false

    name = _dot_join(name_prefix, name)
    expectnext(ps, Tokens.LBRACE)
    while true
        if accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.RESERVED)
            _parse_reserved_statement!(ps, reserved_nums, reserved_names)
        elseif accept(ps, Tokens.EXTENSIONS)
            _parse_extensions_statement!(ps, extensions)
        elseif accept(ps, Tokens.MESSAGE)
            message = parse_message_type(ps, definitions, name)
            definitions[message.name] = message
        elseif accept(ps, Tokens.ENUM)
            enum = parse_enum_type(ps, name)
            definitions[enum.name] = enum
            # ./test/test_protos/protobuf/echo.proto has a trailing SEMICOLON after nested enum
            accept(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.ONEOF)
            push!(fields, parse_oneof_type(ps, definitions, name))
            has_oneof_field = true
        elseif accept(ps, Tokens.EXTEND)
            push!(extends, parse_extend_type(ps, definitions, name))
        elseif peek_group(ps)
            group = parse_group(ps, definitions, name)
            push!(fields, group)
            definitions[group.type.name] = group.type
        elseif accept(ps, Tokens.RBRACE)
            accept(ps, Tokens.SEMICOLON)
            break
        else
            push!(fields, parse_field(ps))
        end
    end
    # TODO: validate field_numbers vs reserved and extensions
    return MessageType(name, fields, options, reserved_nums, reserved_names, extensions, extends, has_oneof_field)
end

# We consumed RPC
function parse_rpc_type(ps::ParserState)
    name = unsafe_name(ps)
    options = Dict{String,Union{String,Dict{String}}}()

    expectnext(ps, Tokens.LPAREN)
    request_stream = accept(ps, Tokens.STREAM)
    request_type = parse_type(ps)
    expectnext(ps, Tokens.RPAREN)
    expectnext(ps, Tokens.RETURNS)
    expectnext(ps, Tokens.LPAREN)
    response_stream = accept(ps, Tokens.STREAM)
    response_type = parse_type(ps)
    expectnext(ps, Tokens.RPAREN)
    if accept(ps, Tokens.LBRACE)
        while accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        end
        expectnext(ps, Tokens.RBRACE)
        accept(ps, Tokens.SEMICOLON)
    else
        # ./test/test_protos/protobuf/factory_test1.proto end an RPC without a SEMICOLON
        expectnext(ps, Tokens.SEMICOLON)
    end
    return RPCType(name, request_stream, request_type, response_stream, response_type, options)
end

# We consumed SERVICE
function parse_service_type(ps::ParserState)
    name = unsafe_name(ps)
    rpcs = RPCType[]
    options = Dict{String,Union{String,Dict{String}}}()

    expectnext(ps, Tokens.LBRACE)
    while !accept(ps, Tokens.RBRACE)
        if accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.RPC)
            push!(rpcs, parse_rpc_type(ps))
        else
            ps.errored = true
            error("Unexpected token while parsing service definition: $(peektoken(ps))")
        end
    end

    return ServiceType(name, rpcs, options)
end

function parse_type(ps::ParserState)
    nk = peekkind(ps)
    if nk == Tokens.ENUM
        readtoken(ps)
        return parse_enum_type(ps)
    elseif nk == Tokens.SERVICE
        readtoken(ps)
        return parse_service_type(ps)
    elseif nk == Tokens.MAP
        readtoken(ps)
        return parse_map_type(ps)
    elseif nk == Tokens.RPC
        readtoken(ps)
        return parse_rpc_type(ps)
    elseif nk == Tokens.IDENTIFIER
        return ReferencedType(val(readtoken(ps)))
    elseif nk == Tokens.DOUBLE   readtoken(ps); return DoubleType()
    elseif nk == Tokens.FLOAT    readtoken(ps); return FloatType()
    elseif nk == Tokens.INT32    readtoken(ps); return Int32Type()
    elseif nk == Tokens.INT64    readtoken(ps); return Int64Type()
    elseif nk == Tokens.UINT32   readtoken(ps); return UInt32Type()
    elseif nk == Tokens.UINT64   readtoken(ps); return UInt64Type()
    elseif nk == Tokens.SINT32   readtoken(ps); return SInt32Type()
    elseif nk == Tokens.SINT64   readtoken(ps); return SInt64Type()
    elseif nk == Tokens.FIXED32  readtoken(ps); return Fixed32Type()
    elseif nk == Tokens.FIXED64  readtoken(ps); return Fixed64Type()
    elseif nk == Tokens.SFIXED32 readtoken(ps); return SFixed32Type()
    elseif nk == Tokens.SFIXED64 readtoken(ps); return SFixed64Type()
    elseif nk == Tokens.BOOL     readtoken(ps); return BoolType()
    elseif nk == Tokens.STRING   readtoken(ps); return StringType()
    elseif nk == Tokens.BYTES    readtoken(ps); return BytesType()
    else
        ps.errored = true
        error("Unsupported type token $(peektoken(ps)) ($(nk))")
    end
end

function parse_type(ps::ParserState, definitions::Dict{String,Union{MessageType, EnumType, ServiceType}})
    nk = peekkind(ps)
    if nk == Tokens.MESSAGE
        readtoken(ps)
        return parse_message_type(ps, definitions)
    elseif nk == Tokens.ONEOF
        readtoken(ps)
        return parse_oneof_type(ps, definitions)
    elseif nk == Tokens.EXTEND
        readtoken(ps)
        return parse_extend_type(ps, definitions)
    else
        return parse_type(ps)
    end
end

