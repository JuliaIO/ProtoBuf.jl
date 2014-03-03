using ProtoBuf

import ProtoBuf.meta

enum(x) = int(x)
sint32(x) = int32(x)
sint64(x) = int64(x)
fixed64(x) = float64(x)
sfixed64(x) = float64(x)
double(x) = float64(x)
fixed32(x) = float32(x)
sfixed32(x) = float32(x)

print_hdr(tname) = println("testing $tname...")

type TestType
    val::Any
end

type TestStr
    val::String
end
==(t1::TestStr, t2::TestStr) = (t1.val == t2.val)

type TestOptional
    sVal1::TestStr
    sVal2::TestStr
    iVal2::Array{Int64,1}
end

type TestNested
    fld1::TestType
    fld2::TestOptional
    fld3::Array{TestStr}
end

type TestDefaults
    iVal1::Int64
    sVal2::String
    iVal2::Array{Int64,1}

    TestDefaults(f1,f2,f3) = new(f1,f2,f3)
    TestDefaults() = new()
end

# disable caching of meta since we manually modify them for the tests
meta(t::Type{TestType})         = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
meta(t::Type{TestOptional})     = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
meta(t::Type{TestNested})       = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
meta(t::Type{TestDefaults})     = meta(t, Symbol[], Int[], {:iVal1 => 10, :iVal2 => [1,2,3]}, false)

function mk_test_nested_meta(o1::Bool, o2::Bool, o21::Bool, o22::Bool)
    meta1 = mk_test_meta(1, :int64)
    meta2 = mk_test_optional_meta(o21, o22)

    m = meta(TestNested)
    m.symdict[:fld1].occurrence = o1 ? 0 : 1
    m.symdict[:fld2].occurrence = o2 ? 0 : 1
    m.symdict[:fld1].meta = meta1
    m.symdict[:fld2].meta = meta2
    m
end

function mk_test_optional_meta(opt1::Bool, opt2::Bool)
    m = meta(TestOptional)
    m.symdict[:sVal1].occurrence = opt1 ? 0 : 1
    m.symdict[:sVal2].occurrence = opt2 ? 0 : 1
    m
end

function mk_test_meta(fldnum::Int, ptyp::Symbol)
    m = meta(TestType)
    attrib = m.symdict[:val]
    attrib.fldnum = fldnum
    attrib.ptyp = ptyp
    m.numdict = Dict{Int,ProtoMetaAttribs}()
    m.numdict[fldnum] = attrib
    m
end

assert_equal{T,U}(::Type{Array{T,1}}, ::Type{Array{U,1}}) = @assert issubtype(T,U) || issubtype(U,T)
assert_equal(T::Type, U::Type) = @assert issubtype(T,U) || issubtype(U,T)
assert_equal(val1::Bool, val2::Bool) = @assert val1 == val2
assert_equal(val1::String, val2::String) = @assert val1 == val2
assert_equal(val1::Number, val2::Number) = @assert val1 == val2
assert_equal{T<:Number}(val1::Array{T,1}, val2::Array{T,1}) = @assert val1 == val2
assert_equal{T<:String}(val1::Array{T,1}, val2::Array{T,1}) = @assert val1 == val2
function assert_equal(val1, val2)
    typ1 = typeof(val1)
    typ2 = typeof(val2)
    assert_equal(typ1, typ2)
   
    n = typ1.names
    t = typ1.types 
    for fld in n
        fldfill1 = filled(val1, fld)
        fldfill2 = filled(val2, fld)
        @assert fldfill1 == fldfill2
        fldfill1 && assert_equal(getfield(val1, fld), getfield(val2, fld))
    end
end

function test_types()
    pb = PipeBuffer()
    testval = TestType(0)
    readval = TestType(0)

    for typ in [:int32, :int64, :uint32, :uint64, :sint32, :sint64, :bool, :enum]
        print_hdr(typ)
        for idx in 1:100
            testval.val = eval(typ)(rand() * 10^9)
            meta = mk_test_meta(int(rand() * 100) + 1, typ)
            writeproto(pb, testval, meta) 
            readproto(pb, readval, meta)
            assert_equal(testval, readval)
        end
    end

    for typ in [:fixed64, :sfixed64, :double, :fixed32, :sfixed32, :float]
        print_hdr(typ)
        for idx in 1:100
            testval.val = (typ != :float) ? eval(typ)(rand() * 10^9) : float32(rand() * 10^9)
            meta = mk_test_meta(int(rand() * 100) + 1, typ)
            writeproto(pb, testval, meta) 
            readproto(pb, readval, meta)
            assert_equal(testval, readval)
        end
    end

    print_hdr("string")
    for idx in 1:100
        testval.val = randstring(50)
        meta = mk_test_meta(int(rand() * 100) + 1, :string)
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end
end

function test_repeats()
    pb = PipeBuffer()
    testval = TestType(0)
    readval = TestType(0)

    print_hdr("repeated int64")
    for idx in 1:100
        testval.val = convert(Array{Int64,1}, randstring(50).data)
        readval.val = Int64[]
        meta = mk_test_meta(int(rand() * 100) + 1, :int64)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end

    print_hdr("testing repeated and packed int64")
    for idx in 1:100
        testval.val = convert(Array{Int64,1}, randstring(50).data)
        readval.val = Int64[]
        meta = mk_test_meta(int(rand() * 100) + 1, :int64)
        meta.ordered[1].occurrence = 2
        meta.ordered[1].packed = true
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end

    print_hdr("testing repeated string")
    for idx in 1:100
        testval.val = [randstring(5) for i in 1:10] 
        readval.val = String[]
        meta = mk_test_meta(int(rand() * 100) + 1, :string)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end
end

function test_optional()
    print_hdr("testing optional fields")
    pb = PipeBuffer()
    testval = TestOptional(TestStr(""), TestStr(""), Int64[1,2,3])
    readval = TestOptional(TestStr(""), TestStr(""), Int64[])

    for idx in 1:100
        testval.sVal1 = TestStr(string(int(rand() * 100)))
        testval.sVal2 = TestStr(randstring(5))
        testval.iVal2 = Int64[int(rand() * 100) for i in 1:10]
        sVal1Opt = randbool()
        sVal2Opt = randbool()
        meta = mk_test_optional_meta(sVal1Opt, sVal2Opt)
        fillunset(testval)
        fillset(testval, :iVal2)
        !sVal1Opt && fillset(testval, :sVal1)
        !sVal2Opt && fillset(testval, :sVal2)

        writeproto(pb, testval, meta)
        readval.iVal2 = Int64[]
        readproto(pb, readval, meta)

        assert_equal(testval, readval)
    end
end

function test_nested()
    print_hdr("testing nested types")
    pb = PipeBuffer()

    testfld1 = TestType(0)
    readfld1 = TestType(0)
    testfld2 = TestOptional(TestStr("1"), TestStr(""), Int64[1,2,3])
    readfld2 = TestOptional(TestStr("1"), TestStr(""), Int64[])
    testval = TestNested(testfld1, testfld2, [TestStr("hello"), TestStr("world")])
    readval = TestNested(readfld1, readfld2, TestStr[])

    for idx in 1:100
        testfld1.val = int64(rand() * 10^9)
        testfld2.sVal1 = TestStr(string(int(rand() * 100)))
        testfld2.sVal2 = TestStr(randstring(5))
        testfld2.iVal2 = Int64[int(rand() * 100) for i in 1:10]

        o1 = randbool()
        o2 = randbool()
        o21 = randbool()
        o22 = randbool()
        meta = mk_test_nested_meta(o1, o2, o21, o22)

        fillunset(testval)
        fillset(testval, :fld3)
        !o1 && fillset(testval, :fld1)
        !o2 && fillset(testval, :fld2)

        fillunset(testfld2)
        fillset(testfld2, :iVal2)
        !o21 && fillset(testfld2, :sVal1)
        !o22 && fillset(testfld2, :sVal2)

        writeproto(pb, testval, meta)
        readfld2.iVal2 = Int64[]
        readval.fld3 = TestType[]
        readproto(pb, readval, meta)

        assert_equal(testval, readval)
    end
end

function test_defaults()
    print_hdr("testing default values")
    pb = PipeBuffer()

    testval = TestDefaults()
    readval = TestDefaults()
    testval.iVal1 = int(rand() * 100)
    writeproto(pb, testval)
    readproto(pb, readval)

    assert_equal(TestDefaults(testval.iVal1, "", [1,2,3]), readval)
end

test_types()
test_repeats()
test_optional()
test_nested()
test_defaults()
gc()
println("_metacache has $(length(ProtoBuf._metacache)) items")
println(ProtoBuf._metacache)
println("_fillcache has $(length(ProtoBuf._fillcache)) items")
println(ProtoBuf._fillcache)

