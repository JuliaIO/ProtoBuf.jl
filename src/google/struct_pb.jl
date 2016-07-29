# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

type __enum_NullValue <: ProtoEnum
    NULL_VALUE::Int32
    __enum_NullValue() = new(0)
end #type __enum_NullValue
const NullValue = __enum_NullValue()

type Struct
    fields::Dict{AbstractString,Any} # map entry
    Struct(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Struct
hash(v::Struct) = ProtoBuf.protohash(v)
isequal(v1::Struct, v2::Struct) = ProtoBuf.protoisequal(v1, v2)
==(v1::Struct, v2::Struct) = ProtoBuf.protoeq(v1, v2)

type ListValue
    values::Array{Any,1}
    ListValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type ListValue
hash(v::ListValue) = ProtoBuf.protohash(v)
isequal(v1::ListValue, v2::ListValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::ListValue, v2::ListValue) = ProtoBuf.protoeq(v1, v2)

type Value
    null_value::Int32
    number_value::Float64
    string_value::AbstractString
    bool_value::Bool
    struct_value::Struct
    list_value::ListValue
    Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Value
const __oneofs_Value = Int[1,1,1,1,1,1]
const __oneof_names_Value = [@compat(Symbol("kind"))]
meta(t::Type{Value}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, __oneofs_Value, __oneof_names_Value)
hash(v::Value) = ProtoBuf.protohash(v)
isequal(v1::Value, v2::Value) = ProtoBuf.protoisequal(v1, v2)
==(v1::Value, v2::Value) = ProtoBuf.protoeq(v1, v2)

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
