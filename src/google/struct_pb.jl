# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

struct __enum_NullValue <: ProtoEnum
    NULL_VALUE::Int32
    __enum_NullValue() = new(0)
end #struct __enum_NullValue
const NullValue = __enum_NullValue()

mutable struct Struct_FieldsEntry <: ProtoType
    key::AbstractString
    value::Base.Any
    Struct_FieldsEntry(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Struct_FieldsEntry (mapentry) (has cyclic type dependency)
const __ftype_Struct_FieldsEntry = Dict(:value => "Value")
meta(t::Type{Struct_FieldsEntry}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, __ftype_Struct_FieldsEntry)

mutable struct Struct <: ProtoType
    fields::Base.Dict # map entry
    Struct(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Struct (has cyclic type dependency)
const __ftype_Struct = Dict(:fields => "Base.Dict{AbstractString,Value}")
meta(t::Type{Struct}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, __ftype_Struct)

mutable struct Value <: ProtoType
    null_value::Int32
    number_value::Float64
    string_value::AbstractString
    bool_value::Bool
    struct_value::Struct
    list_value::Base.Any
    Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Value (has cyclic type dependency)
const __ftype_Value = Dict(:list_value => "ListValue")
const __oneofs_Value = Int[1,1,1,1,1,1]
const __oneof_names_Value = [Symbol("kind")]
meta(t::Type{Value}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, __oneofs_Value, __oneof_names_Value, __ftype_Value)

mutable struct ListValue <: ProtoType
    values::Base.Vector{Value}
    ListValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct ListValue (has cyclic type dependency)

export NullValue, Struct_FieldsEntry, Struct, Value, ListValue, Struct_FieldsEntry, Struct, Value, ListValue
# mapentries: "Struct_FieldsEntry"=>("AbstractString", "Value")
