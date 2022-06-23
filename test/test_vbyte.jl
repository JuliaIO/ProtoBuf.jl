using ProtocolBuffers: Codecs
using .Codecs: vbyte_decode, vbyte_encode
using Test

test_decode(bytes, expected) = @test vbyte_decode(PipeBuffer(bytes), typeof(unsigned(expected))) == unsigned(expected)
test_encode(input, expected) = (io = IOBuffer(); vbyte_encode(io, unsigned(input)); @test take!(io) == expected)
test_roundtrip(input) = (io = PipeBuffer(); vbyte_encode(io, unsigned(input)); @test vbyte_decode(io, typeof(unsigned(input))) == input)

@testset "vbyte decode" begin
    @testset "UInt32" begin
        test_decode(UInt8[0x00], UInt32(0))
        test_decode(UInt8[0x01], UInt32(1))
        test_decode(UInt8[0x80, 0x01], UInt32(128))
        test_decode(UInt8[0x80, 0x80, 0x01], UInt32(1) << 14)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x01], UInt32(1) << 21)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x01], UInt32(1) << 28)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x08], UInt32(1) << 31)

        # For robustness, UInt32 should be able to decode UInt64 varints
        # truncating to UInt32
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x88, 0x00], UInt32(1) << 31)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x88, 0x80, 0x00], UInt32(1) << 31)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x88, 0x80, 0x80, 0x00], UInt32(1) << 31)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x88, 0x80, 0x80, 0x80, 0x00], UInt32(1) << 31)
        test_decode(UInt8[0xaa, 0xaa, 0xaa, 0xaa, 0x2a, 0xaa, 0xaa, 0xaa, 0x2a], 0xa54a952a)

        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x05], mapreduce(i->UInt64(i) << 7(i - 1), |, 5:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x04], mapreduce(i->UInt64(i) << 7(i - 1), |, 4:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x03], mapreduce(i->UInt64(i) << 7(i - 1), |, 3:-1:0))
        test_decode(UInt8[0x81, 0x02], mapreduce(i->UInt64(i) << 7(i - 1), |, 2:-1:0))
        test_decode(UInt8[0x01], mapreduce(i->UInt64(i) << 7(i - 1), |, 1:-1:0))
    end
    @testset "UInt64" begin
        test_decode(UInt8[0x00], UInt64(0))
        test_decode(UInt8[0x01], UInt64(1))
        test_decode(UInt8[0x80, 0x01], UInt64(128))
        test_decode(UInt8[0x80, 0x80, 0x01], UInt64(1) << 14)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x01], UInt64(1) << 21)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 28)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 35)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 42)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 49)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 56)
        test_decode(UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01], UInt64(1) << 63)
        test_decode(UInt8[0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x2a], 0x2a54a952a54a952a)

        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x70], mapreduce(i->UInt64(i) << 7(i - 1), |, 10:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x0a], mapreduce(i->UInt64(i) << 7(i - 1), |, 9:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x09], mapreduce(i->UInt64(i) << 7(i - 1), |, 9:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x08], mapreduce(i->UInt64(i) << 7(i - 1), |, 8:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x07], mapreduce(i->UInt64(i) << 7(i - 1), |, 7:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x06], mapreduce(i->UInt64(i) << 7(i - 1), |, 6:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x84, 0x05], mapreduce(i->UInt64(i) << 7(i - 1), |, 5:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x83, 0x04], mapreduce(i->UInt64(i) << 7(i - 1), |, 4:-1:0))
        test_decode(UInt8[0x81, 0x82, 0x03], mapreduce(i->UInt64(i) << 7(i - 1), |, 3:-1:0))
        test_decode(UInt8[0x81, 0x02], mapreduce(i->UInt64(i) << 7(i - 1), |, 2:-1:0))
        test_decode(UInt8[0x01], mapreduce(i->UInt64(i) << 7(i - 1), |, 1:-1:0))
    end
end

@testset "vbyte encode" begin
    @testset "UInt32" begin
        test_encode(UInt32(0), UInt8[0x00])
        test_encode(UInt32(1), UInt8[0x01])
        test_encode(UInt32(128), UInt8[0x80, 0x01])
        test_encode(UInt32(1) << 14, UInt8[0x80, 0x80, 0x01])
        test_encode(UInt32(1) << 21, UInt8[0x80, 0x80, 0x80, 0x01])
        test_encode(UInt32(1) << 28, UInt8[0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt32(1) << 31, UInt8[0x80, 0x80, 0x80, 0x80, 0x08])

        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 5:-1:0), UInt8[0x81, 0x82, 0x83, 0x84, 0x05])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 4:-1:0), UInt8[0x81, 0x82, 0x83, 0x04])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 3:-1:0), UInt8[0x81, 0x82, 0x03])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 2:-1:0), UInt8[0x81, 0x02])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 1:-1:0), UInt8[0x01])
    end
    @testset "UInt64" begin
        test_encode(UInt64(0), UInt8[0x00])
        test_encode(UInt64(1), UInt8[0x01])
        test_encode(UInt64(128), UInt8[0x80, 0x01])
        test_encode(UInt64(1) << 14, UInt8[0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 21, UInt8[0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 28, UInt8[0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 35, UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 42, UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 49, UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 56, UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])
        test_encode(UInt64(1) << 63, UInt8[0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01])

        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 10:-1:0), UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x09])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 9:-1:0),  UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x09])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 8:-1:0),  UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x08])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 7:-1:0),  UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x07])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 6:-1:0),  UInt8[0x81, 0x82, 0x83, 0x84, 0x85, 0x06])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 5:-1:0),  UInt8[0x81, 0x82, 0x83, 0x84, 0x05])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 4:-1:0),  UInt8[0x81, 0x82, 0x83, 0x04])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 3:-1:0),  UInt8[0x81, 0x82, 0x03])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 2:-1:0),  UInt8[0x81, 0x02])
        test_encode(mapreduce(i->UInt64(i) << 7(i - 1), |, 1:-1:0),  UInt8[0x01])
    end
end

@testset "vbyte idempotency" begin
    @testset "UInt32" begin
        for b in Iterators.product(((0x00, 0xFF) for _ in 1:4)...)
            test_roundtrip(reinterpret(UInt32, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0x01) for _ in 1:4)...)
            test_roundtrip(reinterpret(UInt32, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0x80) for _ in 1:4)...)
            test_roundtrip(reinterpret(UInt32, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0xaa) for _ in 1:4)...)
            test_roundtrip(reinterpret(UInt32, collect(b))[1])
        end
    end

    @testset "UInt64" begin
        for b in Iterators.product(((0x00, 0xFF) for _ in 1:8)...)
            test_roundtrip(reinterpret(UInt64, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0x01) for _ in 1:8)...)
            test_roundtrip(reinterpret(UInt64, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0x80) for _ in 1:8)...)
            test_roundtrip(reinterpret(UInt64, collect(b))[1])
        end
        for b in Iterators.product(((0x00, 0xaa) for _ in 1:8)...)
            test_roundtrip(reinterpret(UInt64, collect(b))[1])
        end
    end
end