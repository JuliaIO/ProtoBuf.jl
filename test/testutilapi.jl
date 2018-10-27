module ProtoBufTestApis
using ProtoBuf
using ..Test
import ProtoBuf.meta

print_hdr(tname) = println("testing $tname...")

mutable struct TestType <: ProtoType
    a::AbstractString
    b::Bool
    TestType() = (o=new(); fillunset(o); o)
end #type TestType
meta(t::Type{TestType}) = meta(t, Symbol[:a], Int[], Dict{Symbol,Any}())

function test_apis()
    t = TestType()

    @test !has_field(t, :a)
    @test !has_field(t, :b)

    @test false == try get_field(t, :a); true; catch; false; end

    t.b = true
    @test has_field(t, :b)
    @test (get_field(t, :b) == true)

    @test !isinitialized(t)
    t.a = "hello world"
    @test isinitialized(t)
    @test (get_field(t, :a) ==  "hello world")

    clear(t, :b)
    @test isinitialized(t)
    clear(t)
    @test !isinitialized(t)

    t = protobuild(TestType, Dict(:a => "hello", :b => false))
    @test t.a == "hello"
    @test t.b == false
end
end # module ProtoBufTestApis

print_hdr("utility api methods")
ProtoBufTestApis.test_apis()

