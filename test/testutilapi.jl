module ProtoBufTestApis
using ProtoBuf
import ProtoBuf.meta

if isless(Base.VERSION, v"0.4.0-")
typealias AbstractString String
end

type TestType
    a::AbstractString
    b::Bool
    TestType() = (o=new(); fillunset(o); o)
end #type TestType
meta(t::Type{TestType}) = meta(t, Symbol[:a], Int[], Dict{Symbol,Any}())

function test_apis()
    t = TestType()

    @assert !has_field(t, :a)
    @assert !has_field(t, :b)

    @assert false == try get_field(t, :a); end

    set_field(t, :b, true)
    @assert has_field(t, :b)
    @assert (get_field(t, :b) == true)

    @assert !isinitialized(t)
    t.a = "hello"
    @assert !isinitialized(t)
    set_field(t, :a, "hello world")
    @assert isinitialized(t)
    @assert (get_field(t, :a) ==  "hello world")

    clear(t, :b)
    @assert isinitialized(t)
    clear(t)
    @assert !isinitialized(t)
end
end # module ProtoBufTestApis

ProtoBufTestApis.test_apis()

