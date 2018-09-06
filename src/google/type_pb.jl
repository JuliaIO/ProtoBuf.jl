# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

struct __enum_Syntax <: ProtoEnum
    SYNTAX_PROTO2::Int32
    SYNTAX_PROTO3::Int32
    __enum_Syntax() = new(0,1)
end #struct __enum_Syntax
const Syntax = __enum_Syntax()

mutable struct Option <: ProtoType
    name::AbstractString
    value::_Any
    Option(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Option

mutable struct EnumValue <: ProtoType
    name::AbstractString
    number::Int32
    options::Base.Vector{Option}
    EnumValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct EnumValue

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
end #struct __enum_Field_Kind
const Field_Kind = __enum_Field_Kind()

struct __enum_Field_Cardinality <: ProtoEnum
    CARDINALITY_UNKNOWN::Int32
    CARDINALITY_OPTIONAL::Int32
    CARDINALITY_REQUIRED::Int32
    CARDINALITY_REPEATED::Int32
    __enum_Field_Cardinality() = new(0,1,2,3)
end #struct __enum_Field_Cardinality
const Field_Cardinality = __enum_Field_Cardinality()

mutable struct Field <: ProtoType
    kind::Int32
    cardinality::Int32
    number::Int32
    name::AbstractString
    type_url::AbstractString
    oneof_index::Int32
    packed::Bool
    options::Base.Vector{Option}
    json_name::AbstractString
    default_value::AbstractString
    Field(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Field
const __fnum_Field = Int[1,2,3,4,6,7,8,9,10,11]
meta(t::Type{Field}) = meta(t, ProtoBuf.DEF_REQ, __fnum_Field, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, ProtoBuf.DEF_FIELD_TYPES)

mutable struct _Enum <: ProtoType
    name::AbstractString
    enumvalue::Base.Vector{EnumValue}
    options::Base.Vector{Option}
    source_context::SourceContext
    syntax::Int32
    _Enum(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct _Enum

mutable struct _Type <: ProtoType
    name::AbstractString
    fields::Base.Vector{Field}
    oneofs::Base.Vector{AbstractString}
    options::Base.Vector{Option}
    source_context::SourceContext
    syntax::Int32
    _Type(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct _Type

export Syntax, _Type, Field_Kind, Field_Cardinality, Field, _Enum, EnumValue, Option
