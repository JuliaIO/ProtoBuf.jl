using Test
using Aqua
import ProtocolBuffers

@testset "ProtocolBuffers" begin
    include("test_lexers.jl")
    include("test_vbyte.jl")
    include("test_encode.jl")
    include("test_decode.jl")
    include("test_parser.jl")
    include("test_codegen.jl")
    include("test_protojl.jl")

    @testset "Aqua" begin
        Aqua.test_all(ProtocolBuffers)
    end
end