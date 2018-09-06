# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct Method <: ProtoType
    name::AbstractString
    request_type_url::AbstractString
    request_streaming::Bool
    response_type_url::AbstractString
    response_streaming::Bool
    options::Base.Vector{Option}
    syntax::Int32
    Method(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Method

mutable struct Mixin <: ProtoType
    name::AbstractString
    root::AbstractString
    Mixin(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Mixin

mutable struct Api <: ProtoType
    name::AbstractString
    methods::Base.Vector{Method}
    options::Base.Vector{Option}
    version::AbstractString
    source_context::SourceContext
    mixins::Base.Vector{Mixin}
    syntax::Int32
    Api(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Api

export Api, Method, Mixin
