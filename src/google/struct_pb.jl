# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta

struct __enum_NullValue <: ProtoEnum
    NULL_VALUE::Int32
    __enum_NullValue() = new(0)
end #type __enum_NullValue
const NullValue = __enum_NullValue()

mutable struct Struct <: ProtoType
    fields::Dict{AbstractString,Any} # map entry
    Struct(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Struct

mutable struct ListValue <: ProtoType
    values::Array{Any,1}
    ListValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type ListValue

mutable struct Value <: ProtoType
    null_value::Int32
    number_value::Float64
    string_value::AbstractString
    bool_value::Bool
    struct_value::Struct
    list_value::ListValue
    Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Value
const __oneofs_Value = Int[1,1,1,1,1,1]
const __oneof_names_Value = [Symbol("kind")]
meta(t::Type{Value}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, __oneofs_Value, __oneof_names_Value)

function meta(t::Type{ListValue})
    haskey(ProtoBuf._metacache, t) && (return ProtoBuf._metacache[t])
    m = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    m.ordered[1].meta = meta(Value)
    m
end

function meta(t::Type{Struct})
    haskey(ProtoBuf._metacache, t) && (return ProtoBuf._metacache[t])
    m = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    m.ordered[1].meta = ProtoBuf.mapentry_meta(Dict{AbstractString,Value})
    m
end

export NullValue, Struct, Value, ListValue
