using Aqua
using JET
using ProtoBuf
using Test

function is_ci()
    get(ENV, "TRAVIS", "") == "true" ||
    get(ENV, "APPVEYOR", "") in ("true", "True") ||
    get(ENV, "CI", "") in ("true", "True")
end

include("unittests.jl")

@testset "JET" begin
    include("jet_test_utils.jl")
    is_ci() || jet_test_package(ProtoBuf)
    # jet_test_file("unittests.jl", ignored_modules=(JET.AnyFrameModule(Test),))
    include("test_perf.jl")
end

@testset "Aqua" begin
    Aqua.test_all(ProtoBuf)
end