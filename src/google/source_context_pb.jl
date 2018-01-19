# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

mutable struct SourceContext
    file_name::AbstractString
    SourceContext(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type SourceContext
hash(v::SourceContext) = ProtoBuf.protohash(v)
isequal(v1::SourceContext, v2::SourceContext) = ProtoBuf.protoisequal(v1, v2)
==(v1::SourceContext, v2::SourceContext) = ProtoBuf.protoeq(v1, v2)

export SourceContext
