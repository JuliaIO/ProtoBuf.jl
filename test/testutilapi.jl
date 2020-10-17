module ProtoBufTestApis
using ProtoBuf
using ..Test
import ProtoBuf.meta

print_hdr(tname) = println("testing $tname...")

mutable struct TestType <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function TestType(; kwargs...)
        obj = new(meta(TestType), Dict{Symbol,Any}())
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
end #type TestType
const __meta_TestType = Ref{ProtoMeta}()
function meta(::Type{TestType})
    if !isassigned(__meta_TestType)
        __meta_TestType[] = target = ProtoMeta(TestType)
        allflds = Pair{Symbol,Union{Type,String}}[:a => AbstractString, :b => Bool]
        meta(target, TestType, allflds, [:a], ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_TestType[]
end
function Base.getproperty(obj::TestType, name::Symbol)
    if name === :a
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :b
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end

function test_apis()
    t = TestType()

    @test [:a, :b] == propertynames(t)
    @test !hasproperty(t, :a)
    @test !hasproperty(t, :b)

    @test_throws KeyError getproperty(t, :a)

    t.b = true
    @test hasproperty(t, :b)
    @test (getproperty(t, :b) == true)

    @test !isinitialized(t)
    t.a = "hello world"
    @test isinitialized(t)
    @test (t.a ==  "hello world")

    clear(t, :b)
    @test isinitialized(t)
    clear(t)
    @test !isinitialized(t)

    t = TestType(; a="hello", b=false)
    @test t.a == "hello"
    @test t.b == false
end

function test_deepcopy()
    ts = ProtoBuf.google.protobuf.Timestamp()
    ts.seconds = 123
    @test !hasproperty(ts, :nanos)
    ts2 = deepcopy(ts)
    @test !hasproperty(ts2, :nanos)
    @test hasproperty(ts2, :seconds)
end

end # module ProtoBufTestApis

print_hdr("utility api methods")
ProtoBufTestApis.test_apis()
ProtoBufTestApis.test_deepcopy()
