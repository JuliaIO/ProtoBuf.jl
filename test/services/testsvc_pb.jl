# syntax: proto3
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==

mutable struct BinaryOpReq <: ProtoType
    i1::Int64
    i2::Int64
    BinaryOpReq(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type BinaryOpReq
hash(v::BinaryOpReq) = ProtoBuf.protohash(v)
isequal(v1::BinaryOpReq, v2::BinaryOpReq) = ProtoBuf.protoisequal(v1, v2)
==(v1::BinaryOpReq, v2::BinaryOpReq) = ProtoBuf.protoeq(v1, v2)

mutable struct BinaryOpResp <: ProtoType
    result::Int64
    BinaryOpResp(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type BinaryOpResp
hash(v::BinaryOpResp) = ProtoBuf.protohash(v)
isequal(v1::BinaryOpResp, v2::BinaryOpResp) = ProtoBuf.protoisequal(v1, v2)
==(v1::BinaryOpResp, v2::BinaryOpResp) = ProtoBuf.protoeq(v1, v2)

# service methods for TestMath
const _TestMath_methods = MethodDescriptor[
        MethodDescriptor("Mul", 1, BinaryOpReq, BinaryOpResp),
        MethodDescriptor("Add", 2, BinaryOpReq, BinaryOpResp)
    ] # const _TestMath_methods
const _TestMath_desc = ServiceDescriptor("TestMath", 1, _TestMath_methods)

TestMath(impl::Module) = ProtoService(_TestMath_desc, impl)

mutable struct TestMathStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    TestMathStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_TestMath_desc, channel))
end # type TestMathStub

mutable struct TestMathBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    TestMathBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_TestMath_desc, channel))
end # type TestMathBlockingStub

Mul(stub::TestMathStub, controller::ProtoRpcController, inp::BinaryOpReq, done::Function) = call_method(stub.impl, _TestMath_methods[1], controller, inp, done)
Mul(stub::TestMathBlockingStub, controller::ProtoRpcController, inp::BinaryOpReq) = call_method(stub.impl, _TestMath_methods[1], controller, inp)

Add(stub::TestMathStub, controller::ProtoRpcController, inp::BinaryOpReq, done::Function) = call_method(stub.impl, _TestMath_methods[2], controller, inp, done)
Add(stub::TestMathBlockingStub, controller::ProtoRpcController, inp::BinaryOpReq) = call_method(stub.impl, _TestMath_methods[2], controller, inp)

export BinaryOpReq, BinaryOpResp, TestMath, TestMathStub, TestMathBlockingStub, Mul, Add
