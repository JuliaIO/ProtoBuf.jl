module TestCompelexProtoFile
using Test
using ProtocolBuffers


mktempdir() do tmpdir
    @testset "Translate and include complex proto files" begin
        for options in ((;), (parametrize_oneofs = true,))
            @testset "options = $options" begin
                @testset "google/protobuf/unittest.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_unittest/ProtobufUnittest_PB.jl")) isa Module
                    end
                end

                @testset "google/protobuf/unittest_proto3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest_proto3.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "proto3_unittest/Proto3Unittest_PB.jl")) isa Module
                    end
                end

                @testset "google/protobuf/unittest_well_known_types.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest_well_known_types.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_unittest/ProtobufUnittest_PB.jl")) isa Module
                    end
                end

                @testset "datasets/google_message3/benchmark_message3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("datasets/google_message3/benchmark_message3.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "benchmarks/google_message3/GoogleMessage3_PB.jl")) isa Module
                    end
                end

                @testset "datasets/google_message4/benchmark_message4.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("datasets/google_message4/benchmark_message4.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "benchmarks/google_message4/GoogleMessage4_PB.jl")) isa Module
                    end
                end

                @testset "google/protobuf/test_message_proto2.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/test_messages_proto2.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_test_messages/proto2/Proto2_PB.jl")) isa Module
                    end
                end

                @testset "google/protobuf/test_message_proto3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/test_messages_proto3.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_test_messages/proto3/Proto3_PB.jl")) isa Module
                    end
                end
            end
        end
    end
end
end

module TestComplexMessage
using Test
using ProtocolBuffers
using TranscodingStreams
using BufferedStreams

function roundtrip_iobuffer(input, f_in=identity, f_out=identity)
    io = IOBuffer()
    e = ProtoEncoder(f_in(io))
    encode(e, input)
    seekstart(io)
    d = ProtoDecoder(f_out(io))
    return decode(d, OmniMessage)
end

function roundtrip_iostream(input, f_in=identity, f_out=identity)
    (path, io) = mktemp()
    e = ProtoEncoder(f_in(io))
    encode(e, input)
    close(io)
    io = f_out(open(path, "r"))
    d = ProtoDecoder(io)
    out = decode(d, OmniMessage)
    close(io)
    return out
end

function test_by_field(a, b)
    @testset "$(typeof(a))" begin
        _test_by_field(a, b)
    end
end

function _test_by_field(a, b, name=string(typeof(a)))
    N = fieldcount(typeof(a))
    (N == 0 || a isa AbstractDict) && return (@testset "$name" begin @test a == b end)
    for (i, n) in zip(1:N, fieldnames(typeof(a)))
        absname = string(name, ".", String(n))
        _test_by_field(getfield(a, i), getfield(b, i), absname)
    end
end

@testset "Translate and roundtrip a complex message" begin
    mktempdir() do tmpdir
        protojl("complex_message.proto", joinpath(@__DIR__, "test_protos/"), tmpdir, always_use_modules=false);
        include(joinpath(tmpdir, "complex_message_pb.jl"))
    end
    msg = OmniMessage(
        UInt8[0xff],
        "S",
        typemax(UInt32),
        typemax(UInt64),
        typemax(Int32),
        typemax(Int64),
        true,
        typemax(Int32),
        typemax(Int64),
        TestEnum.OTHER,
        typemax(Int32),
        typemax(Int64),
        typemax(UInt32),
        typemax(UInt64),
        EmptyMessage(),
        NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing)),
        OneOf(:oneof_uint32_field, typemax(UInt32)),

        [UInt8[0xff]],
        ["S"],
        [typemax(UInt32)],
        [typemax(UInt64)],
        [typemax(Int32)],
        [typemax(Int64)],
        [true],
        [typemax(Int32)],
        [typemax(Int64)],
        [TestEnum.OTHER],
        [typemax(Int32)],
        [typemax(Int64)],
        [typemax(UInt32)],
        [typemax(UInt64)],
        [EmptyMessage()],
        [NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))],

        Dict("K" => UInt8[0xff]),
        Dict("K" => "S"),
        Dict("K" => typemax(UInt32)),
        Dict("K" => typemax(UInt64)),
        Dict("K" => typemax(Int32)),
        Dict("K" => typemax(Int64)),
        Dict("K" => true),
        Dict("K" => typemax(Int32)),
        Dict("K" => typemax(Int64)),
        Dict("K" => TestEnum.OTHER),
        Dict("K" => typemax(Int32)),
        Dict("K" => typemax(Int64)),
        Dict("K" => typemax(UInt32)),
        Dict("K" => typemax(UInt64)),
        Dict("K" => EmptyMessage()),
        Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))),

        Dict(typemax(UInt32) => "V"),
        Dict(typemax(UInt64) => "V"),
        Dict(typemax(Int32) => "V"),
        Dict(typemax(Int64) => "V"),
        Dict(true => "V"),
        Dict(typemax(Int32) => "V"),
        Dict(typemax(Int64) => "V"),
        Dict(typemax(Int32) => "V"),
        Dict(typemax(Int64) => "V"),
        Dict(typemax(UInt32) => "V"),
        Dict(typemax(UInt64) => "V"),

        typemax(Float32),
        typemax(Float64),
        [typemax(Float32)],
        [typemax(Float64)],
        Dict("K" => typemax(Float32)),
        Dict("K" => typemax(Float64)),

        var"OmniMessage.Group"(Int32(42)),
        [var"OmniMessage.Repeated_group"(Int32(43))],
    )

    @testset "IOBuffer" begin
        test_by_field(roundtrip_iobuffer(msg), msg)
    end
    @testset "IOStream" begin
        test_by_field(roundtrip_iostream(msg), msg)
    end

    @testset "Duplicated messages" begin
        io = IOBuffer()
        e = ProtoEncoder(io)
        encode(e, 1, DuplicatedInnerMessage(UInt32(42), UInt32[1, 2], DuplicatedMessage(DuplicatedInnerMessage(UInt32(42), UInt32[1, 2], nothing))))
        encode(e, 1, DuplicatedInnerMessage(UInt32(43), UInt32[3, 4], DuplicatedMessage(DuplicatedInnerMessage(UInt32(43), UInt32[5, 6], nothing))))
        seekstart(io)
        x = decode(ProtoDecoder(io), DuplicatedMessage)
        test_by_field(x, DuplicatedMessage(DuplicatedInnerMessage(UInt32(43), UInt32[1, 2, 3, 4], DuplicatedMessage(DuplicatedInnerMessage(UInt32(43), UInt32[1, 2, 5, 6], nothing)))))
    end
end
end