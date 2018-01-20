# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

mutable struct Timestamp
    seconds::Int64
    nanos::Int32
    Timestamp(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type Timestamp
hash(v::Timestamp) = ProtoBuf.protohash(v)
isequal(v1::Timestamp, v2::Timestamp) = ProtoBuf.protoisequal(v1, v2)
==(v1::Timestamp, v2::Timestamp) = ProtoBuf.protoeq(v1, v2)

export Timestamp
