# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta

mutable struct Method <: ProtoType
    name::AbstractString
    request_type_url::AbstractString
    request_streaming::Bool
    response_type_url::AbstractString
    response_streaming::Bool
    options::Array{Option,1}
    syntax::Int32
    Method(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Method

mutable struct Mixin <: ProtoType
    name::AbstractString
    root::AbstractString
    Mixin(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Mixin

mutable struct Api <: ProtoType
    name::AbstractString
    methods::Array{Method,1}
    options::Array{Option,1}
    version::AbstractString
    source_context::SourceContext
    mixins::Array{Mixin,1}
    syntax::Int32
    Api(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Api

export Api, Method, Mixin
