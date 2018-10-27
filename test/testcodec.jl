module ProtoBufTestCodec
using ProtoBuf
using Test
using Random
import Base: ==

import ProtoBuf.meta

macro _rand_int(T,mx,a)
   esc(quote
       $(T)(round(rand() * $(mx)) + $(a))
   end)
end

print_hdr(tname) = println("testing $tname...")

mutable struct TestType <: ProtoType
    val::Any
end

mutable struct TestStr <: ProtoType
    val::AbstractString
end
==(t1::TestStr, t2::TestStr) = (t1.val == t2.val)

mutable struct TestOptional <: ProtoType
    sVal1::TestStr
    sVal2::TestStr
    iVal2::Array{Int64,1}
end

mutable struct TestNested <: ProtoType
    fld1::TestType
    fld2::TestOptional
    fld3::Array{TestStr}
end

mutable struct TestDefaults <: ProtoType
    iVal1::Int64
    sVal2::AbstractString
    iVal2::Array{Int64,1}

    TestDefaults(f1,f2,f3) = new(f1,f2,f3)
    TestDefaults() = new()
end

mutable struct TestOneofs <: ProtoType
    iVal1::Int64
    iVal2::Int64
    iVal3::Int64

    TestOneofs() = new()
end

mutable struct TestMaps <: ProtoType
    d1::Dict{Int,Int}
    d2::Dict{Int32,String}
    d3::Dict{String,String}
    TestMaps() = new()
end

mutable struct TestFilled <: ProtoType
    fld1::TestType
    fld2::TestType
    TestFilled() = new()
end

mutable struct __enum_TestEnum <: ProtoEnum
    UNIVERSAL::Int32
    WEB::Int32
    IMAGES::Int32
    LOCAL::Int32
    NEWS::Int32
    PRODUCTS::Int32
    VIDEO::Int32
    __enum_TestEnum() = new(0,1,2,3,4,5,6)
end
const TestEnum = __enum_TestEnum()

# disable caching of meta since we manually modify them for the tests
meta(t::Type{TestType})         = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
meta(t::Type{TestOptional})     = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
meta(t::Type{TestNested})       = meta(t, Symbol[], Int[], Dict{Symbol,Any}(), false)
const _t_defaults = Dict{Symbol,Any}(:iVal1 => 10, :iVal2 => [1,2,3])
meta(t::Type{TestDefaults})     = meta(t, Symbol[], Int[], _t_defaults, false)
const _t_oneofs = Int[0,1,1]
const _t_oneof_names = [:optval]
meta(t::Type{TestOneofs})       = meta(t,  Symbol[], Int[], Dict{Symbol,Any}(), false, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, _t_oneofs, _t_oneof_names)
meta(t::Type{TestFilled})       = meta(t, Symbol[:fld1], Int[], Dict{Symbol,Any}())

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

assert_equal(::Type{Array{T,1}}, ::Type{Array{U,1}}) where {T,U} = @test (T <: U) || (U <: T)
assert_equal(T::Type, U::Type) = @test (T <: U) || (U <: T)
assert_equal(val1::Bool, val2::Bool) = @test val1 == val2
assert_equal(val1::AbstractString, val2::AbstractString) = @test val1 == val2
assert_equal(val1::Number, val2::Number) = @test val1 == val2
assert_equal(val1::Array{T,1}, val2::Array{T,1}) where {T<:Number} = @test val1 == val2
assert_equal(val1::Array{T,1}, val2::Array{T,1}) where {T<:AbstractString} = @test val1 == val2
assert_equal(val1::Dict{K,V}, val2::Dict{K,V}) where {K,V} = @test val1 == val2
function assert_equal(val1, val2)
    typ1 = typeof(val1)
    typ2 = typeof(val2)
    assert_equal(typ1, typ2)
   
    n = fieldnames(typ1)
    t = typ1.types 
    for fld in n
        fldfill1 = isfilled(val1, fld)
        fldfill2 = isfilled(val2, fld)
        @test fldfill1 == fldfill2
        fldfill1 && assert_equal(getfield(val1, fld), getfield(val2, fld))
    end
end

function test_types()
    pb = PipeBuffer()
    testval = TestType(0)
    readval = TestType(0)

    # test enum
    print_hdr("enum")
    testval.val = @_rand_int(Int32, 10^9, 0)
    fldnum = @_rand_int(Int, 100, 1)
    meta = mk_test_meta(fldnum, :enum)
    writeproto(pb, testval, meta)
    readproto(pb, readval, meta)
    assert_equal(testval, readval)

    let typs = [Int32,Int64,UInt32,UInt64,Int32,Int64,UInt64,Int64,UInt32,Int32], ptyps=[:int32,:int64,:uint32,:uint64,:sint32,:sint64,:fixed64,:sfixed64,:fixed32,:sfixed32]
        for (typ,ptyp) in zip(typs,ptyps)
            print_hdr(ptyp)
            for idx in 1:100
                testval.val = convert(typ, @_rand_int(UInt32, 10^9, 0))
                fldnum = @_rand_int(Int, 100, 1)
                meta = mk_test_meta(fldnum, ptyp)
                writeproto(pb, testval, meta)
                readproto(pb, readval, meta)
                assert_equal(testval, readval)
            end
        end
    end

    let typs = [Int32,Int64,Int32,Int64], ptyps=[:int32,:int64,:sint32,:sint64]
        for (typ,ptyp) in zip(typs,ptyps)
            print_hdr(ptyp)
            for idx in 1:100
                testval.val = convert(typ, -1 * @_rand_int(Int32, 10^9, 0))
                fldnum = @_rand_int(Int, 100, 1)
                meta = mk_test_meta(fldnum, ptyp)
                writeproto(pb, testval, meta)
                readproto(pb, readval, meta)
                assert_equal(testval, readval)
            end
        end
    end

    print_hdr("varint overflow...")
    ProtoBuf._write_uleb(pb, -1)
    @test ProtoBuf._read_uleb(pb, Int8) == 0
    ProtoBuf._write_uleb(pb, 1)
    @test ProtoBuf._read_uleb(pb, Int8) == 1
    write(pb, 0xff)
    ProtoBuf._write_uleb(pb, -1)
    @test ProtoBuf._read_uleb(pb, Int32) == 0

    let typs = [Bool], ptyps=[:bool]
        for (typ,ptyp) in zip(typs,ptyps)
            print_hdr(ptyp)
            for idx in 1:100
                testval.val = convert(typ, @_rand_int(UInt32, 1, 0))
                fldnum = @_rand_int(Int, 100, 1)
                meta = mk_test_meta(fldnum, ptyp)
                writeproto(pb, testval, meta)
                readproto(pb, readval, meta)
                assert_equal(testval, readval)
            end
        end
    end

    let typs = [Float64,Float32], ptyps=[:double,:float]
        for (typ,ptyp) in zip(typs,ptyps)
            print_hdr(ptyp)
            for idx in 1:100
                testval.val = convert(typ, @_rand_int(UInt32, 10^9, 0))
                fldnum = @_rand_int(Int, 100, 1)
                meta = mk_test_meta(fldnum, ptyp)
                writeproto(pb, testval, meta) 
                readproto(pb, readval, meta)
                assert_equal(testval, readval)
            end
        end
    end

    print_hdr("string")
    for idx in 1:100
        testval.val = randstring(50)
        fldnum = @_rand_int(Int, 100, 1)
        meta = mk_test_meta(fldnum, :string)
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
        testval.val = collect(Int64, randstring(50))
        readval.val = Int64[]
        fldnum = @_rand_int(Int, 100, 1)
        meta = mk_test_meta(fldnum, :int64)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end

    print_hdr("repeated and packed int64")
    for idx in 1:100
        testval.val = collect(Int64, randstring(50))
        readval.val = Int64[]
        fldnum = @_rand_int(Int, 100, 1)
        meta = mk_test_meta(fldnum, :int64)
        meta.ordered[1].occurrence = 2
        meta.ordered[1].packed = true
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end

    print_hdr("repeated string")
    for idx in 1:100
        testval.val = [randstring(5) for i in 1:10] 
        readval.val = AbstractString[]
        fldnum = @_rand_int(Int, 100, 1)
        meta = mk_test_meta(fldnum, :string)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        assert_equal(testval, readval)
    end
end

function test_optional()
    print_hdr("optional fields")
    pb = PipeBuffer()
    testval = TestOptional(TestStr(""), TestStr(""), Int64[1,2,3])
    readval = TestOptional(TestStr(""), TestStr(""), Int64[])

    for idx in 1:100
        testval.sVal1 = TestStr(string(@_rand_int(Int, 100, 0)))
        testval.sVal2 = TestStr(randstring(5))
        testval.iVal2 = Int64[@_rand_int(Int,100,0) for i in 1:10]
        sVal1Opt = rand(Bool)
        sVal2Opt = rand(Bool)
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
    print_hdr("nested types")
    pb = PipeBuffer()

    testfld1 = TestType(0)
    readfld1 = TestType(0)
    testfld2 = TestOptional(TestStr("1"), TestStr(""), Int64[1,2,3])
    readfld2 = TestOptional(TestStr("1"), TestStr(""), Int64[])
    testval = TestNested(testfld1, testfld2, [TestStr("hello"), TestStr("world")])
    readval = TestNested(readfld1, readfld2, TestStr[])

    for idx in 1:100
        testfld1.val = @_rand_int(Int64, 10^9, 0)
        testfld2.sVal1 = TestStr(string(@_rand_int(Int, 100, 0)))
        testfld2.sVal2 = TestStr(randstring(5))
        testfld2.iVal2 = Int64[@_rand_int(Int, 100, 0) for i in 1:10]

        o1 = rand(Bool)
        o2 = rand(Bool)
        o21 = rand(Bool)
        o22 = rand(Bool)
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
        readval.fld3 = TestStr[]
        readproto(pb, readval, meta)

        assert_equal(testval, readval)
    end
end

function test_defaults()
    print_hdr("default values")
    pb = PipeBuffer()

    testval = TestDefaults()
    readval = TestDefaults()
    testval.iVal1 = @_rand_int(Int, 100, 0)
    writeproto(pb, testval)
    readproto(pb, readval)

    assert_equal(TestDefaults(testval.iVal1, "", [1,2,3]), readval)
end

function test_oneofs()
    print_hdr("oneofs")
    testval = TestOneofs()
    @test isfilled(testval)
    @test isfilled(testval, :iVal1)
    @test !isfilled(testval, :iVal2)
    @test isfilled(testval, :iVal3)
    @test which_oneof(testval, :optval) === :iVal3

    testval.iVal2 = 10
    @test isfilled(testval, :iVal1)
    @test isfilled(testval, :iVal2)
    @test !isfilled(testval, :iVal3)
    @test which_oneof(testval, :optval) === :iVal2

    testval.iVal1 = 10
    @test isfilled(testval, :iVal1)
    @test isfilled(testval, :iVal2)
    @test !isfilled(testval, :iVal3)
    @test which_oneof(testval, :optval) === :iVal2

    testval.iVal3 = 10
    @test isfilled(testval, :iVal1)
    @test !isfilled(testval, :iVal2)
    @test isfilled(testval, :iVal3)
    @test which_oneof(testval, :optval) === :iVal3
end

function test_maps()
    print_hdr("maps")
    pb = PipeBuffer()

    testval = TestMaps()
    readval = TestMaps()
    writeproto(pb, testval)
    readproto(pb, readval)
    assert_equal(testval, readval)

    testval = TestMaps()
    readval = TestMaps()
    testval.d1 = Dict{Int,Int}()
    writeproto(pb, testval)
    readproto(pb, readval)
    @test !isfilled(readval, :d1)

    testval = TestMaps()
    readval = TestMaps()
    testval.d2 = Dict{Int32,String}()
    writeproto(pb, testval)
    readproto(pb, readval)
    @test !isfilled(readval, :d2)

    testval = TestMaps()
    readval = TestMaps()
    testval.d3 = Dict{String,String}()
    writeproto(pb, testval)
    readproto(pb, readval)
    @test !isfilled(readval, :d3)

    testval = TestMaps()
    readval = TestMaps()
    testval.d1 = Dict{Int,Int}()
    testval.d1[1] = 1
    testval.d1[2] = 2
    writeproto(pb, testval)
    readproto(pb, readval)
    @test isfilled(readval, :d1)
    assert_equal(testval, readval)

    testval = TestMaps()
    readval = TestMaps()
    testval.d2 = Dict{Int32,String}()
    testval.d2[Int32(1)] = convert(String, "One")
    testval.d2[Int32(2)] = convert(String, "Two")
    writeproto(pb, testval)
    readproto(pb, readval)
    @test isfilled(readval, :d2)
    assert_equal(testval, readval)

    testval = TestMaps()
    readval = TestMaps()
    testval.d3 = Dict{String,String}()
    testval.d3["1"] = "One"
    testval.d3["2"] = "Two"
    writeproto(pb, testval)
    readproto(pb, readval)
    @test isfilled(readval, :d3)
    assert_equal(testval, readval)
end

function test_misc()
    print_hdr("misc functionality")
    testfld = TestOptional(TestStr("1"), TestStr(""), Int64[1,2,3])
    readfld = TestOptional(TestStr(""), TestStr("1"), Int64[])
    copy!(readfld, testfld)
    assert_equal(readfld, testfld)

    # test add_field!
    readfld = TestOptional(TestStr("1"), TestStr(""), Int64[])
    for iVal2 in testfld.iVal2
        add_field!(readfld, :iVal2, iVal2)
    end
    assert_equal(readfld, testfld)
    @test ProtoBuf.protoisequal(readfld, testfld)

    tf = TestFilled()
    @test !isfilled(tf)
    tf.fld1 = TestType("")
    fillset(tf, :fld1)
    @test isfilled(tf)

    iob = IOBuffer()
    show(iob, meta(TestOptional))
    @test !isempty(take!(iob))
    nothing
end

function test_enums()
    print_hdr("enums")
    @test getfield(TestEnum, lookup(TestEnum, 0)) == TestEnum.UNIVERSAL
    @test getfield(TestEnum, lookup(TestEnum, 1)) == TestEnum.WEB
    @test getfield(TestEnum, lookup(TestEnum, 2)) == TestEnum.IMAGES
    @test getfield(TestEnum, lookup(TestEnum, 3)) == TestEnum.LOCAL
    @test getfield(TestEnum, lookup(TestEnum, 4)) == TestEnum.NEWS
    @test getfield(TestEnum, lookup(TestEnum, 5)) == TestEnum.PRODUCTS
    @test getfield(TestEnum, lookup(TestEnum, 6)) == TestEnum.VIDEO

    @test enumstr(TestEnum, TestEnum.LOCAL) == "LOCAL"
    @test_throws ErrorException enumstr(TestEnum, Int32(12))
end

end # module ProtoBufTestCodec

ProtoBufTestCodec.test_types()
ProtoBufTestCodec.test_enums()
ProtoBufTestCodec.test_oneofs()
ProtoBufTestCodec.test_maps()
ProtoBufTestCodec.test_repeats()
ProtoBufTestCodec.test_optional()
ProtoBufTestCodec.test_nested()
ProtoBufTestCodec.test_defaults()
ProtoBufTestCodec.test_misc()
GC.gc()
println("_metacache has $(length(ProtoBuf._metacache)) entries")
#println(ProtoBuf._metacache)
println("_fillcache has $(length(ProtoBuf._fillcache)) entries")
#println(ProtoBuf._fillcache)
