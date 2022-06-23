using ProtocolBuffers: Codecs
using .Codecs: decode, decode!, ProtoDecoder, BufferedVector
using Test

tag_from_type(x::T,       V::Type{Val{:zigzag}}) where {T<:Union{Int32,Int64}}                    = Codecs.VARINT
tag_from_type(x::T,       V::Type{Nothing})      where {T<:Union{UInt32,UInt64,Int64,Int32,Bool}} = Codecs.VARINT
tag_from_type(x::T,       V::Type{Val{:fixed}})  where {T<:Union{UInt32,Int32}}                   = Codecs.FIXED32
tag_from_type(x::Float32, V::Type{Nothing})                                                       = Codecs.FIXED32
tag_from_type(x::T,       V::Type{Val{:fixed}})  where {T<:Union{UInt64,Int64}}                   = Codecs.FIXED64
tag_from_type(x::Float64, V::Type{Nothing})                                                       = Codecs.FIXED64
tag_from_type(x::AbstractVector,  V::Type)                                                        = Codecs.LENGTH_DELIMITED
tag_from_type(x::Dict,    V::Type)                                                                = Codecs.LENGTH_DELIMITED
tag_from_type(x::String,  V::Type)                                                                = Codecs.LENGTH_DELIMITED

function test_decode(input_bytes, expected, V::Type=Nothing)
    w = tag_from_type(expected, V)
    input_bytes = collect(input_bytes)
    @info input_bytes
    if w == Codecs.LENGTH_DELIMITED
        input_bytes = vcat(UInt8(length(input_bytes)), input_bytes)
    end

    e = ProtoDecoder(PipeBuffer(input_bytes))
    if V === Nothing
        if isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x)
            x = x[]
        else
            x = decode(e, typeof(expected))
        end
    else
        if isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x, V)
            x = x[]
        else
            x = decode(e, typeof(expected), V)
        end
    end

    @test x == expected
end

@testset "encode" begin
    @testset "length delimited" begin
        @testset "bytes" begin
            test_decode(b"123456789", b"123456789")
        end

        @testset "string" begin
            test_decode(b"123456789", b"123456789")
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

        @testset "repeated int64" begin
            test_decode([0x01, 0x02], Int64[1, 2])
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int64[-1])
        end

        @testset "repeated bool" begin
            test_decode([0x00, 0x01, 0x00], Bool[false, true, false])
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

        @testset "map"

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
        end

        @testset "sint32" begin
            test_decode([0x04], Int32(2), Val{:zigzag})
        end

        @testset "sint64" begin
            test_decode([0x04], Int64(2), Val{:zigzag})
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
end