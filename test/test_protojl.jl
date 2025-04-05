module TestCompelexProtoFile
using Test
using ProtoBuf

mktempdir() do tmpdir
    @testset "Translate and include complex proto files" begin
        for options in ((;), (parametrize_oneofs = true,))
            @testset "options = $options" begin
                @testset "google/protobuf/unittest.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_unittest/protobuf_unittest.jl")) isa Module
                    end
                end

                @testset "google/protobuf/unittest_proto3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest_proto3.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "proto3_unittest/proto3_unittest.jl")) isa Module
                    end
                end

                @testset "google/protobuf/unittest_well_known_types.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest_well_known_types.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_unittest/protobuf_unittest.jl")) isa Module
                    end
                end

                @testset "datasets/google_message3/benchmark_message3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("datasets/google_message3/benchmark_message3.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "benchmarks/google_message3/google_message3.jl")) isa Module
                    end
                end

                @testset "datasets/google_message4/benchmark_message4.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("datasets/google_message4/benchmark_message4.proto", joinpath(@__DIR__, "test_protos/benchmarks"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "benchmarks/google_message4/google_message4.jl")) isa Module
                    end
                end

                @testset "google/protobuf/test_message_proto2.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/test_messages_proto2.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_test_messages/protobuf_test_messages.jl")) isa Module
                    end
                end

                @testset "google/protobuf/test_message_proto3.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/test_messages_proto3.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_test_messages/protobuf_test_messages.jl")) isa Module
                    end
                end

                @testset "google/protobuf/unittest_custom_options.proto" begin
                    @testset "translate source" begin
                        @test isnothing(protojl("google/protobuf/unittest_custom_options.proto", joinpath(@__DIR__, "test_protos"), tmpdir; options...))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "protobuf_unittest/protobuf_unittest.jl")) isa Module
                    end
                end

                @testset "google/protobuf/complex_dependencies/*" begin
                    @testset "translate source" begin
                        test_dir = "test_protos/google/protobuf/complex_dependencies"
                        @test isnothing(protojl(
                            ["da.proto","g.proto","c.proto","d.proto","e.proto"],
                            joinpath(@__DIR__,test_dir),
                            tmpdir;
                            options...
                         ))
                    end
                    @testset "include generated" begin
                        @test include(joinpath(tmpdir, "test/test.jl")) isa Module
                        @test test.da.A isa Type
                        @test test.c.C isa Type
                        @test test.d.D isa Type
                        @test test.test2.e.Ef isa Type
                        @test test.test2.g.G isa Type
                    end
                end
            end
        end
    end
end
end

module TestComplexMessage
using Test
using ProtoBuf
using BufferedStreams

function roundtrip_iobuffer(input, f_in=identity, f_out=identity)
    io = IOBuffer()
    e = ProtoEncoder(f_in(io))
    encode(e, input)
    seekstart(io)
    d = ProtoDecoder(f_out(io))
    return decode(d, OmniMessage)
end

function roundtrip_iobuffer_maxsize(input, f_in=identity, f_out=identity)
    protosize = ProtoBuf._encoded_size(input)
    buf = zeros(UInt8, protosize)

    wio = IOBuffer(buf, read=false, write=true, maxsize=protosize)
    e = ProtoEncoder(f_in(wio))

    encoded = encode(e, input)

    rio = IOBuffer(buf, read=true, write=false)
    d = ProtoDecoder(f_out(rio))

    @test encoded == protosize
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
    (N == 0 || a isa AbstractDict || a isa AbstractVector) && return (@testset "$name" begin @test a == b end)
    for (i, n) in zip(1:N, fieldnames(typeof(a)))
        absname = string(name, ".", String(n))
        _test_by_field(getfield(a, i), getfield(b, i), absname)
    end
end

@testset "Translate and roundtrip a complex message" begin
    mktempdir() do tmpdir
        protojl("complex_message.proto", joinpath(@__DIR__, "test_protos/"), tmpdir, always_use_modules=false, parametrize_oneofs=true);
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
        NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing, OneOf(:y, 1), nothing), OneOf(:y, 2), nothing),
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
        [
            NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing, OneOf(:y, 3), nothing), OneOf(:y, 4), nothing),
            NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing, OneOf(:y, 3), nothing), OneOf(:y, 4), CoRecursiveMessage(nothing)),
        ],

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
        Dict(
            "K1" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing, OneOf(:y, 5), nothing), OneOf(:y, 6), nothing),
            "K2" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing, OneOf(:y, 5), nothing), OneOf(:y, 6), CoRecursiveMessage(nothing)),

        ),

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

        Float32(-0.0), # Checks that -0.0 is serialized and not confused with the 0.0 default value
        Float64(-0.0),
    )

    @testset "IOBuffer" begin
        test_by_field(roundtrip_iobuffer(msg), msg)
    end
    @testset "IOBuffer preallocated" begin
        test_by_field(roundtrip_iobuffer_maxsize(msg), msg)
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

module TestMappingStruct
using Test
using ProtoBuf

@testset "Roundtrip a dictionary mapping" begin
    tmpdir = mktempdir()
    protojl("pair_struct.proto", joinpath(pkgdir(ProtoBuf), "test", "test_protos"), tmpdir, always_use_modules=false, parametrize_oneofs=true);
    include(joinpath(tmpdir, "pair_struct_pb.jl"))

    function encode_bytes(msg)
        io = IOBuffer()
        e = PB.ProtoEncoder(io)
        PB.encode(e, msg)
        return take!(io)
    end

    function decode_bytes(::Type{T}, bytes) where {T}
        io = IOBuffer(bytes)
        d = PB.ProtoDecoder(io)
        return PB.decode(d, T)
    end

    test_dictionary = Dict{String, Int64}(
        "field1"=>1,
        "field2"=>-5,
        "field3"=>120,
    )

    dict_message = Map(test_dictionary)
    pairs_message = Pairs([ProtoPair(k, v) for (k, v) in test_dictionary])

    encoded_dict = encode_bytes(dict_message)
    encoded_pairs = encode_bytes(pairs_message)

    decoded_dict = decode_bytes(Map, encoded_pairs)
    decoded_pairs = decode_bytes(Pairs, encoded_dict)

    @test encoded_dict == encoded_pairs

    @test typeof(dict_message) == typeof(decoded_dict)
    @test dict_message.map_field == decoded_dict.map_field

    @test typeof(pairs_message) == typeof(decoded_pairs)
    @test pairs_message.map_field == decoded_pairs.map_field
end
end
