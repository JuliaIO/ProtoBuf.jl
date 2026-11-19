module TestDecode
using ProtoBuf: Codecs
import ProtoBuf as PB
using .Codecs: decode, decode!, ProtoDecoder, BufferedVector
using Test
using EnumX: @enumx

const temp_dir = mktempdir()
const test_dir = joinpath(pkgdir(PB), "test")

PB.protojl("test_messages_for_codec.proto", joinpath(test_dir, "test_protos"), temp_dir, always_use_modules=false, parametrize_oneofs=true)
include(joinpath(temp_dir, "test_messages_for_codec_pb.jl"))

TestInner(x::Int) = TestInner(x, nothing) # convenience constructor for a generated struct

const _Varint = Union{UInt32,UInt64,Int64,Int32,Bool,Enum}

wire_type(::Type{<:Union{Int32,Int64}},  V::Type{Val{:zigzag}}) = Codecs.VARINT
wire_type(::Type{<:_Varint},             V::Type{Nothing})      = Codecs.VARINT
wire_type(::Type{<:Union{UInt32,Int32}}, V::Type{Val{:fixed}})  = Codecs.FIXED32
wire_type(::Type{Float32},               V::Type{Nothing})      = Codecs.FIXED32
wire_type(::Type{<:Union{UInt64,Int64}}, V::Type{Val{:fixed}})  = Codecs.FIXED64
wire_type(::Type{Float64},               V::Type{Nothing})      = Codecs.FIXED64
wire_type(::Type{<:AbstractVector},      V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractDict},        V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractString},      V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:_Varint})                                    = Codecs.VARINT
wire_type(::Type{Float64})                                      = Codecs.FIXED64
wire_type(::Type{Float32})                                      = Codecs.FIXED32
wire_type(::Type{<:AbstractVector})                             = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractDict})                               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractString})                             = Codecs.LENGTH_DELIMITED

function test_decode(input_bytes, expected, V::Type=Nothing)
    w = wire_type(typeof(expected), V)
    input_bytes = collect(input_bytes)
    if w == Codecs.LENGTH_DELIMITED && !isa(expected, Dict)
        input_bytes = vcat(UInt8(length(input_bytes)), input_bytes)
    end

    e = ProtoDecoder(IOBuffer(input_bytes))
    if V === Nothing
        if eltype(expected) <: Union{String,Vector{UInt8},TestInner}
            skip(e.io, 1)
            x = BufferedVector{eltype(expected)}()
            while !eof(e.io)
                num, tag = PB.decode_tag(e)
                decode!(e, x)
            end
            x = x[]
        elseif isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x)
            x = x[]
        elseif isa(expected, Dict)
            x = Dict{keytype(expected), valtype(expected)}()
            while !eof(e.io)
                num, tag = PB.decode_tag(e)
                decode!(e, x)
            end
        else
            x = decode(e, typeof(expected))
        end
    else
        if isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x, V)
            x = x[]
        elseif isa(expected, Dict)
            x = Dict{keytype(expected), valtype(expected)}()
            while !eof(e.io)
                num, tag = PB.decode_tag(e)
                decode!(e, x, V)
            end
        else
            x = decode(e, typeof(expected), V)
        end
    end

    @test x == expected
end

function test_decode_message(input_bytes, expected::TestStruct, V=nothing)
    input_bytes = collect(input_bytes)
    e = ProtoDecoder(PipeBuffer(input_bytes))
    if isnothing(V)
        x = decode(e, typeof(expected))
    else
        _, tag = PB.decode_tag(e)
        @assert tag == Codecs.START_GROUP
        x = decode(e, Ref{typeof(expected)}, V)
    end
    @test x.oneof[] == expected.oneof[]
    @test typeof(x) === typeof(expected)
    @test typeof(x.oneof) === typeof(expected.oneof)
end

@testset "decode" begin
    @testset "length delimited" begin
        @testset "bytes" begin
            test_decode(b"123456789", b"123456789")
        end

        @testset "string" begin
            test_decode(b"123456789", "123456789")
        end

        @testset "repeated bytes" begin
            test_decode([0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34], [[0x31, 0x32], [0x33, 0x34]])
        end

        @testset "repeated string" begin
            test_decode([0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34], ["12", "34"])
        end

        @testset "repeated uint32" begin
            test_decode([0x01, 0x02], UInt32[1, 2])
        end

        @testset "repeated uint64" begin
            test_decode([0x01, 0x02], UInt64[1, 2])
        end

        @testset "repeated int32" begin
            test_decode([0x01, 0x02], Int32[1, 2])
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int32[-1])
        end

        @testset "repeated enum" begin
            test_decode([0x01, 0x02], [TestEnum.B, TestEnum.C])
        end

        @testset "repeated int64" begin
            test_decode([0x01, 0x02], Int64[1, 2])
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int64[-1])
        end

        @testset "repeated bool" begin
            test_decode([0x00, 0x01, 0x00], Bool[false, true, false])
            # bools are varints: any nonzero value is true
            test_decode([0x02, 0x80, 0x01, 0x80, 0x00], Bool[true, true, false])
        end

        @testset "repeated float64" begin
            test_decode(reinterpret(UInt8, Float64[1.0, 2.0]), Float64[1.0, 2.0])
        end

        @testset "repeated float32" begin
            test_decode(reinterpret(UInt8, Float32[1.0, 2.0]), Float32[1.0, 2.0])
        end

        @testset "repeated sfixed32" begin
            test_decode(reinterpret(UInt8, Int32[1, 2]), Int32[1, 2], Val{:fixed})
        end

        @testset "repeated sfixed64" begin
            test_decode(reinterpret(UInt8, Int64[1, 2]), Int64[1, 2], Val{:fixed})
        end

        @testset "repeated fixed32" begin
            test_decode(reinterpret(UInt8, UInt32[1, 2]), UInt32[1, 2], Val{:fixed})
        end

        @testset "repeated fixed64" begin
            test_decode(reinterpret(UInt8, UInt64[1, 2]), UInt64[1, 2], Val{:fixed})
        end

        @testset "repeated sint32" begin
            test_decode([0x02, 0x04, 0x01, 0x03], Int32[1, 2, -1, -2], Val{:zigzag})
        end

        @testset "repeated sint64" begin
            test_decode([0x02, 0x04, 0x01, 0x03], Int64[1, 2, -1, -2], Val{:zigzag})
        end

        @testset "repeated message" begin
            test_decode([0x12, 0x02, 0x08, 0x03, 0x12, 0x02, 0x08, 0x04], [TestInner(3), TestInner(4)])
        end

        @testset "map" begin
            @testset "string,string" begin test_decode([0x0a, 0x06, 0x0a, 0x01, 0x62, 0x12, 0x01, 0x61], Dict{String,String}("b" => "a")) end

            @testset "multiple string,string" begin test_decode([0x0a, 0x06, 0x0a, 0x01, 0x63, 0x12, 0x01, 0x64, 0x0a, 0x06, 0x0a, 0x01, 0x62, 0x12, 0x01, 0x61], Dict{String,String}("b" => "a", "c" => "d")) end
            @testset "multiple string,string reversed" begin test_decode([0x0a, 0x06, 0x0a, 0x01, 0x62, 0x12, 0x01, 0x61, 0x0a, 0x06, 0x0a, 0x01, 0x63, 0x12, 0x01, 0x64], Dict{String,String}("b" => "a", "c" => "d")) end

            @testset "int32,string" begin test_decode([0x0a, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a")) end
            @testset "int64,string" begin test_decode([0x0a, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a")) end
            @testset "uint32,string" begin test_decode([0x0a, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61], Dict{UInt32,String}(1 => "a")) end
            @testset "uint64,string" begin test_decode([0x0a, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61], Dict{UInt64,String}(1 => "a")) end
            @testset "bool,string" begin test_decode([0x0a, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61], Dict{Bool,String}(true => "a")) end

            @testset "sfixed32,string" begin test_decode([0x0a, 0x08, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "sfixed64,string" begin test_decode([0x0a, 0x0c, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed32,string" begin test_decode([0x0a, 0x08, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{UInt32,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed64,string" begin test_decode([0x0a, 0x0c, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{UInt64,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end

            @testset "sint32,string" begin test_decode([0x0a, 0x05, 0x08, 0x02, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a"), Val{Tuple{:zigzag,Nothing}}) end
            @testset "sint64,string" begin test_decode([0x0a, 0x05, 0x08, 0x02, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a"), Val{Tuple{:zigzag,Nothing}}) end

            @testset "string,int32" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Int32}("a" => 1)) end
            @testset "string,int64" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Int64}("a" => 1)) end
            @testset "string,uint32" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,UInt32}("a" => 1)) end
            @testset "string,uint64" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,UInt64}("a" => 1)) end
            @testset "string,bool" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Bool}("a" => true)) end

            @testset "string,sfixed32" begin test_decode([0x0a, 0x08, 0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{String,Int32}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,sfixed64" begin test_decode([0x0a, 0x0c, 0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,Int64}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed32" begin test_decode([0x0a, 0x08, 0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{String,UInt32}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed64" begin test_decode([0x0a, 0x0c, 0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,UInt64}("a" => 1), Val{Tuple{Nothing,:fixed}}) end

            @testset "string,sint32" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x02], Dict{String,Int32}("a" => 1), Val{Tuple{Nothing,:zigzag}}) end
            @testset "string,sint64" begin test_decode([0x0a, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x02], Dict{String,Int64}("a" => 1), Val{Tuple{Nothing,:zigzag}}) end


            @testset "sfixed32,sfixed32" begin test_decode([0x0a, 0x0a, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{Int32,Int32}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "sfixed64,sfixed64" begin test_decode([0x0a, 0x12, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{Int64,Int64}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed32,fixed32" begin test_decode([0x0a, 0x0a, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{UInt32,UInt32}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed64,fixed64" begin test_decode([0x0a, 0x12, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{UInt64,UInt64}(1 => 1), Val{Tuple{:fixed,:fixed}}) end

            @testset "sint32,sint32" begin test_decode([0x0a, 0x04, 0x08, 0x02, 0x10, 0x02], Dict{Int32,Int32}(1 => 1), Val{Tuple{:zigzag,:zigzag}}) end
            @testset "sint64,sint64" begin test_decode([0x0a, 0x04, 0x08, 0x02, 0x10, 0x02], Dict{Int64,Int64}(1 => 1), Val{Tuple{:zigzag,:zigzag}}) end

            # An entry's key and value can come in any order or be missing (then they take their
            # default value), and unknown fields in an entry are skipped.
            @testset "value before key" begin test_decode([0x0a, 0x05, 0x12, 0x01, 0x61, 0x08, 0x01], Dict{Int32,String}(1 => "a")) end
            @testset "missing value" begin test_decode([0x0a, 0x02, 0x08, 0x01], Dict{Int32,String}(1 => "")) end
            @testset "missing key" begin test_decode([0x0a, 0x03, 0x12, 0x01, 0x61], Dict{Int32,String}(0 => "a")) end
            @testset "empty entry" begin test_decode([0x0a, 0x00], Dict{String,Vector{UInt8}}("" => UInt8[])) end
            @testset "unknown field" begin test_decode([0x0a, 0x07, 0x08, 0x01, 0x18, 0x07, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a")) end
            @testset "missing message value" begin test_decode([0x0a, 0x03, 0x0a, 0x01, 0x6b], Dict{String,TestInner}("k" => TestInner(0))) end
            @testset "missing enum value" begin test_decode([0x0a, 0x02, 0x08, 0x01], Dict{Int32,TestEnum.T}(1 => TestEnum.A)) end
            @testset "missing sint32 value" begin test_decode([0x0a, 0x02, 0x08, 0x01], Dict{Int32,Int32}(1 => 0), Val{Tuple{Nothing,:zigzag}}) end
            @testset "missing fixed64 key" begin test_decode([0x0a, 0x02, 0x10, 0x04], Dict{UInt64,Int64}(0 => 2), Val{Tuple{:fixed,:zigzag}}) end
        end

        @testset "message" begin
            test_decode_message([0x0a, 0x03, 0x31, 0x32, 0x33], TestStruct(PB.OneOf(:bytes, collect(b"123"))))
            test_decode_message([0x10, 0x02], TestStruct(PB.OneOf(:enum, TestEnum.C)))
            test_decode_message([0x1a, 0x02, 0x08, 0x02], TestStruct(PB.OneOf(:var"#struct", TestInner(2))))
            test_decode_message([0x1a, 0x06, 0x08, 0x02, 0x12, 0x02, 0x08, 0x03], TestStruct(PB.OneOf(:var"#struct", TestInner(2, TestInner(3)))))
        end

        @testset "group message" begin
            test_decode_message([0x03, 0x0a, 0x03, 0x31, 0x32, 0x33, 0x04], TestStruct(PB.OneOf(:bytes, collect(b"123"))), Val{:group})
            test_decode_message([0x03, 0x10, 0x02, 0x04], TestStruct(PB.OneOf(:enum, TestEnum.C)), Val{:group})
            test_decode_message([0x03, 0x1a, 0x02, 0x08, 0x02, 0x04], TestStruct(PB.OneOf(:var"#struct", TestInner(2))), Val{:group})
            test_decode_message([0x03, 0x1a, 0x06, 0x08, 0x02, 0x12, 0x02, 0x08, 0x03, 0x04], TestStruct(PB.OneOf(:var"#struct", TestInner(2, TestInner(3)))), Val{:group})
        end
    end

    @testset "varint" begin
        @testset "uint32" begin
            test_decode([0x02], UInt32(2))
        end

        @testset "uint64" begin
            test_decode([0x02], UInt64(2))
        end

        @testset "int32" begin
            test_decode([0x02], Int32(2))
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int32(-1))
        end

        @testset "int64" begin
            test_decode([0x02], Int64(2))
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int64(-1))
        end

        @testset "bool" begin
            test_decode([0x01], true)
            # bools are varints: any nonzero value is true, e.g. an int32 field read as bool
            test_decode([0x02], true)
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], true)
            test_decode([0x80, 0x00], false)
        end

        @testset "sint32" begin
            test_decode([0x04], Int32(2), Val{:zigzag})
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0x0F], typemin(Int32), Val{:zigzag})
            test_decode([0xFE, 0xFF, 0xFF, 0xFF, 0x0F], typemax(Int32), Val{:zigzag})
        end

        @testset "sint64" begin
            test_decode([0x04], Int64(2), Val{:zigzag})
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], typemin(Int64), Val{:zigzag})
            test_decode([0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], typemax(Int64), Val{:zigzag})
        end

        @testset "enum" begin
            test_decode([0x02], TestEnum.C)
        end

        @testset "unknown enum member" begin
            test_decode([0x10], Core.bitcast(TestEnum.T, Int32(0x10)))
        end

        @testset "negative enum member" begin
            # Negative enum values are sign-extended to 10 bytes on the wire
            neg = Core.bitcast(TestEnum.T, Int32(-1))
            ten_bytes = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]
            test_decode(ten_bytes, neg)
            test_decode([ten_bytes; 0x01], [neg, TestEnum.B])
            @test decode(ProtoDecoder(IOBuffer([0x10; ten_bytes])), TestStruct).oneof[] === neg
        end

        @testset "skipped varint longer than 10 bytes" begin
            # unknown field 3 holding an 11-byte varint, then x = 5
            @test_throws ErrorException decode(ProtoDecoder(IOBuffer([0x18; fill(0x80, 10); 0x00; 0x08; 0x05])), TestInner)
        end
    end

    @testset "fixed" begin
        @testset "sfixed32" begin
            test_decode(reinterpret(UInt8, [Int32(2)]), Int32(2), Val{:fixed})
        end

        @testset "sfixed64" begin
            test_decode(reinterpret(UInt8, [Int64(2)]), Int64(2), Val{:fixed})
        end

        @testset "fixed32" begin
            test_decode(reinterpret(UInt8, [UInt32(2)]), UInt32(2), Val{:fixed})
        end

        @testset "fixed64" begin
            test_decode(reinterpret(UInt8, [UInt64(2)]), UInt64(2), Val{:fixed})
        end
    end

    @testset "truncated input" begin
        # bytes field (TestStruct.bytes = 1) claiming 5 bytes, 2 present
        @test_throws EOFError decode(ProtoDecoder(IOBuffer([0x0a, 0x05, 0x61, 0x62])), TestStruct)
        # unknown fields cut short: length-delimited, fixed64, fixed32
        @test_throws EOFError decode(ProtoDecoder(IOBuffer([0x2a, 0x0a, 0x61, 0x62])), TestInner)
        @test_throws EOFError decode(ProtoDecoder(IOBuffer([0x29, 0x01, 0x02])), TestInner)
        @test_throws EOFError decode(ProtoDecoder(IOBuffer([0x2d, 0x01])), TestInner)
        mktemp() do path, io
            write(io, UInt8[0x2a, 0x0a, 0x61, 0x62])
            seekstart(io)
            @test_throws EOFError decode(ProtoDecoder(io), TestInner)
        end
    end

    @testset "skipping" begin
        io = IOBuffer()
        d = PB.ProtoDecoder(io)
        e = PB.ProtoEncoder(io)
        PB.encode(e, 3, UInt32(42)) # VARINT
        PB.encode(e, 4, [UInt32(42)]) # LENGTH_DELIMITED
        PB.encode(e, 5, Float64(42)) # FIXED64
        PB.encode(e, 6, Float32(42)) # FIXED32
        write(io, 0x03) # START_GROUP
            PB.encode(e, 1, UInt32(42)) # VARINT
            PB.encode(e, 2, [UInt32(42)]) # LENGTH_DELIMITED
            PB.encode(e, 3, Float64(42)) # FIXED64
            PB.encode(e, 4, Float32(42)) # FIXED32
        write(io, 0x04) # END_GROUP
        write(io, 0x03) # START_GROUP
            write(io, 0x03) # START_GROUP
                PB.encode(e, 1, UInt32(42)) # VARINT
                PB.encode(e, 2, [UInt32(42)]) # LENGTH_DELIMITED
                PB.encode(e, 3, Float64(42)) # FIXED64
                PB.encode(e, 4, Float32(42)) # FIXED32
            write(io, 0x04) # END_GROUP
        write(io, 0x04) # END_GROUP
        seekstart(io)

        @test decode(d, TestInner) == TestInner(0)
    end

    @testset "backwards compat" begin
        OlderVersion = include(joinpath(test_dir, "test_protos", "test_decode_backwards_compat.jl"))
        msg = OlderVersion.TestInner(0, OlderVersion.TestInner(1, OlderVersion.TestInner(2, nothing)))
        io = IOBuffer()
        e = PB.ProtoEncoder(io)
        PB.encode(e, msg)
        roundtripped = PB.decode(PB.ProtoDecoder(seekstart(io)), OlderVersion.TestInner)
        @test roundtripped == msg
    end
end
end # module
