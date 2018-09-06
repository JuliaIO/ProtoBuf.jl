# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct Empty <: ProtoType
    Empty(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Empty

export Empty
