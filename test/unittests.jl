using Test
import ProtoBuf

@testset "ProtoBuf" begin
    include("test_lexers.jl")
    include("test_vbyte.jl")
    include("test_encode.jl")
    include("test_decode.jl")
    include("test_parser.jl")
    include("test_modules.jl")
    include("test_codegen.jl")
    include("test_protojl.jl")
end