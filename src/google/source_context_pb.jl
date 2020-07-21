# syntax: proto3
mutable struct SourceContext <: ProtoType
    file_name::AbstractString
    SourceContext(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct SourceContext

export SourceContext
