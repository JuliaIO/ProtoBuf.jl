import ProtocolBuffers as PB
using ProtocolBuffers: Codecs
using .Codecs: encode, ProtoEncoder, WireType
using Test
using EnumX: @enumx


# Without this, we'll get an invalid redefinition when re-running this file
if !isdefined(@__MODULE__, :EncodeTestEnum)
    @enumx EncodeTestEnum A B C
end
if !isdefined(@__MODULE__, :EncodeTestStruct)
    struct EncodeTestStruct{T<:Union{Vector{UInt8},EncodeTestEnum.T}}
        oneof::PB.OneOf{T}
    end
end

function PB.encode(e::PB.ProtoEncoder, x::EncodeTestStruct)
    initpos = position(e.io)
    if isnothing(x.oneof);
    elseif x.oneof.name == :bytes
        PB.encode(e, 1, x.oneof[])
    elseif x.oneof.name == :enum
        PB.encode(e, 2, x.oneof[])
    end
    return position(e.io) - initpos
end


function test_encode_struct(input::EncodeTestStruct, i, expected)
    d = ProtoEncoder(IOBuffer())
    encode(d, input)
    bytes = take!(d.io)
    tag = first(bytes)
    bytes = bytes[2:end]
    if isa(input.oneof[], AbstractVector)
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
            test_encode([EncodeTestEnum.B, EncodeTestEnum.C], 2, Codecs.LENGTH_DELIMITED, [0x01, 0x02])
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

        @testset "map" begin
            @testset "string,string" begin test_encode(Dict{String,String}("b" => "a"), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x62, 0x12, 0x01, 0x61]) end

            @testset "int32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "int64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "uint32,string" begin test_encode(Dict{UInt32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "uint64,string" begin test_encode(Dict{UInt64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x01, 0x12, 0x01, 0x61]) end
            @testset "bool,string" begin test_encode(Dict{Bool,String}(true => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x01, 0x12, 0x01, 0x61]) end

            @testset "sfixed32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "sfixed64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed32,string" begin test_encode(Dict{UInt32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed64,string" begin test_encode(Dict{UInt64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Val{Tuple{:fixed,Nothing}}) end

            @testset "sint32,string" begin test_encode(Dict{Int32,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x02, 0x12, 0x01, 0x61], Val{Tuple{:zigzag,Nothing}}) end
            @testset "sint64,string" begin test_encode(Dict{Int64,String}(1 => "a"), 2, Codecs.LENGTH_DELIMITED, [0x08, 0x02, 0x12, 0x01, 0x61], Val{Tuple{:zigzag,Nothing}}) end

            @testset "string,int32" begin test_encode(Dict{String,Int32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,int64" begin test_encode(Dict{String,Int64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,uint32" begin test_encode(Dict{String,UInt32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,uint64" begin test_encode(Dict{String,UInt64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x10, 0x01]) end
            @testset "string,bool" begin test_encode(Dict{String,Bool}("a" => true), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x10, 0x01]) end

            @testset "string,sfixed32" begin test_encode(Dict{String,Int32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,sfixed64" begin test_encode(Dict{String,Int64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed32" begin test_encode(Dict{String,UInt32}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed64" begin test_encode(Dict{String,UInt64}("a" => 1), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end

            @testset "string,repeated int32" begin test_encode(Dict{String,Vector{Int32}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x01]) end
            @testset "string,repeated int64" begin test_encode(Dict{String,Vector{Int64}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x01]) end
            @testset "string,repeated uint32" begin test_encode(Dict{String,Vector{UInt32}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x01]) end
            @testset "string,repeated uint64" begin test_encode(Dict{String,Vector{UInt64}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x01]) end
            @testset "string,repeated bool" begin test_encode(Dict{String,Vector{Bool}}("a" => [true]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x01]) end

            @testset "string,repeated sfixed32" begin test_encode(Dict{String,Vector{Int32}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x04, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated sfixed64" begin test_encode(Dict{String,Vector{Int64}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated fixed32" begin test_encode(Dict{String,Vector{UInt32}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x04, 0x01, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated fixed64" begin test_encode(Dict{String,Vector{UInt64}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Val{Tuple{Nothing,:fixed}}) end

            @testset "string,repeated sint32" begin test_encode(Dict{String,Vector{Int32}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x02], Val{Tuple{Nothing,:zigzag}}) end
            @testset "string,repeated sint64" begin test_encode(Dict{String,Vector{Int64}}("a" => [1]), 2, Codecs.LENGTH_DELIMITED, [0x0a, 0x01, 0x61, 0x12, 0x01, 0x02], Val{Tuple{Nothing,:zigzag}}) end
        end

        @testset "message" begin
            test_encode_struct(EncodeTestStruct(PB.OneOf(:bytes, collect(b"123"))), 1, b"123")
            test_encode_struct(EncodeTestStruct(PB.OneOf(:enum, EncodeTestEnum.C)), 2, [0x02])
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
            test_encode(EncodeTestEnum.C, 2, Codecs.VARINT, [0x02])
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
        end

        @testset "sint64" begin
            test_encode(Int64(2), 2, Codecs.VARINT, [0x04], Val{:zigzag})
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