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

if Base.VERSION > v"1.7.0"
    @testset "JET" begin
        include("jet_test_utils.jl")
        is_ci() || jet_test_package(ProtoBuf)
        # jet_test_file("unittests.jl", ignored_modules=(JET.AnyFrameModule(Test),))
        include("test_perf.jl")
    end
end

@testset "Aqua" begin
    Aqua.test_all(ProtoBuf)
end

#=
using Coverage
using ProtoBuf
pkg_path = pkgdir(ProtoBuf);
coverage = process_folder(joinpath(pkg_path, "src"));
open(joinpath(pkg_path, "lcov.info"), "w") do io
    LCOV.write(io, coverage)
end;
covered_lines, total_lines = get_summary(coverage);
println("Coverage: $(round(100 * covered_lines / total_lines, digits=2))%");
run(`find $pkg_path -name "*.cov" -type f -delete`);
=#
