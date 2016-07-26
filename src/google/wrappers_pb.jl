# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

type DoubleValue
    value::Float64
    DoubleValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type DoubleValue
hash(v::DoubleValue) = ProtoBuf.protohash(v)
isequal(v1::DoubleValue, v2::DoubleValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::DoubleValue, v2::DoubleValue) = ProtoBuf.protoeq(v1, v2)

type FloatValue
    value::Float32
    FloatValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FloatValue
hash(v::FloatValue) = ProtoBuf.protohash(v)
isequal(v1::FloatValue, v2::FloatValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::FloatValue, v2::FloatValue) = ProtoBuf.protoeq(v1, v2)

type Int64Value
    value::Int64
    Int64Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Int64Value
hash(v::Int64Value) = ProtoBuf.protohash(v)
isequal(v1::Int64Value, v2::Int64Value) = ProtoBuf.protoisequal(v1, v2)
==(v1::Int64Value, v2::Int64Value) = ProtoBuf.protoeq(v1, v2)

type UInt64Value
    value::UInt64
    UInt64Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type UInt64Value
hash(v::UInt64Value) = ProtoBuf.protohash(v)
isequal(v1::UInt64Value, v2::UInt64Value) = ProtoBuf.protoisequal(v1, v2)
==(v1::UInt64Value, v2::UInt64Value) = ProtoBuf.protoeq(v1, v2)

type Int32Value
    value::Int32
    Int32Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Int32Value
hash(v::Int32Value) = ProtoBuf.protohash(v)
isequal(v1::Int32Value, v2::Int32Value) = ProtoBuf.protoisequal(v1, v2)
==(v1::Int32Value, v2::Int32Value) = ProtoBuf.protoeq(v1, v2)

type UInt32Value
    value::UInt32
    UInt32Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type UInt32Value
hash(v::UInt32Value) = ProtoBuf.protohash(v)
isequal(v1::UInt32Value, v2::UInt32Value) = ProtoBuf.protoisequal(v1, v2)
==(v1::UInt32Value, v2::UInt32Value) = ProtoBuf.protoeq(v1, v2)

type BoolValue
    value::Bool
    BoolValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type BoolValue
hash(v::BoolValue) = ProtoBuf.protohash(v)
isequal(v1::BoolValue, v2::BoolValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::BoolValue, v2::BoolValue) = ProtoBuf.protoeq(v1, v2)

type StringValue
    value::AbstractString
    StringValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type StringValue
hash(v::StringValue) = ProtoBuf.protohash(v)
isequal(v1::StringValue, v2::StringValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::StringValue, v2::StringValue) = ProtoBuf.protoeq(v1, v2)

type BytesValue
    value::Array{UInt8,1}
    BytesValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type BytesValue
hash(v::BytesValue) = ProtoBuf.protohash(v)
isequal(v1::BytesValue, v2::BytesValue) = ProtoBuf.protoisequal(v1, v2)
==(v1::BytesValue, v2::BytesValue) = ProtoBuf.protoeq(v1, v2)

export DoubleValue, FloatValue, Int64Value, UInt64Value, Int32Value, UInt32Value, BoolValue, StringValue, BytesValue
