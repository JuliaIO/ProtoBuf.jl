# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

struct __enum_Syntax <: ProtoEnum
    SYNTAX_PROTO2::Int32
    SYNTAX_PROTO3::Int32
    __enum_Syntax() = new(0,1)
end #type __enum_Syntax
const Syntax = __enum_Syntax()

mutable struct Option <: ProtoType
    name::AbstractString
    value::_Any
    Option(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Option
hash(v::Option) = ProtoBuf.protohash(v)
isequal(v1::Option, v2::Option) = ProtoBuf.protoisequal(v1, v2)
==(v1::Option, v2::Option) = ProtoBuf.protoeq(v1, v2)

mutable struct EnumValue <: ProtoType
    name::AbstractString
    number::Int32
    options::Array{Option,1}
    EnumValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type EnumValue
hash(v::EnumValue) = ProtoBuf.protohash(v)
isequal(v1::EnumValue, v2::EnumValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::EnumValue, v2::EnumValue) = ProtoBuf.protoeq(v1, v2)

struct __enum_Field_Kind <: ProtoEnum
    TYPE_UNKNOWN::Int32
    TYPE_DOUBLE::Int32
    TYPE_FLOAT::Int32
    TYPE_INT64::Int32
    TYPE_UINT64::Int32
    TYPE_INT32::Int32
    TYPE_FIXED64::Int32
    TYPE_FIXED32::Int32
    TYPE_BOOL::Int32
    TYPE_STRING::Int32
    TYPE_GROUP::Int32
    TYPE_MESSAGE::Int32
    TYPE_BYTES::Int32
    TYPE_UINT32::Int32
    TYPE_ENUM::Int32
    TYPE_SFIXED32::Int32
    TYPE_SFIXED64::Int32
    TYPE_SINT32::Int32
    TYPE_SINT64::Int32
    __enum_Field_Kind() = new(0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18)
end #type __enum_Field_Kind
const Field_Kind = __enum_Field_Kind()

struct __enum_Field_Cardinality <: ProtoEnum
    CARDINALITY_UNKNOWN::Int32
    CARDINALITY_OPTIONAL::Int32
    CARDINALITY_REQUIRED::Int32
    CARDINALITY_REPEATED::Int32
    __enum_Field_Cardinality() = new(0,1,2,3)
end #type __enum_Field_Cardinality
const Field_Cardinality = __enum_Field_Cardinality()

mutable struct Field <: ProtoType
    kind::Int32
    cardinality::Int32
    number::Int32
    name::AbstractString
    type_url::AbstractString
    oneof_index::Int32
    packed::Bool
    options::Array{Option,1}
    json_name::AbstractString
    default_value::AbstractString
    Field(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Field
const __fnum_Field = Int[1,2,3,4,6,7,8,9,10,11]
meta(t::Type{Field}) = meta(t, ProtoBuf.DEF_REQ, __fnum_Field, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
hash(v::Field) = ProtoBuf.protohash(v)
isequal(v1::Field, v2::Field) = ProtoBuf.protoisequal(v1, v2)
==(v1::Field, v2::Field) = ProtoBuf.protoeq(v1, v2)

mutable struct _Enum <: ProtoType
    name::AbstractString
    enumvalue::Array{EnumValue,1}
    options::Array{Option,1}
    source_context::SourceContext
    syntax::Int32
    _Enum(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type _Enum
hash(v::_Enum) = ProtoBuf.protohash(v)
isequal(v1::_Enum, v2::_Enum) = ProtoBuf.protoisequal(v1, v2)
==(v1::_Enum, v2::_Enum) = ProtoBuf.protoeq(v1, v2)

mutable struct _Type <: ProtoType
    name::AbstractString
    fields::Array{Field,1}
    oneofs::Array{AbstractString,1}
    options::Array{Option,1}
    source_context::SourceContext
    syntax::Int32
    _Type(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type _Type
hash(v::_Type) = ProtoBuf.protohash(v)
isequal(v1::_Type, v2::_Type) = ProtoBuf.protoisequal(v1, v2)
==(v1::_Type, v2::_Type) = ProtoBuf.protoeq(v1, v2)

export Syntax, _Type, Field_Kind, Field_Cardinality, Field, _Enum, EnumValue, Option
