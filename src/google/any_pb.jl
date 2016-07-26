# syntax: proto3
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

type _Any
    type_url::AbstractString
    value::Array{UInt8,1}
    _Any(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type _Any
hash(v::_Any) = ProtoBuf.protohash(v)
isequal(v1::_Any, v2::_Any) = ProtoBuf.protoisequal(v1, v2)
==(v1::_Any, v2::_Any) = ProtoBuf.protoeq(v1, v2)

export _Any
