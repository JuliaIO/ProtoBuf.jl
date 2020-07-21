# syntax: proto3
mutable struct FieldMask <: ProtoType
    paths::Base.Vector{AbstractString}
    FieldMask(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct FieldMask

export FieldMask
