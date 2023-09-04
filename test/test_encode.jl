module TestEncode
using ProtoBuf: Codecs
import ProtoBuf as PB
using .Codecs: _with_size, encode, ProtoEncoder, WireType
using Test
using EnumX: @enumx

@enumx TestEnum A B C
struct TestInner
    x::Int
    r::Union{Nothing,TestInner}
end
TestInner(x::Int) = TestInner(x, nothing)
struct TestStruct{T<:Union{Nothing,PB.OneOf{<:Union{Vector{UInt8},TestEnum.T,TestInner}}}}
    oneof::T
end

function PB.encode(e::PB.AbstractProtoEncoder, x::TestInner)
    initpos = position(e.io)
    x.x != 0 && PB.encode(e, 1, x.x)
    !isnothing(x.r) && PB.encode(e, 2, x.r)
    return position(e.io) - initpos
end

function PB.encode(e::PB.AbstractProtoEncoder, x::TestStruct)
    initpos = position(e.io)
    if isnothing(x.oneof);
    elseif x.oneof.name == :bytes
        PB.encode(e, 1, x.oneof[])
    elseif x.oneof.name == :enum
        PB.encode(e, 2, x.oneof[])
    elseif x.oneof.name == :struct
        PB.encode(e, 3, x.oneof[])
    end
    return position(e.io) - initpos
end

function test_encode_struct(input::TestStruct, i, expected, V=nothing)
    d = ProtoEncoder(IOBuffer())
    is_group = !isnothing(V)
    if is_group
        encode(d, 0, input, V)
    else
        encode(d, input)
    end
    bytes = take!(d.io)
    if is_group
        @testset "group tags" begin
            @test first(bytes) == UInt8(Codecs.START_GROUP)
            @test last(bytes) == UInt8(Codecs.END_GROUP)
        end
        bytes = bytes[2:end-1]
    end
    tag = first(bytes)
    bytes = bytes[2:end]
    if !isa(input.oneof[], Enum)
        len = first(bytes)
        bytes = bytes[2:end]
        @testset "length" begin
            @test len == length(expected)
        end
        w = Codecs.LENGTH_DELIMITED
    else
        w = Codecs.VARINT
    end
    @testset "tag" begin
        @test tag >> 3 == i
        @test tag & 0x07 == Int(w)
    end
    @testset "encoded payload" begin
        @test bytes == expected
    end
end

function test_encode(input, i, w::WireType, expected, V::Type=Nothing)
    d = ProtoEncoder(IOBuffer())
    if V === Nothing
        encode(d, i, input)
    else
        encode(d, i, input, V)
    end
    bytes = take!(d.io)
    if (isa(input, AbstractVector) && eltype(input) <: Union{Vector{UInt8}, String, TestInner}) || isa(input, AbstractDict)
        j = 1
        while !isempty(bytes)
            tag = bytes[1]
            len = bytes[2]
            elbytes = bytes[3:len+2]
            bytes = bytes[3+len:end]

            extag = expected[1]
            exlen = expected[2]
            elexpected = expected[3:len+2]
            expected = expected[3+len:end]
            @testset "length $j" begin
                @test len == exlen
            end
            @testset "tag $j" begin
                @test ((tag >> 3) == (extag >> 3)) & ((tag >> 3) == i)
                @test ((tag & 0x07) == (extag & 0x07)) & ((tag & 0x07) == Int(w))
            end
            @testset "encoded payload $j" begin
                @test elbytes == elexpected
            end
            j += 1
        end
    else
        tag = first(bytes)
        bytes = bytes[2:end]
        if w == Codecs.LENGTH_DELIMITED
            len = first(bytes)
            bytes = bytes[2:end]
            @testset "length" begin
                @test len == length(expected)
            end
        end
        @testset "tag" begin
            @test tag >> 3 == i
            @test tag & 0x07 == Int(w)
        end
        @testset "encoded payload" begin
            @test bytes == expected
        end
    end
end

@testset "encode" begin
    @testset "length delimited" begin
        @testset "bytes" begin
            test_encode(b"123456789", 2, Codecs.LENGTH_DELIMITED, b"123456789")
            test_encode(b"", 2, Codecs.LENGTH_DELIMITED, b"")
        end

        @testset "string" begin
            test_encode("123456789", 2, Codecs.LENGTH_DELIMITED, b"123456789")
            test_encode("", 2, Codecs.LENGTH_DELIMITED, b"")
        end

        @testset "repeated bytes" begin
            test_encode([[0x31, 0x32], [0x33, 0x34]], 2, Codecs.LENGTH_DELIMITED, [0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34])
        end

        @testset "repeated string" begin
            test_encode(["12", "34"], 2, Codecs.LENGTH_DELIMITED, [0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34])
        end

        @testset "repeated uint32" begin
            test_encode(UInt32[1, 2], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
        end

        @testset "repeated uint64" begin
            test_encode(UInt64[1, 2], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
        end

        @testset "repeated int32" begin
            test_encode(Int32[1, 2], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
            test_encode(Int32[-1], 2, Codecs.LENGTH_DELIMITED, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        end

        @testset "repeated enum" begin
            test_encode([TestEnum.B, TestEnum.C], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
        end

        @testset "repeated int64" begin
            test_encode(Int64[1, 2], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
            test_encode(Int64[-1], 2, Codecs.LENGTH_DELIMITED, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        end

        @testset "repeated bool" begin
            test_encode(Bool[false, true, false], 2, Codecs.LENGTH_DELIMITED, [0x00, 0x01, 0x00])
        end

        @testset "repeated float64" begin
            test_encode(Float64[1.0, 2.0], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, Float64[1.0, 2.0]))
        end

        @testset "repeated float32" begin
            test_encode(Float32[1.0, 2.0], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, Float32[1.0, 2.0]))
        end

        @testset "repeated sfixed32" begin
            test_encode(Int32[1, 2], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, Int32[1, 2]), Val{:fixed})
        end

        @testset "repeated sfixed64" begin
            test_encode(Int64[1, 2], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, Int64[1, 2]), Val{:fixed})
        end

        @testset "repeated fixed32" begin
            test_encode(UInt32[1, 2], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, UInt32[1, 2]), Val{:fixed})
        end

        @testset "repeated fixed64" begin
            test_encode(UInt64[1, 2], 2, Codecs.LENGTH_DELIMITED, reinterpret(UInt8, UInt64[1, 2]), Val{:fixed})
        end

        @testset "repeated sint32" begin
            test_encode(Int32[1, 2, -1, -2], 2, Codecs.LENGTH_DELIMITED, [0x02, 0x04, 0x01, 0x03], Val{:zigzag})
        end

        @testset "repeated sint64" begin
            test_encode(Int64[1, 2, -1, -2], 2, Codecs.LENGTH_DELIMITED, [0x02, 0x04, 0x01, 0x03], Val{:zigzag})
        end

        @testset "repeated message" begin
            test_encode([TestInner(3), TestInner(4)], 2, Codecs.LENGTH_DELIMITED, [0x12, 0x02, 0x08, 0x03, 0x12, 0x02, 0x08, 0x04])
        end

        @testset "map" begin
            @testset "string,string" begin test_encode(Dict{String,String}("b" => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x06, 0x0a, 0x01, 0x62, 0x12, 0x01, 0x61]) end
            @testset "multiple string,string" begin test_encode(Dict{String,String}("b" => "a", "c" => "d"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x06, 0x0a, 0x01, 0x63, 0x12, 0x01, 0x64, 0x12, 0x06, 0x0a, 0x01, 0x62, 0x12, 0x01, 0x61]) end

            @testset "int32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "int64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "uint32,string" begin test_encode(Dict{UInt32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "uint64,string" begin test_encode(Dict{UInt64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "bool,string" begin test_encode(Dict{Bool,String}(true => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x01, 0x12, 0x01, 0x61]) end

            @testset "sfixed32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x08, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "sfixed64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0c, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed32,string" begin test_encode(Dict{UInt32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x08, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed64,string" begin test_encode(Dict{UInt64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0c, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end

            @testset "sint32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x02, 0x12, 0x01, 0x61], Val{Tuple{:zigzag,Nothing}}) end
            @testset "sint64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x08, 0x02, 0x12, 0x01, 0x61], Val{Tuple{:zigzag,Nothing}}) end

            @testset "string,int32" begin test_encode(Dict{String,Int32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,int64" begin test_encode(Dict{String,Int64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,uint32" begin test_encode(Dict{String,UInt32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,uint64" begin test_encode(Dict{String,UInt64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,bool" begin test_encode(Dict{String,Bool}("a" => true), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x05, 0x0a, 0x01, 0x61, 0x10, 0x01]) end

            @testset "string,sfixed32" begin test_encode(Dict{String,Int32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x08, 0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,sfixed64" begin test_encode(Dict{String,Int64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0c, 0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed32" begin test_encode(Dict{String,UInt32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x08, 0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed64" begin test_encode(Dict{String,UInt64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0c, 0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end

            @testset "sfixed32,sfixed32" begin test_encode(Dict{Int32,Int32}(1 => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0a, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{:fixed,:fixed}}) end
            @testset "sfixed64,sfixed64" begin test_encode(Dict{Int64,Int64}(1 => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x12, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed32,fixed32" begin test_encode(Dict{UInt32,UInt32}(1 => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x0a, 0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed64,fixed64" begin test_encode(Dict{UInt64,UInt64}(1 => 1), 2, Codecs.LENGTH_DELIMITED, [0x12, 0x12, 0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{:fixed,:fixed}}) end
        end

        @testset "message" begin
            test_encode_struct(TestStruct(PB.OneOf(:bytes, collect(b"123"))), 1, b"123")
            test_encode_struct(TestStruct(PB.OneOf(:enum, TestEnum.C)), 2, [0x02])
            test_encode_struct(TestStruct(PB.OneOf(:struct, TestInner(2))), 3, [0x08, 0x02])
            test_encode_struct(TestStruct(PB.OneOf(:struct, TestInner(2, TestInner(3)))), 3, [0x08, 0x02, 0x12, 0x02, 0x08, 0x03])
        end

        @testset "group message" begin
            test_encode_struct(TestStruct(PB.OneOf(:bytes, collect(b"123"))), 1, b"123", Val{:group})
            test_encode_struct(TestStruct(PB.OneOf(:enum, TestEnum.C)), 2, [0x02], Val{:group})
            test_encode_struct(TestStruct(PB.OneOf(:struct, TestInner(2))), 3, [0x08, 0x02], Val{:group})
            test_encode_struct(TestStruct(PB.OneOf(:struct, TestInner(2, TestInner(3)))), 3, [0x08, 0x02, 0x12, 0x02, 0x08, 0x03], Val{:group})
        end
    end

    @testset "varint" begin
        @testset "uint32" begin
            test_encode(UInt32(2), 2, Codecs.VARINT, [0x02])
        end

        @testset "uint64" begin
            test_encode(UInt64(2), 2, Codecs.VARINT, [0x02])
        end

        @testset "int32" begin
            test_encode(Int32(2), 2, Codecs.VARINT, [0x02])
            test_encode(Int32(-1), 2, Codecs.VARINT, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        end

        @testset "enum" begin
            test_encode(TestEnum.C, 2, Codecs.VARINT, [0x02])
        end

        @testset "int64" begin
            test_encode(Int64(2), 2, Codecs.VARINT, [0x02])
            test_encode(Int64(-1), 2, Codecs.VARINT, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01])
        end

        @testset "bool" begin
            test_encode(true, 2, Codecs.VARINT, [0x01])
        end

        @testset "sint32" begin
            test_encode(Int32(2), 2, Codecs.VARINT, [0x04], Val{:zigzag})
            test_encode(typemax(Int32), 2, Codecs.VARINT, [0xFE, 0xFF, 0xFF, 0xFF, 0x0F], Val{:zigzag})
            test_encode(typemin(Int32), 2, Codecs.VARINT, [0xFF, 0xFF, 0xFF, 0xFF, 0x0F], Val{:zigzag})
        end

        @testset "sint64" begin
            test_encode(Int64(2), 2, Codecs.VARINT, [0x04], Val{:zigzag})
            test_encode(typemax(Int64), 2, Codecs.VARINT, [0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Val{:zigzag})
            test_encode(typemin(Int64), 2, Codecs.VARINT, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Val{:zigzag})
        end
    end

    @testset "fixed" begin
        @testset "sfixed32" begin
            test_encode(Int32(2), 2, Codecs.FIXED32, reinterpret(UInt8, [Int32(2)]), Val{:fixed})
        end

        @testset "sfixed64" begin
            test_encode(Int64(2), 2, Codecs.FIXED64, reinterpret(UInt8, [Int64(2)]), Val{:fixed})
        end

        @testset "fixed32" begin
            test_encode(UInt32(2), 2, Codecs.FIXED32, reinterpret(UInt8, [UInt32(2)]), Val{:fixed})
        end

        @testset "fixed64" begin
            test_encode(UInt64(2), 2, Codecs.FIXED64, reinterpret(UInt8, [UInt64(2)]), Val{:fixed})
        end
    end
end
end # module

module TestEncodedSize
using Test
using ProtoBuf: _encoded_size
import ProtoBuf as PB
using ProtoBuf: Codecs

using EnumX
@enumx TestEnum DEFAULT=0 OTHER=1

struct EmptyMessage end
PB._encoded_size(x::EmptyMessage) = 0

abstract type var"##AbstractNonEmptyMessage" end
struct NonEmptyMessage <: var"##AbstractNonEmptyMessage"
    x::UInt32
    self_referential_field::Union{Nothing,NonEmptyMessage}
end
function PB._encoded_size(x::NonEmptyMessage)
    encoded_size = 0
    x.x != zero(UInt32) && (encoded_size += PB._encoded_size(x.x, 1))
    !isnothing(x.self_referential_field) && (encoded_size += PB._encoded_size(x.self_referential_field, 2))
    return encoded_size
end

@testset "_with_size" begin
    io = IOBuffer()
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6])
    @test take!(io) == UInt8[6, 1, 2, 3, 4, 5, 6]

    io = IOBuffer()
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6], Val{:zigzag})
    @test take!(io) == UInt8[6, 2, 4, 6, 8, 10, 12]

    io = IOBuffer(zeros(UInt8, 7), maxsize=7, read=false, write=true)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6])
    @test io.data == UInt8[6, 1, 2, 3, 4, 5, 6]

    io = IOBuffer(zeros(UInt8, 7), maxsize=7, read=false, write=true)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6], Val{:zigzag})
    @test io.data == UInt8[6, 2, 4, 6, 8, 10, 12]

    io = IOBuffer(;maxsize=2^14 + 1)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6])
    @test take!(io) == UInt8[6, 1, 2, 3, 4, 5, 6]

    io = IOBuffer(;maxsize=2^14 + 1)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6], Val{:zigzag})
    @test take!(io) == UInt8[6, 2, 4, 6, 8, 10, 12]

    io = IOBuffer(;maxsize=2^21 + 1)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6])
    @test take!(io) == UInt8[6, 1, 2, 3, 4, 5, 6]

    io = IOBuffer(;maxsize=2^21 + 1)
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6], Val{:zigzag})
    @test take!(io) == UInt8[6, 2, 4, 6, 8, 10, 12]

    io = PipeBuffer()
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6])
    @test take!(io) == UInt8[6, 1, 2, 3, 4, 5, 6]

    io = PipeBuffer()
    Codecs._with_size(Codecs._encode, io, io, [1, 2, 3, 4, 5, 6], Val{:zigzag})
    @test take!(io) == UInt8[6, 2, 4, 6, 8, 10, 12]
end

@testset "_encoded_size" begin
    @test _encoded_size(nothing) == 0
    @test _encoded_size(UInt8[0xff]) == 1
    @test _encoded_size(UInt8[]) == 0
    @test _encoded_size("S") == 1
    @test _encoded_size("") == 0
    @test _encoded_size(typemax(UInt32)) == 5
    @test _encoded_size(typemax(UInt64)) == 10
    @test _encoded_size(typemax(Int32)) == 5
    @test _encoded_size(typemax(Int64)) == 9
    @test _encoded_size(true) == 1
    @test _encoded_size(typemax(Int32), Val{:zigzag}) == 5
    @test _encoded_size(typemax(Int64), Val{:zigzag}) == 10
    @test _encoded_size(typemax(Int32), Val{:zigzag}) == 5
    @test _encoded_size(typemax(Int64), Val{:zigzag}) == 10
    @test _encoded_size(TestEnum.OTHER) == 1
    @test _encoded_size(typemax(Int32), Val{:fixed}) == 4
    @test _encoded_size(typemax(Int64), Val{:fixed}) == 8
    @test _encoded_size(typemax(UInt32), Val{:fixed}) == 4
    @test _encoded_size(typemax(UInt64), Val{:fixed}) == 8
    @test _encoded_size(EmptyMessage()) == 0
    #                                                                                                    T   D     T    L    T   D
    @test _encoded_size(NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))) == (1 + 5) + (1 + (1 + (1 + 5)))
    @test _encoded_size([UInt8[0xff]]) == 2
    @test _encoded_size(["S"]) == 2
    @test _encoded_size([typemax(UInt32)]) == 5
    @test _encoded_size([typemax(UInt64)]) == 10
    @test _encoded_size([typemax(Int32)]) == 5
    @test _encoded_size([typemax(Int64)]) == 9
    @test _encoded_size([true]) == 1
    @test _encoded_size([typemax(Int32)], Val{:zigzag}) == 5
    @test _encoded_size([typemax(Int64)], Val{:zigzag}) == 10
    @test _encoded_size([typemin(Int32)], Val{:zigzag}) == 5
    @test _encoded_size([typemax(Int64)], Val{:zigzag}) == 10
    @test _encoded_size([TestEnum.OTHER]) == 1
    @test _encoded_size([typemax(Int32)], Val{:fixed}) == 4
    @test _encoded_size([typemax(Int64)], Val{:fixed}) == 8
    @test _encoded_size([typemax(UInt32)], Val{:fixed}) == 4
    @test _encoded_size([typemax(UInt64)], Val{:fixed}) == 8
    @test _encoded_size([EmptyMessage()]) == 1
    @test _encoded_size([EmptyMessage(), EmptyMessage()]) == 2
    @test _encoded_size([EmptyMessage(), EmptyMessage()], 1) == 4
    #                                                                                                     L    T   D     T    L    T   D
    @test _encoded_size([NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))]) == 1 + (1 + 5) + (1 + (1 + (1 + 5)))
    #                                                                                                                  S    T   D     T    L    T   D      E
    @test _encoded_size([NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))], Val{:group}) == 1 + (1 + 5) + (1 + (1 + (1 + 5))) + 1
    #                                                  T   L   D     T   L   D
    @test _encoded_size(Dict("K" => UInt8[0xff]))    == ((1 + 1 + 1) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict("K" => UInt8[0xff]), 1) == ((1 + 1 + 1) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict("K" => "S"))            == ((1 + 1 + 1) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict("K" => "S"), 1)         == ((1 + 1 + 1) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict("KEY" => "STR"))        == ((1 + 1 + 3) + (1 + 1 + 3)) + 1
    @test _encoded_size(Dict("KEY" => "STR"), 1)     == ((1 + 1 + 3) + (1 + 1 + 3)) + 2
    @test _encoded_size(Dict("KEY1" => "STR1", "KEY2" => "STR2"))       == 2 * (((1 + 1 + 4) + (1 + 1 + 4)) + 1)
    @test _encoded_size(Dict("KEY1" => "STR1", "KEY2" => "STR2"), 1)    == 2 * (((1 + 1 + 4) + (1 + 1 + 4)) + 2)
    @test _encoded_size(Dict("KEY1" => "STR1", "KEY2" => "STR2"), 128)  == 2 * (((1 + 1 + 4) + (1 + 1 + 4)) + 3)
    #                                                      T   L   D     T    D
    @test _encoded_size(Dict("K" => typemax(UInt32)))    == ((1 + 1 + 1) + (1 +  5)) + 1
    @test _encoded_size(Dict("K" => typemax(UInt32)), 1) == ((1 + 1 + 1) + (1 +  5)) + 2
    @test _encoded_size(Dict("K" => typemax(UInt64)))    == ((1 + 1 + 1) + (1 + 10)) + 1
    @test _encoded_size(Dict("K" => typemax(UInt64)), 1) == ((1 + 1 + 1) + (1 + 10)) + 2
    @test _encoded_size(Dict("K" => typemax(Int32)))     == ((1 + 1 + 1) + (1 +  5)) + 1
    @test _encoded_size(Dict("K" => typemax(Int32)), 1)  == ((1 + 1 + 1) + (1 +  5)) + 2
    @test _encoded_size(Dict("K" => typemax(Int64)))     == ((1 + 1 + 1) + (1 +  9)) + 1
    @test _encoded_size(Dict("K" => typemax(Int64)), 1)  == ((1 + 1 + 1) + (1 +  9)) + 2
    @test _encoded_size(Dict("K" => true))               == ((1 + 1 + 1) + (1 +  1)) + 1
    @test _encoded_size(Dict("K" => true), 1)            == ((1 + 1 + 1) + (1 +  1)) + 2
    @test _encoded_size(Dict("K" => typemax(Int32)), Val{Tuple{Nothing,:zigzag}})    == ((1 + 1 + 1) + (1 +  5)) + 1
    @test _encoded_size(Dict("K" => typemax(Int32)), 1, Val{Tuple{Nothing,:zigzag}}) == ((1 + 1 + 1) + (1 +  5)) + 2
    @test _encoded_size(Dict("K" => typemax(Int64)), Val{Tuple{Nothing,:zigzag}})    == ((1 + 1 + 1) + (1 + 10)) + 1
    @test _encoded_size(Dict("K" => typemax(Int64)), 1, Val{Tuple{Nothing,:zigzag}}) == ((1 + 1 + 1) + (1 + 10)) + 2
    @test _encoded_size(Dict("K" => typemin(Int32)), Val{Tuple{Nothing,:zigzag}})    == ((1 + 1 + 1) + (1 +  5)) + 1
    @test _encoded_size(Dict("K" => typemin(Int32)), 1, Val{Tuple{Nothing,:zigzag}}) == ((1 + 1 + 1) + (1 +  5)) + 2
    @test _encoded_size(Dict("K" => typemin(Int64)), Val{Tuple{Nothing,:zigzag}})    == ((1 + 1 + 1) + (1 + 10)) + 1
    @test _encoded_size(Dict("K" => typemin(Int64)), 1, Val{Tuple{Nothing,:zigzag}}) == ((1 + 1 + 1) + (1 + 10)) + 2
    @test _encoded_size(Dict("K" => TestEnum.OTHER))     == ((1 + 1 + 1) + (1 +  1)) + 1
    @test _encoded_size(Dict("K" => TestEnum.OTHER), 1)  == ((1 + 1 + 1) + (1 +  1)) + 2

    @test _encoded_size(Dict("K" => typemax(UInt32)), Val{Tuple{Nothing,:fixed}})    == ((1 + 1 + 1) + (1 + 4)) + 1
    @test _encoded_size(Dict("K" => typemax(UInt32)), 1, Val{Tuple{Nothing,:fixed}}) == ((1 + 1 + 1) + (1 + 4)) + 2
    @test _encoded_size(Dict("K" => typemax(UInt64)), Val{Tuple{Nothing,:fixed}})    == ((1 + 1 + 1) + (1 + 8)) + 1
    @test _encoded_size(Dict("K" => typemax(UInt64)), 1, Val{Tuple{Nothing,:fixed}}) == ((1 + 1 + 1) + (1 + 8)) + 2
    @test _encoded_size(Dict("K" => typemax(Int32)),  Val{Tuple{Nothing,:fixed}})    == ((1 + 1 + 1) + (1 + 4)) + 1
    @test _encoded_size(Dict("K" => typemax(Int32)),  1, Val{Tuple{Nothing,:fixed}}) == ((1 + 1 + 1) + (1 + 4)) + 2
    @test _encoded_size(Dict("K" => typemax(Int64)),  Val{Tuple{Nothing,:fixed}})    == ((1 + 1 + 1) + (1 + 8)) + 1
    @test _encoded_size(Dict("K" => typemax(Int64)),  1, Val{Tuple{Nothing,:fixed}}) == ((1 + 1 + 1) + (1 + 8)) + 2

    @test _encoded_size(Dict("K" => EmptyMessage()))    == ((1 + 1 + 1) + (1 + 1 + 0)) + 1
    @test _encoded_size(Dict("K" => EmptyMessage()), 1) == ((1 + 1 + 1) + (1 + 1 + 0)) + 2
    #                                                                                                                     T   L   D      T   L     T   D    T    L    T   D
    @test _encoded_size(Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))))    == ((1 + 1 + 1) + (1 + 1 + (1 + 5) + (1 + (1 + (1 + 5))))) + 1
    @test _encoded_size(Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))), 1) == ((1 + 1 + 1) + (1 + 1 + (1 + 5) + (1 + (1 + (1 + 5))))) + 2
    #                                                      T    D     T   L   D    TH
    @test _encoded_size(Dict(typemax(UInt32) => "V"))    == ((1 +  5) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(UInt32) => "V"), 1) == ((1 +  5) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(UInt64) => "V"))    == ((1 + 10) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(UInt64) => "V"), 1) == ((1 + 10) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int32) => "V"))     == ((1 +  5) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int32) => "V"), 1)  == ((1 +  5) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int64) => "V"))     == ((1 +  9) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int64) => "V"), 1)  == ((1 +  9) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(true => "V"))               == ((1 +  1) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(true => "V"), 1)            == ((1 +  1) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})    == ((1 +  5) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int32) => "V"), 1, Val{Tuple{:zigzag,Nothing}}) == ((1 +  5) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})    == ((1 + 10) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int64) => "V"), 1, Val{Tuple{:zigzag,Nothing}}) == ((1 + 10) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemin(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})    == ((1 +  5) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemin(Int32) => "V"), 1, Val{Tuple{:zigzag,Nothing}}) == ((1 +  5) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemin(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})    == ((1 + 10) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemin(Int64) => "V"), 1, Val{Tuple{:zigzag,Nothing}}) == ((1 + 10) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(TestEnum.OTHER => "V"))     == ((1 +  1) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(TestEnum.OTHER => "V"), 1)  == ((1 +  1) + (1 + 1 + 1)) + 2

    @test _encoded_size(Dict(typemax(UInt32) => "V"), Val{Tuple{:fixed,Nothing}})    == ((1 + 4) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(UInt32) => "V"), 1, Val{Tuple{:fixed,Nothing}}) == ((1 + 4) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(UInt64) => "V"), Val{Tuple{:fixed,Nothing}})    == ((1 + 8) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(UInt64) => "V"), 1, Val{Tuple{:fixed,Nothing}}) == ((1 + 8) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int32) => "V"),  Val{Tuple{:fixed,Nothing}})    == ((1 + 4) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int32) => "V"), 1,  Val{Tuple{:fixed,Nothing}}) == ((1 + 4) + (1 + 1 + 1)) + 2
    @test _encoded_size(Dict(typemax(Int64) => "V"),  Val{Tuple{:fixed,Nothing}})    == ((1 + 8) + (1 + 1 + 1)) + 1
    @test _encoded_size(Dict(typemax(Int64) => "V"), 1,  Val{Tuple{:fixed,Nothing}}) == ((1 + 8) + (1 + 1 + 1)) + 2

    @test _encoded_size(Dict(typemax(UInt32) => typemax(UInt32)), Val{Tuple{:fixed,:fixed}})    == ((1 + 4) + (1 + 4)) + 1
    @test _encoded_size(Dict(typemax(UInt32) => typemax(UInt32)), 1, Val{Tuple{:fixed,:fixed}}) == ((1 + 4) + (1 + 4)) + 2
    @test _encoded_size(Dict(typemax(UInt64) => typemax(UInt64)), Val{Tuple{:fixed,:fixed}})    == ((1 + 8) + (1 + 8)) + 1
    @test _encoded_size(Dict(typemax(UInt64) => typemax(UInt64)), 1, Val{Tuple{:fixed,:fixed}}) == ((1 + 8) + (1 + 8)) + 2
    @test _encoded_size(Dict(typemax(Int32) => typemax(Int32)),  Val{Tuple{:fixed,:fixed}})    == ((1 + 4) + (1 + 4)) + 1
    @test _encoded_size(Dict(typemax(Int32) => typemax(Int32)),  1, Val{Tuple{:fixed,:fixed}}) == ((1 + 4) + (1 + 4)) + 2
    @test _encoded_size(Dict(typemax(Int64) => typemax(Int64)),  Val{Tuple{:fixed,:fixed}})    == ((1 + 8) + (1 + 8)) + 1
    @test _encoded_size(Dict(typemax(Int64) => typemax(Int64)),  1, Val{Tuple{:fixed,:fixed}}) == ((1 + 8) + (1 + 8)) + 2

    @test _encoded_size(Dict(typemax(Int32) => typemax(Int32)), Val{Tuple{:zigzag,:zigzag}})    == ((1 +  5) + (1 +  5)) + 1
    @test _encoded_size(Dict(typemax(Int32) => typemax(Int32)), 1, Val{Tuple{:zigzag,:zigzag}}) == ((1 +  5) + (1 +  5)) + 2
    @test _encoded_size(Dict(typemax(Int64) => typemax(Int64)), Val{Tuple{:zigzag,:zigzag}})    == ((1 + 10) + (1 + 10)) + 1
    @test _encoded_size(Dict(typemax(Int64) => typemax(Int64)), 1, Val{Tuple{:zigzag,:zigzag}}) == ((1 + 10) + (1 + 10)) + 2
    @test _encoded_size(Dict(typemin(Int32) => typemax(Int32)), Val{Tuple{:zigzag,:zigzag}})    == ((1 +  5) + (1 +  5)) + 1
    @test _encoded_size(Dict(typemin(Int32) => typemax(Int32)), 1, Val{Tuple{:zigzag,:zigzag}}) == ((1 +  5) + (1 +  5)) + 2
    @test _encoded_size(Dict(typemin(Int64) => typemax(Int64)), Val{Tuple{:zigzag,:zigzag}})    == ((1 + 10) + (1 + 10)) + 1
    @test _encoded_size(Dict(typemin(Int64) => typemax(Int64)), 1, Val{Tuple{:zigzag,:zigzag}}) == ((1 + 10) + (1 + 10)) + 2

    @test _encoded_size(typemax(Float32)) == 4
    @test _encoded_size(typemax(Float64)) == 8
    @test _encoded_size([typemax(Float32)]) == 4
    @test _encoded_size([typemax(Float64)]) == 8
    @test _encoded_size(Dict("K" => typemax(Float32)))    == ((1 + 1 + 1) + (1 + 4)) + 1
    @test _encoded_size(Dict("K" => typemax(Float32)), 1) == ((1 + 1 + 1) + (1 + 4)) + 2
    @test _encoded_size(Dict("K" => typemax(Float64)))    == ((1 + 1 + 1) + (1 + 8)) + 1
    @test _encoded_size(Dict("K" => typemax(Float64)), 1) == ((1 + 1 + 1) + (1 + 8)) + 2
end
end # module
