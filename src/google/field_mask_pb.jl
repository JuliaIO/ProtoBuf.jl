# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta

mutable struct FieldMask <: ProtoType
    paths::Array{AbstractString,1}
    FieldMask(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FieldMask

export FieldMask
