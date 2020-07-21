# syntax: proto3
mutable struct Duration <: ProtoType
    seconds::Int64
    nanos::Int32
    Duration(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Duration

export Duration
