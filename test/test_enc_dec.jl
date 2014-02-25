using Protobuf

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

type TestOptional
    iVal1::Int64
    sVal2::String
    iVal2::Array{Int64,1}
end

type TestNested
    fld1::TestType
    fld2::TestOptional
end

function mk_test_nested_meta(o1::Bool, o2::Bool, o21::Bool, o22::Bool)
    (meta1,filled1) = mk_test_meta(1, :int64)
    (meta2, filled2) = mk_test_optional_meta(o21, o22)

    filled = Dict{Symbol, Union(Bool,ProtoFill)}()
    filled[:fld1] = o1 ? false : filled1
    filled[:fld2] = o2 ? false : filled2

    attrib1 = ProtoMetaAttribs(1, :fld1, :obj, o1 ? 0 : 1, false, [], meta1)
    attrib2 = ProtoMetaAttribs(2, :fld2, :obj, o2 ? 0 : 1, false, [], meta2)
    symdict = Dict{Symbol,ProtoMetaAttribs}()
    numdict = Dict{Int,ProtoMetaAttribs}()
    attribarr = ProtoMetaAttribs[]
    for (sym,fldnum,attrib) in [(:fld1,1,attrib1), (:fld2,2,attrib2)]
        symdict[sym] = numdict[fldnum] = attrib
        push!(attribarr, attrib)
    end

    (ProtoMeta(TestNested, symdict, numdict, attribarr), ProtoFill(TestNested, filled))
end

function mk_test_optional_meta(opt1::Bool, opt2::Bool)
    attrib1 = ProtoMetaAttribs(1, :iVal1, :int64, opt1 ? 0 : 1, false, [], nothing)
    attrib2 = ProtoMetaAttribs(2, :sVal2, :string, opt2 ? 0 : 1, false, [], nothing)
    attrib3 = ProtoMetaAttribs(3, :iVal2, :int64, 2, true, [], nothing)

    symdict = Dict{Symbol,ProtoMetaAttribs}()
    numdict = Dict{Int,ProtoMetaAttribs}()
    attribarr = ProtoMetaAttribs[]

    for (sym,fldnum,attrib) in [(:iVal1,1,attrib1), (:sVal2,2,attrib2), (:iVal2,3,attrib3)]
        symdict[sym] = numdict[fldnum] = attrib
        push!(attribarr, attrib)
    end

    filled = Dict{Symbol, Union(Bool,ProtoFill)}()
    filled[:iVal1] = !opt1
    filled[:sVal2] = !opt2
    filled[:iVal2] = true

    (ProtoMeta(TestOptional, symdict, numdict, attribarr), ProtoFill(TestOptional, filled))
end

function mk_test_meta(fldnum::Int, ptyp::Symbol)
    attrib = ProtoMetaAttribs(fldnum, :val, ptyp, 1, false, [], nothing)
    symdict = Dict{Symbol,ProtoMetaAttribs}()
    numdict = Dict{Int,ProtoMetaAttribs}()
    symdict[:val] = attrib
    numdict[fldnum] = attrib

    filled = Dict{Symbol, Union(Bool,ProtoFill)}()
    filled[:val] = true

    (ProtoMeta(TestType, symdict, numdict, [attrib]), ProtoFill(TestType, filled))
end


function test_types()
    pb = PipeBuffer()
    testval = TestType(0)
    readval = TestType(0)

    for typ in [:int32, :int64, :uint32, :uint64, :sint32, :sint64, :bool, :enum]
        print_hdr(typ)
        for idx in 1:100
            testval.val = eval(typ)(rand() * 10^9)
            (meta,filled) = mk_test_meta(int(rand() * 100) + 1, typ)
            writeproto(pb, testval, meta) 
            readproto(pb, readval, meta)
            @assert testval.val == readval.val
        end
    end

    for typ in [:fixed64, :sfixed64, :double, :fixed32, :sfixed32, :float]
        print_hdr(typ)
        for idx in 1:100
            testval.val = (typ != :float) ? eval(typ)(rand() * 10^9) : float32(rand() * 10^9)
            (meta,filled) = mk_test_meta(int(rand() * 100) + 1, typ)
            writeproto(pb, testval, meta) 
            readproto(pb, readval, meta)
            @assert testval.val == readval.val
        end
    end

    print_hdr("string")
    for idx in 1:100
        testval.val = randstring(50)
        (meta,filled) = mk_test_meta(int(rand() * 100) + 1, :string)
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        @assert testval.val == readval.val
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
        (meta,filled) = mk_test_meta(int(rand() * 100) + 1, :int64)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        @assert testval.val == readval.val
    end

    print_hdr("testing repeated and packed int64")
    for idx in 1:100
        testval.val = convert(Array{Int64,1}, randstring(50).data)
        readval.val = Int64[]
        (meta,filled) = mk_test_meta(int(rand() * 100) + 1, :int64)
        meta.ordered[1].occurrence = 2
        meta.ordered[1].packed = true
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        @assert testval.val == readval.val
    end

    print_hdr("testing repeated string")
    for idx in 1:100
        testval.val = [randstring(5) for i in 1:10] 
        readval.val = String[]
        (meta,filled) = mk_test_meta(int(rand() * 100) + 1, :string)
        meta.ordered[1].occurrence = 2
        writeproto(pb, testval, meta) 
        readproto(pb, readval, meta)
        @assert testval.val == readval.val
    end
end

function test_optional()
    print_hdr("testing optional fields")
    pb = PipeBuffer()
    testval = TestOptional(1, "", Int64[1,2,3])
    readval = TestOptional(1, "", Int64[])

    for idx in 1:100
        testval.iVal1 = int(rand() * 100)
        testval.sVal2 = randstring(5)
        testval.iVal2 = Int64[int(rand() * 100) for i in 1:10]
        (meta, fill) = mk_test_optional_meta(randbool(), randbool())

        writeproto(pb, testval, meta, fill)
        readfill = ProtoFill(TestOptional, Dict{Symbol, Union(Bool,ProtoFill)}())
        readval.iVal2 = Int64[]
        readproto(pb, readval, meta, readfill)

        for fld in keys(fill.filled)
            @assert fill.filled[fld] == (fld in keys(readfill.filled))
        end
        for fld in [:iVal1, :sVal2, :iVal2]
            if fill.filled[fld] == true
                @assert getfield(testval, fld) == getfield(readval, fld)
            end
        end
    end
end

function test_nested()
    print_hdr("testing nested types")
    pb = PipeBuffer()

    testfld1 = TestType(0)
    readfld1 = TestType(0)
    testfld2 = TestOptional(1, "", Int64[1,2,3])
    readfld2 = TestOptional(1, "", Int64[])
    testval = TestNested(testfld1, testfld2)
    readval = TestNested(readfld1, readfld2)

    for idx in 1:100
        testfld1.val = int64(rand() * 10^9)
        testfld2.iVal1 = int(rand() * 100)
        testfld2.sVal2 = randstring(5)
        testfld2.iVal2 = Int64[int(rand() * 100) for i in 1:10]

        (meta, fill) = mk_test_nested_meta(randbool(), randbool(), randbool(), randbool())

        writeproto(pb, testval, meta, fill)
        readfill = ProtoFill(TestNested, Dict{Symbol, Union(Bool,ProtoFill)}())
        readfld2.iVal2 = Int64[]
        readproto(pb, readval, meta, readfill)

        for fldfill in keys(fill.filled)
            fill2 = fill.filled[fldfill]
            if fill2 != false
                readfill2 = readfill.filled[fldfill]
                for fld in keys(fill2.filled)
                    @assert fill2.filled[fld] == (fld in keys(readfill2.filled))
                end
            end
        end

        fill2 = fill.filled[:fld1]
        if fill2 != false
            if fill2.filled[:val] == true
                @assert getfield(testval.fld1, :val) == getfield(readval.fld1, :val)
            end
        end
        fill2 = fill.filled[:fld2]
        if fill2 != false
            for fld in [:iVal1, :sVal2, :iVal2]
                if fill2.filled[fld] == true
                    @assert getfield(testval.fld2, fld) == getfield(readval.fld2, fld)
                end
            end
        end
    end

end

test_types()
test_repeats()
test_optional()
test_nested()

