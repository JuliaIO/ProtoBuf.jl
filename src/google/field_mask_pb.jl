# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

type FieldMask
    paths::Array{AbstractString,1}
    FieldMask(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FieldMask
hash(v::FieldMask) = ProtoBuf.protohash(v)
isequal(v1::FieldMask, v2::FieldMask) = ProtoBuf.protoisequal(v1, v2)
==(v1::FieldMask, v2::FieldMask) = ProtoBuf.protoeq(v1, v2)

export FieldMask
