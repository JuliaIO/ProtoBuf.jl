module ProtoBufTestWellKnown
using ProtoBuf
using ProtoBuf.google.protobuf
using ..Test
using Random

print_hdr(tname) = println("testing $tname...")

function test_listvalue()
    print_hdr(ListValue.name)
    v1 = Value(;number_value=10.10)
    v2 = Value(;string_value="hello")
    va = [v1, v2]
    l = ListValue(;values=va)
    iob = PipeBuffer()
    writeproto(iob, l)
    l1 = ListValue()
    readproto(iob, l1)

    @test length(l.values) == length(l1.values)
    @test l.values[1].number_value == l1.values[1].number_value
    @test l.values[2].string_value == l1.values[2].string_value
    @test l == l1
end

function test_struct()
    print_hdr(Struct.name)
    v1 = Value(;number_value=10.10)
    v2 = Value(;string_value="hello")
    vd = Dict{AbstractString,Any}()
    vd["v1"] = v1
    vd["v2"] = v2
    s = Struct(;fields=vd)
    iob = PipeBuffer()
    writeproto(iob, s)
    s1 = Struct()
    readproto(iob, s1)

    @test length(s.fields) == length(s1.fields)
    @test s.fields["v1"].number_value == s1.fields["v1"].number_value
    @test s.fields["v2"].string_value == s1.fields["v2"].string_value
    @test s == s1
end

function test_generic(::Type{T}; kwargs...) where T
    print_hdr(T.name)
    w = T(;kwargs...)
    iob = PipeBuffer()
    writeproto(iob, w)
    r = T()
    readproto(iob, r)
    @test w == r
end

test_any() = test_generic(_Any; type_url="testurl", value=UInt8[1,2,3,4,5])
test_empty() = test_generic(Empty)
test_timestamp() = test_generic(Timestamp; seconds=10, nanos=100)
test_duration() = test_generic(Duration; seconds=10, nanos=100)
test_fieldmask() = test_generic(FieldMask; paths=[randstring(10), randstring(10)])

function test_wrappers()
    types = [DoubleValue, FloatValue, Int64Value, UInt64Value, Int32Value, UInt32Value, BoolValue, StringValue, BytesValue]
    vals = Any[1.1, Float32(1.1), 100, rand(UInt64), rand(Int32), rand(UInt32), true, randstring(10), rand(UInt8, 10)]
    for idx in 1:length(types)
        test_generic(types[idx]; value=vals[idx])
    end
end

end # module ProtoBufTestWellKnown

ProtoBufTestWellKnown.test_listvalue()
ProtoBufTestWellKnown.test_struct()
ProtoBufTestWellKnown.test_any()
ProtoBufTestWellKnown.test_empty()
ProtoBufTestWellKnown.test_timestamp()
ProtoBufTestWellKnown.test_duration()
ProtoBufTestWellKnown.test_fieldmask()
ProtoBufTestWellKnown.test_wrappers()
