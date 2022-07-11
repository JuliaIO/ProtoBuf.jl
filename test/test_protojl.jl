module TestCompelexProtoFile
using Test
using ProtocolBuffers

mktempdir() do tmpdir
    @testset "Translate and include complex proto files" begin
        @testset "google/protobuf/unittest.proto" begin
            @testset "translate source" begin
                @test isnothing(protojl("google/protobuf/unittest.proto", joinpath(@__DIR__, "test_protos"), tmpdir))
            end
            @testset "include generated" begin
                @test include(joinpath(tmpdir, "protobuf_unittest/ProtobufUnittest_PB.jl")) isa Module
            end
        end

        @testset "google/protobuf/unittest_proto3.proto" begin
            @testset "translate source" begin
                @test isnothing(protojl("google/protobuf/unittest_proto3.proto", joinpath(@__DIR__, "test_protos"), tmpdir))
            end
            @testset "include generated" begin
                @test include(joinpath(tmpdir, "proto3_unittest/Proto3Unittest_PB.jl")) isa Module
            end
        end

        @testset "google/protobuf/unittest_well_known_types.proto" begin
            @testset "translate source" begin
                @test isnothing(protojl("google/protobuf/unittest_well_known_types.proto", joinpath(@__DIR__, "test_protos"), tmpdir))
            end
            @testset "include generated" begin
                @test include(joinpath(tmpdir, "protobuf_unittest/ProtobufUnittest_PB.jl")) isa Module
            end
        end

        @testset "datasets/google_message3/benchmark_message3.proto" begin
            @testset "translate source" begin
                @test isnothing(protojl("datasets/google_message3/benchmark_message3.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir))
            end
            @testset "include generated" begin
                @test include(joinpath(tmpdir, "benchmarks/google_message3/GoogleMessage3_PB.jl")) isa Module
            end
        end

        @testset "datasets/google_message4/benchmark_message4.proto" begin
            @testset "translate source" begin
                @test isnothing(protojl("datasets/google_message4/benchmark_message4.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir))
            end
            @testset "include generated" begin
                @test include(joinpath(tmpdir, "benchmarks/google_message4/GoogleMessage4_PB.jl")) isa Module
            end
        end
    end
end
end

module TestComplexMessage
using Test
using ProtocolBuffers

function roundtrip(input)
    io = IOBuffer()
    e = ProtoEncoder(io)
    d = ProtoDecoder(io)
    encode(e, input)
    seekstart(io)
    roundtripped = decode(d, OmniMessage)
    return roundtripped
end

function test_by_field(actual::T, expected::T) where {T}
    for field in fieldnames(T)
        @testset "$T.$field" begin
            @test getfield(actual, field) == getfield(expected, field)
        end
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
    )
    @testset "roundtrip" begin
        test_by_field(roundtrip(msg), msg)
    end
    @testset "roundtrip roundtrip" begin
        test_by_field(roundtrip(roundtrip(msg)), msg)
    end
end
end