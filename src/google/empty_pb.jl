# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

mutable struct Empty
    Empty(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Empty
hash(v::Empty) = ProtoBuf.protohash(v)
isequal(v1::Empty, v2::Empty) = ProtoBuf.protoisequal(v1, v2)
==(v1::Empty, v2::Empty) = ProtoBuf.protoeq(v1, v2)

export Empty
