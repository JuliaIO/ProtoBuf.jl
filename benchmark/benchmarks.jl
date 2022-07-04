using BenchmarkTools
using ProtocolBuffers
using EnumX

using ProtocolBuffers.Codecs: BufferedVector, LENGTH_DELIMITED


@enumx TestEnum a b c d e

Base.rand(::Type{TestEnum.T}) = TestEnum.T(rand(Int(TestEnum.a):Int(TestEnum.e)))
Base.rand(::Type{TestEnum.T}, n::Int) = TestEnum.T.(rand(Int(TestEnum.a):Int(TestEnum.e), n))

const N = (1, 63, 256)
const W = LENGTH_DELIMITED

SUITE = BenchmarkGroup()
SUITE["encode"] = BenchmarkGroup()
SUITE["encode"]["scalar"] = BenchmarkGroup()
SUITE["encode"]["repeated"] = BenchmarkGroup()
SUITE["decode"] = BenchmarkGroup()
SUITE["decode"]["scalar"] = BenchmarkGroup()
SUITE["decode"]["repeated"] = BenchmarkGroup()

function setup_decoder(x)
    io = IOBuffer()
    d = ProtoDecoder(io)
    e = ProtoEncoder(io)
    encode(e, 1, x)
    seekstart(io)
    ProtocolBuffers.Codecs.decode_tag(d)
    return d
end

function setup_decoder(x, V)
    io = IOBuffer()
    d = ProtoDecoder(io)
    e = ProtoEncoder(io)
    encode(e, 1, x, V)
    seekstart(io)
    ProtocolBuffers.Codecs.decode_tag(d)
    return d
end


for (field_type, jl_type) in (
        ("uint32", UInt32), ("uint64", UInt64), ("int32", Int32), ("int64", Int64),
        ("float", Float32), ("double", Float64), ("enum", TestEnum.T),
    )
    SUITE["encode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["encode"]["scalar"][field_type] = @benchmarkable encode(e, 1, x) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type))
    for n in N
        SUITE["encode"]["repeated"][field_type][n] = @benchmarkable encode(e, 1, x) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type, $n))
    end
end

for (field_type, jl_type) in (("sint32", Int32), ("sint64", Int64),)
    SUITE["encode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["encode"]["scalar"][field_type] = @benchmarkable encode(e, 1, x, $(Val{:zigzag})) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type))
    for n in N
        SUITE["encode"]["repeated"][field_type][n] = @benchmarkable encode(e, 1, x, $(Val{:zigzag})) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type, $n))
    end
end

for (field_type, jl_type) in (("sfixed32", Int32), ("sfixed64", Int64), ("fixed32", UInt32), ("fixed64", UInt64))
    SUITE["encode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["encode"]["scalar"][field_type] = @benchmarkable encode(e, 1, x, $(Val{:fixed})) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type))
    for n in N
        SUITE["encode"]["repeated"][field_type][n] = @benchmarkable encode(e, 1, x, $(Val{:fixed})) evals=1 samples=10000 setup=(e=ProtoEncoder(IOBuffer()); x = rand($jl_type, $n))
    end
end


for (field_type, jl_type) in (
    ("uint32", UInt32), ("uint64", UInt64), ("int32", Int32), ("int64", Int64),
    ("float", Float32), ("double", Float64), ("enum", TestEnum.T),
)
    SUITE["decode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["decode"]["scalar"][field_type] = @benchmarkable decode(d, $(jl_type)) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type)))
    for n in N
        SUITE["decode"]["repeated"][field_type][n] = @benchmarkable decode!(d, W, b) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type, $n)); b = $(BufferedVector{jl_type}()))
    end
end

for (field_type, jl_type) in (("sint32", Int32), ("sint64", Int64),)
    SUITE["decode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["decode"]["scalar"][field_type] = @benchmarkable decode(d, $(jl_type), $(Val{:zigzag})) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type), Val{:zigzag}))
    for n in N
        SUITE["decode"]["repeated"][field_type][n] = @benchmarkable decode!(d, W, b, $(Val{:zigzag})) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type, $n), Val{:zigzag}); b = $(BufferedVector{jl_type}()))
    end
end

for (field_type, jl_type) in (("sfixed32", Int32), ("sfixed64", Int64), ("fixed32", UInt32), ("fixed64", UInt64))
    SUITE["decode"]["repeated"][field_type] = BenchmarkGroup()
    SUITE["decode"]["scalar"][field_type] = @benchmarkable decode(d, $(jl_type), $(Val{:fixed})) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type), Val{:fixed}))
    for n in N
        SUITE["decode"]["repeated"][field_type][n] = @benchmarkable decode!(d, W, b, $(Val{:fixed})) evals=1 samples=10000 setup=(d=setup_decoder(rand($jl_type, $n), Val{:fixed}); b = $(BufferedVector{jl_type}()))
    end
end


# results = run(SUITE, verbose=true, seconds=30);
# BenchmarkTools.save("tune.json", params(SUITE));
