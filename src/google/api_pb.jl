# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

type Method
    name::AbstractString
    request_type_url::AbstractString
    request_streaming::Bool
    response_type_url::AbstractString
    response_streaming::Bool
    options::Array{Option,1}
    syntax::Int32
    Method(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Method
hash(v::Method) = ProtoBuf.protohash(v)
isequal(v1::Method, v2::Method) = ProtoBuf.protoisequal(v1, v2)
==(v1::Method, v2::Method) = ProtoBuf.protoeq(v1, v2)

type Mixin
    name::AbstractString
    root::AbstractString
    Mixin(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Mixin
hash(v::Mixin) = ProtoBuf.protohash(v)
isequal(v1::Mixin, v2::Mixin) = ProtoBuf.protoisequal(v1, v2)
==(v1::Mixin, v2::Mixin) = ProtoBuf.protoeq(v1, v2)

type Api
    name::AbstractString
    methods::Array{Method,1}
    options::Array{Option,1}
    version::AbstractString
    source_context::SourceContext
    mixins::Array{Mixin,1}
    syntax::Int32
    Api(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Api
hash(v::Api) = ProtoBuf.protohash(v)
isequal(v1::Api, v2::Api) = ProtoBuf.protoisequal(v1, v2)
==(v1::Api, v2::Api) = ProtoBuf.protoeq(v1, v2)

export Api, Method, Mixin
