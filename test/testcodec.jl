module ProtoBufTestCodec
using ProtoBuf
using Test
using Random
import ProtoBuf.meta

macro _rand_int(T,mx,a)
   esc(quote
       $(T)(round(rand() * $(mx)) + $(a))
   end)
end

const TestTypeJType = Ref{Type}(Int64)
const TestTypeWType = Ref{Symbol}(:int64)
const TestTypeFldNum = Ref{Int}(1)
const TestTypePack = Ref{Vector{Symbol}}(ProtoBuf.DEF_PACK)
mutable struct TestType <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestType(; kwargs...)
        obj = new(meta(TestType), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestType})
    allflds = Pair{Symbol,Union{Type,String}}[:val => TestTypeJType[]]
    wtypes = Dict{Symbol,Symbol}(:val => TestTypeWType[])
    meta(ProtoMeta(TestType), TestType, allflds, ProtoBuf.DEF_REQ, [TestTypeFldNum[]], ProtoBuf.DEF_VAL, TestTypePack[], wtypes, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestType, name::Symbol)
    if name === :val
        return (obj.__protobuf_jl_internal_values[name])::Any
    else
        getfield(obj, name)
    end
end

mutable struct TestStr <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestStr(; kwargs...)
        obj = new(meta(TestStr), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestStr})
    allflds = Pair{Symbol,Union{Type,String}}[:val => AbstractString]
    meta(ProtoMeta(TestStr), TestStr, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestStr, name::Symbol)
    if name === :val
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct TestOptional <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestOptional(; kwargs...)
        obj = new(meta(TestOptional), Dict{Symbol,Any}(), Set{Symbol}())
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
end
const TestOptionalReq = Symbol[]
function meta(::Type{TestOptional})
    allflds = Pair{Symbol,Union{Type,String}}[:sVal1 => TestStr, :sVal2 => TestStr, :iVal2 => Array{Int64,1}]
    meta(ProtoMeta(TestOptional), TestOptional, allflds, TestOptionalReq, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestOptional, name::Symbol)
    if name === :sVal1
        return (obj.__protobuf_jl_internal_values[name])::TestStr
    elseif name === :sVal2
        return (obj.__protobuf_jl_internal_values[name])::TestStr
    elseif name === :iVal2
        return (obj.__protobuf_jl_internal_values[name])::Array{Int64,1}
    else
        getfield(obj, name)
    end
end

mutable struct TestNested <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestNested(; kwargs...)
        obj = new(meta(TestNested), Dict{Symbol,Any}(), Set{Symbol}())
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

end
const TestNestedReq = Symbol[]
function meta(::Type{TestNested})
    allflds = Pair{Symbol,Union{Type,String}}[:fld1 => TestType, :fld2 => TestOptional, :fld3 => Array{TestStr,1}]
    meta(ProtoMeta(TestNested), TestNested, allflds, TestNestedReq, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestNested, name::Symbol)
    if name === :fld1
        return (obj.__protobuf_jl_internal_values[name])::TestType
    elseif name === :fld2
        return (obj.__protobuf_jl_internal_values[name])::TestOptional
    elseif name === :fld3
        return (obj.__protobuf_jl_internal_values[name])::Array{TestStr,1}
    else
        getfield(obj, name)
    end
end

mutable struct TestDefaults <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestDefaults(; kwargs...)
        obj = new(meta(TestDefaults), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestDefaults})
    allflds = Pair{Symbol,Union{Type,String}}[:iVal1 => Int64, :sVal2 => AbstractString, :iVal2 => Array{Int64,1}]
    defaults = Dict{Symbol,Any}(:iVal1 => 10, :iVal2 => [1,2,3])
    meta(ProtoMeta(TestDefaults), TestDefaults, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, defaults, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestDefaults, name::Symbol)
    if name === :iVal1
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :sVal2
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :iVal2
        return (obj.__protobuf_jl_internal_values[name])::Array{Int64,1}
    else
        getfield(obj, name)
    end
end

mutable struct TestOneofs <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestOneofs(; kwargs...)
        obj = new(meta(TestOneofs), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestOneofs})
    allflds = Pair{Symbol,Union{Type,String}}[:iVal1 => Int64, :iVal2 => Int64, :iVal3 => Int64]
    oneofs = Int[0,1,1]
    oneof_names = [:optval]
    meta(ProtoMeta(TestOneofs), TestOneofs, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, oneofs, oneof_names)
end
function Base.getproperty(obj::TestOneofs, name::Symbol)
    if name === :iVal1
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :iVal2
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :iVal3
        return (obj.__protobuf_jl_internal_values[name])::Int64
    else
        getfield(obj, name)
    end
end

mutable struct TestMaps <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestMaps(; kwargs...)
        obj = new(meta(TestMaps), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestMaps})
    allflds = Pair{Symbol,Union{Type,String}}[:d1 => Dict{Int,Int}, :d2 => Dict{Int32,String}, :d3 => Dict{String,String}]
    meta(ProtoMeta(TestMaps), TestMaps, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestMaps, name::Symbol)
    if name === :d1
        return (obj.__protobuf_jl_internal_values[name])::Dict{Int,Int}
    elseif name === :d2
        return (obj.__protobuf_jl_internal_values[name])::Dict{Int32,String}
    elseif name === :d3
        return (obj.__protobuf_jl_internal_values[name])::Dict{String,String}
    else
        getfield(obj, name)
    end
end

mutable struct TestFilled <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestFilled(; kwargs...)
        obj = new(meta(TestFilled), Dict{Symbol,Any}(), Set{Symbol}())
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
end
function meta(::Type{TestFilled})
    allflds = Pair{Symbol,Union{Type,String}}[:fld1 => TestType, :fld2 => TestType]
    meta(ProtoMeta(TestFilled), TestFilled, allflds, [:fld1], ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
end
function Base.getproperty(obj::TestFilled, name::Symbol)
    if name === :fld1
        return (obj.__protobuf_jl_internal_values[name])::TestType
    elseif name === :fld2
        return (obj.__protobuf_jl_internal_values[name])::TestType
    else
        getfield(obj, name)
    end
end

const TestEnum = (;[
    Symbol("UNIVERSAL") => Int32(0),
    Symbol("WEB") => Int32(1),
    Symbol("IMAGES") => Int32(2),
    Symbol("LOCAL") => Int32(3),
    Symbol("NEWS") => Int32(4),
    Symbol("PRODUCTS") => Int32(5),
    Symbol("VIDEO") => Int32(6),
]...)

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

    for fld in propertynames(typ1)
        fldfill1 = hasproperty(val1, fld)
        fldfill2 = hasproperty(val2, fld)
        @test fldfill1 == fldfill2
        fldfill1 && assert_equal(getproperty(val1, fld), getproperty(val2, fld))
    end
end

function test_types()
    pb = PipeBuffer()

    @testset "types" begin
        @testset "enum" begin
            TestTypeJType[] = Int32
            TestTypeWType[] = :int32
            TestTypePack[] = ProtoBuf.DEF_PACK
            TestTypeFldNum[] = @_rand_int(Int, 100, 1)
            testmeta = meta(TestType)
            testval = TestType(; val=@_rand_int(Int32, 10^9, 0))
            readval = TestType()
            writeproto(pb, testval, testmeta)
            readproto(pb, readval, testmeta)
            assert_equal(testval, readval)
        end

        @testset "integers" begin
            let typs = [Int32,Int64,UInt32,UInt64,Int32,Int64,UInt64,Int64,UInt32,Int32], ptyps=[:int32,:int64,:uint32,:uint64,:sint32,:sint64,:fixed64,:sfixed64,:fixed32,:sfixed32]
                for (typ,ptyp) in zip(typs,ptyps)
                    TestTypeJType[] = typ
                    TestTypeWType[] = ptyp
                    for idx in 1:100
                        TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                        testmeta = meta(TestType)
                        testval = TestType(; val=convert(typ, @_rand_int(UInt32, 10^9, 0)))
                        readval = TestType()
                        writeproto(pb, testval, testmeta)
                        readproto(pb, readval, testmeta)
                        assert_equal(testval, readval)
                    end
                end
            end

            let typs = [Int32,Int64,Int32,Int64], ptyps=[:int32,:int64,:sint32,:sint64]
                for (typ,ptyp) in zip(typs,ptyps)
                    TestTypeJType[] = typ
                    TestTypeWType[] = ptyp
                    for idx in 1:100
                        TestTypeFldNum[] = convert(typ, -1 * @_rand_int(Int32, 10^9, 0))
                        testmeta = meta(TestType)
                        testval = TestType(; val=convert(typ, @_rand_int(UInt32, 10^9, 0)))
                        readval = TestType()
                        writeproto(pb, testval, testmeta)
                        readproto(pb, readval, testmeta)
                        assert_equal(testval, readval)
                    end
                end
            end
        end

        @testset "varint overflow" begin
            ProtoBuf._write_uleb(pb, Int64(-1))
            @test ProtoBuf._read_uleb(pb, Int8) == 0
            ProtoBuf._write_uleb(pb, Int64(1))
            @test ProtoBuf._read_uleb(pb, Int8) == 1
            write(pb, 0xff)
            ProtoBuf._write_uleb(pb, Int64(-1))
            @test ProtoBuf._read_uleb(pb, Int32) == 0
        end

        @testset "bool" begin
            let typs = [Bool], ptyps=[:bool]
                for (typ,ptyp) in zip(typs,ptyps)
                    TestTypeJType[] = typ
                    TestTypeWType[] = ptyp
                    for idx in 1:100
                        TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                        testmeta = meta(TestType)
                        testval = TestType(; val=convert(typ, @_rand_int(UInt32, 1, 0)))
                        readval = TestType()
                        writeproto(pb, testval, testmeta)
                        readproto(pb, readval, testmeta)
                        assert_equal(testval, readval)
                    end
                end
            end
        end

        @testset "double, float" begin
            let typs = [Float64,Float32], ptyps=[:double,:float]
                for (typ,ptyp) in zip(typs,ptyps)
                    TestTypeJType[] = typ
                    TestTypeWType[] = ptyp
                    for idx in 1:100
                        TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                        testmeta = meta(TestType)
                        testval = TestType(; val=convert(typ, @_rand_int(UInt32, 10^9, 0)))
                        readval = TestType()
                        writeproto(pb, testval, testmeta)
                        readproto(pb, readval, testmeta)
                        assert_equal(testval, readval)
                    end
                end
            end
        end

        @testset "string" begin
            let typs = [AbstractString], ptyps=[:string]
                for (typ,ptyp) in zip(typs,ptyps)
                    TestTypeJType[] = typ
                    TestTypeWType[] = ptyp
                    for idx in 1:100
                        TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                        testmeta = meta(TestType)
                        testval = TestType(; val=randstring(50))
                        readval = TestType()
                        writeproto(pb, testval, testmeta)
                        readproto(pb, readval, testmeta)
                        assert_equal(testval, readval)
                    end
                end
            end
        end
    end
end

function test_repeats()
    pb = PipeBuffer()

    @testset "Repeated" begin
        @testset "Repeated int64" begin
            TestTypeJType[] = Vector{Int64}
            TestTypeWType[] = :int64
            TestTypePack[] = ProtoBuf.DEF_PACK
            for idx in 1:100
                TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                testval = TestType(; val=collect(Int64, randstring(50)))
                readval = TestType()
                testmeta = meta(TestType)
                writeproto(pb, testval, testmeta)
                readproto(pb, readval, testmeta)
                assert_equal(testval, readval)
            end
        end

        @testset "Repeated and packed int64" begin
            TestTypePack[] = Symbol[:val]
            for idx in 1:100
                TestTypeFldNum[] = @_rand_int(Int, 100, 1)
                testval = TestType(; val=collect(Int64, randstring(50)))
                readval = TestType()
                testmeta = meta(TestType)
                writeproto(pb, testval, testmeta)
                readproto(pb, readval, testmeta)
                assert_equal(testval, readval)
            end
        end

        @testset "Repeated string" begin
            TestTypeJType[] = Vector{AbstractString}
            TestTypeWType[] = :string
            TestTypePack[] = ProtoBuf.DEF_PACK
            for idx in 1:100
                testval = TestType(; val=AbstractString[randstring(5) for i in 1:10])
                readval = TestType()
                testmeta = meta(TestType)
                writeproto(pb, testval, testmeta)
                readproto(pb, readval, testmeta)
                assert_equal(testval, readval)
            end
        end
    end
end

function test_optional()
    @testset "Optional fields" begin
        pb = PipeBuffer()
        testval = TestOptional(; sVal1=TestStr(; val=""), sVal2=TestStr(; val=""), iVal2=Int64[1,2,3])
        readval = TestOptional(; sVal1=TestStr(; val=""), sVal2=TestStr(; val=""), iVal2=Int64[])

        for idx in 1:100
            testval.sVal1 = TestStr(; val=string(@_rand_int(Int, 100, 0)))
            testval.sVal2 = TestStr(; val=randstring(5))
            testval.iVal2 = Int64[@_rand_int(Int,100,0) for i in 1:10]

            empty!(TestOptionalReq)
            kwargs = Dict{Symbol,Any}(:iVal2 => Int64[@_rand_int(Int,100,0) for i in 1:10])
            if rand(Bool)
                push!(TestOptionalReq, :sVal1)
                kwargs[:sVal1] = TestStr(; val=string(@_rand_int(Int, 100, 0)))
            end
            if rand(Bool)
                push!(TestOptionalReq, :sVal2)
                kwargs[:sVal2] = TestStr(; val=randstring(5))
            end
            testval = TestOptional(; kwargs...)
            readval = TestOptional()
            testmeta = meta(TestOptional)
            writeproto(pb, testval, testmeta)
            readproto(pb, readval, testmeta)
            assert_equal(testval, readval)
        end
    end
end

function test_nested()
    @testset "Nested types" begin
        pb = PipeBuffer()

        TestTypeJType[] = Int64
        TestTypeWType[] = :int64
        TestTypePack[] = ProtoBuf.DEF_PACK
        TestTypeFldNum[] = 1

        for idx in 1:100
            o1 = rand(Bool)
            o2 = rand(Bool)
            o21 = rand(Bool)
            o22 = rand(Bool)

            empty!(TestNestedReq)
            testnestedkwargs = Dict{Symbol,Any}()
            if o1
                push!(TestNestedReq, :fld1)
                testnestedkwargs[:fld1] = TestType(; val=@_rand_int(Int64, 10^9, 0))
            end
            if o2
                push!(TestNestedReq, :fld2)
                empty!(TestOptionalReq)
                testfld2kwargs = Dict{Symbol,Any}(:iVal2=>Int64[@_rand_int(Int, 100, 0) for i in 1:10])
                if o21
                    push!(TestOptionalReq, :sVal1)
                    testfld2kwargs[:sVal1] = TestStr(; val=string(@_rand_int(Int, 100, 0)))
                end
                if o22
                    push!(TestOptionalReq, :sVal2)
                    testfld2kwargs[:sVal2] = TestStr(; val=randstring(5))
                end
                testnestedkwargs[:fld2] = TestOptional(; testfld2kwargs...)
            end

            testval = TestNested(; testnestedkwargs...)
            readval = TestNested()
            testmeta = meta(TestNested)

            writeproto(pb, testval, testmeta)
            readproto(pb, readval, testmeta)

            assert_equal(testval, readval)
        end
    end
end

function test_defaults()
    @testset "Default values" begin
        pb = PipeBuffer()

        testval = TestDefaults()
        readval = TestDefaults()
        testval.iVal1 = @_rand_int(Int, 100, 0)
        writeproto(pb, testval)
        readproto(pb, readval)

        assert_equal(TestDefaults(; iVal1=testval.iVal1, sVal2="", iVal2=[1,2,3]), readval)
    end
end

function test_oneofs()
    @testset "Oneofs" begin
        testval = TestOneofs(; iVal1=1, iVal3=3)
        @test isfilled(testval)
        @test hasproperty(testval, :iVal1)
        @test !hasproperty(testval, :iVal2)
        @test hasproperty(testval, :iVal3)
        @test which_oneof(testval, :optval) === :iVal3

        testval.iVal2 = 10
        @test hasproperty(testval, :iVal1)
        @test hasproperty(testval, :iVal2)
        @test !hasproperty(testval, :iVal3)
        @test which_oneof(testval, :optval) === :iVal2

        testval.iVal1 = 10
        @test hasproperty(testval, :iVal1)
        @test hasproperty(testval, :iVal2)
        @test !hasproperty(testval, :iVal3)
        @test which_oneof(testval, :optval) === :iVal2

        testval.iVal3 = 10
        @test hasproperty(testval, :iVal1)
        @test !hasproperty(testval, :iVal2)
        @test hasproperty(testval, :iVal3)
        @test which_oneof(testval, :optval) === :iVal3
    end
end

function test_maps()
    @testset "Maps" begin
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
        @test !hasproperty(readval, :d1)

        testval = TestMaps()
        readval = TestMaps()
        testval.d2 = Dict{Int32,String}()
        writeproto(pb, testval)
        readproto(pb, readval)
        @test !hasproperty(readval, :d2)

        testval = TestMaps()
        readval = TestMaps()
        testval.d3 = Dict{String,String}()
        writeproto(pb, testval)
        readproto(pb, readval)
        @test !hasproperty(readval, :d3)

        testval = TestMaps()
        readval = TestMaps()
        testval.d1 = Dict{Int,Int}()
        testval.d1[1] = 1
        testval.d1[2] = 2
        writeproto(pb, testval)
        readproto(pb, readval)
        @test hasproperty(readval, :d1)
        assert_equal(testval, readval)

        testval = TestMaps()
        readval = TestMaps()
        testval.d2 = Dict{Int32,String}()
        testval.d2[Int32(1)] = convert(String, "One")
        testval.d2[Int32(2)] = convert(String, "Two")
        writeproto(pb, testval)
        readproto(pb, readval)
        @test hasproperty(readval, :d2)
        assert_equal(testval, readval)

        testval = TestMaps()
        readval = TestMaps()
        testval.d3 = Dict{String,String}()
        testval.d3["1"] = "One"
        testval.d3["2"] = "Two"
        writeproto(pb, testval)
        readproto(pb, readval)
        @test hasproperty(readval, :d3)
        assert_equal(testval, readval)
    end
end

function test_misc()
    @testset "Miscellaneous functionality" begin
        testfld = TestOptional(; sVal1=TestStr(; val="1"), sVal2=TestStr(; val=""), iVal2=Int64[1,2,3])
        readfld = TestOptional(; sVal1=TestStr(; val=""), sVal2=TestStr(; val="1"), iVal2=Int64[])
        copy!(readfld, testfld)
        assert_equal(readfld, testfld)

        tf = TestFilled()
        @test !isfilled(tf)
        TestTypeJType[] = AbstractString
        TestTypeWType[] = :string
        TestTypeFldNum[] = 1
        TestTypePack[] = ProtoBuf.DEF_PACK
        tf.fld1 = TestType(; val="")
        @test isfilled(tf)

        iob = IOBuffer()
        show(iob, meta(TestOptional))
        @test !isempty(take!(iob))
    end
end

function test_enums()
    @testset "Enums" begin
        @test getproperty(TestEnum, lookup(TestEnum, 0)) == TestEnum.UNIVERSAL
        @test getproperty(TestEnum, lookup(TestEnum, 1)) == TestEnum.WEB
        @test getproperty(TestEnum, lookup(TestEnum, 2)) == TestEnum.IMAGES
        @test getproperty(TestEnum, lookup(TestEnum, 3)) == TestEnum.LOCAL
        @test getproperty(TestEnum, lookup(TestEnum, 4)) == TestEnum.NEWS
        @test getproperty(TestEnum, lookup(TestEnum, 5)) == TestEnum.PRODUCTS
        @test getproperty(TestEnum, lookup(TestEnum, 6)) == TestEnum.VIDEO

        @test enumstr(TestEnum, TestEnum.LOCAL) == "LOCAL"
        @test_throws ErrorException enumstr(TestEnum, Int32(12))
    end
end

end # module ProtoBufTestCodec

@testset "Codec" begin
    ProtoBufTestCodec.test_types()
    ProtoBufTestCodec.test_enums()
    ProtoBufTestCodec.test_oneofs()
    ProtoBufTestCodec.test_maps()
    ProtoBufTestCodec.test_repeats()
    ProtoBufTestCodec.test_optional()
    ProtoBufTestCodec.test_nested()
    ProtoBufTestCodec.test_defaults()
    ProtoBufTestCodec.test_misc()
end
