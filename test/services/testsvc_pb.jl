# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

mutable struct BinaryOpReq <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function BinaryOpReq(; kwargs...)
        obj = new(meta(BinaryOpReq), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end #type BinaryOpReq
function meta(::Type{BinaryOpReq})
    allflds = Pair{Symbol,Union{Type,String}}[:i1 => Int64, :i2 => Int64]
    meta(ProtoMeta(BinaryOpReq), BinaryOpReq, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::BinaryOpReq, name::Symbol)
    if name === :i1
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :i2
        return (obj.__protobuf_jl_internal_values[name])::Int64
    else
        getfield(obj, name)
    end
end

mutable struct BinaryOpResp <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function BinaryOpResp(; kwargs...)
        obj = new(meta(BinaryOpResp), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end #type BinaryOpResp
function meta(::Type{BinaryOpResp})
    allflds = Pair{Symbol,Union{Type,String}}[:result => Int64]
    meta(ProtoMeta(BinaryOpResp), BinaryOpResp, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::BinaryOpResp, name::Symbol)
    if name === :result
        return (obj.__protobuf_jl_internal_values[name])::Int64
    else
        getfield(obj, name)
    end
end

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
