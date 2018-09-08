# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct DoubleValue <: ProtoType
    value::Float64
    DoubleValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct DoubleValue

mutable struct FloatValue <: ProtoType
    value::Float32
    FloatValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct FloatValue

mutable struct Int64Value <: ProtoType
    value::Int64
    Int64Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Int64Value

mutable struct UInt64Value <: ProtoType
    value::UInt64
    UInt64Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct UInt64Value

mutable struct Int32Value <: ProtoType
    value::Int32
    Int32Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Int32Value

mutable struct UInt32Value <: ProtoType
    value::UInt32
    UInt32Value(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct UInt32Value

mutable struct BoolValue <: ProtoType
    value::Bool
    BoolValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct BoolValue

mutable struct StringValue <: ProtoType
    value::AbstractString
    StringValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct StringValue

mutable struct BytesValue <: ProtoType
    value::Array{UInt8,1}
    BytesValue(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct BytesValue

export DoubleValue, FloatValue, Int64Value, UInt64Value, Int32Value, UInt32Value, BoolValue, StringValue, BytesValue
