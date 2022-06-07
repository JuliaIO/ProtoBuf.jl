using Test
using Aqua
import ProtocolBuffers

include("test_lexers.jl")

@testset "Aqua" begin
    Aqua.test_all(ProtocolBuffers)
end