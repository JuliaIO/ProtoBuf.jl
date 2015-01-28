using ProtoBuf
import ProtoBuf.meta

type BinaryOpReq
    i1::Int64
    i2::Int64
    BinaryOpReq() = (o=new(); fillunset(o); o)
end #type BinaryOpReq
const __req_BinaryOpReq = Symbol[:i1,:i2]
meta(t::Type{BinaryOpReq}) = meta(t, __req_BinaryOpReq, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES)

type BinaryOpResp
    result::Int64
    BinaryOpResp() = (o=new(); fillunset(o); o)
end #type BinaryOpResp
const __req_BinaryOpResp = Symbol[:result]
meta(t::Type{BinaryOpResp}) = meta(t, __req_BinaryOpResp, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES)

# service methods for TestMath
const _TestMath_methods = MethodDescriptor[
        MethodDescriptor("Mul", 1, BinaryOpReq, BinaryOpResp),
        MethodDescriptor("Add", 2, BinaryOpReq, BinaryOpResp)
    ] # const _TestMath_methods
const _TestMath_desc = ServiceDescriptor("TestMath", 1, _TestMath_methods)

TestMath(impl::Module) = ProtoService(_TestMath_desc, impl)

type TestMathStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    TestMathStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_TestMath_desc, channel))
end # type TestMathStub

type TestMathBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    TestMathBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_TestMath_desc, channel))
end # type TestMathBlockingStub

Mul(stub::TestMathStub, controller::ProtoRpcController, inp::BinaryOpReq, done::Function) = call_method(stub.impl, _TestMath_methods[1], controller, inp, done)
Mul(stub::TestMathBlockingStub, controller::ProtoRpcController, inp::BinaryOpReq) = call_method(stub.impl, _TestMath_methods[1], controller, inp)

Add(stub::TestMathStub, controller::ProtoRpcController, inp::BinaryOpReq, done::Function) = call_method(stub.impl, _TestMath_methods[2], controller, inp, done)
Add(stub::TestMathBlockingStub, controller::ProtoRpcController, inp::BinaryOpReq) = call_method(stub.impl, _TestMath_methods[2], controller, inp)

export BinaryOpReq, BinaryOpResp, TestMath, TestMathStub, TestMathBlockingStub, Mul, Add
