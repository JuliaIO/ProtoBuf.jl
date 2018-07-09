# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta

mutable struct SourceContext <: ProtoType
    file_name::AbstractString
    SourceContext(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type SourceContext

export SourceContext
