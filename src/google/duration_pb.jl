# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

mutable struct Duration
    seconds::Int64
    nanos::Int32
    Duration(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Duration
hash(v::Duration) = ProtoBuf.protohash(v)
isequal(v1::Duration, v2::Duration) = ProtoBuf.protoisequal(v1, v2)
==(v1::Duration, v2::Duration) = ProtoBuf.protoeq(v1, v2)

export Duration
