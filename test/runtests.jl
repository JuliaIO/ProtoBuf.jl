using ProtoBuf, Test

@testset "ProtoBuf Tests" begin
    include("testprotoc.jl")
    include("services/testsvc.jl")
    include("testmetalock.jl")
    include("testtypevers.jl")
    include("testutilapi.jl")
    include("testwellknown.jl")
    include("testcodec.jl")
end
