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

# Don't run JET on nightly in CI
if Base.VERSION > v"1.7.0" && !(is_ci() && get(VERSION.prerelease, 1, "") == "DEV")
    @testset "JET" begin
        include("jet_test_utils.jl")

        # filter false positives for undefined variable warnings in `copy_chunks!` from Base.BitArray
        jet_frames_to_skip = (
            JETFrameFingerprint(JET.UndefVarErrorReport, :Base, :copy_chunks!, "copy_chunks!(dest::Vector{UInt64}, pos_d::Int64, src::Vector{UInt64}, pos_s::Int64, numbits::Int64)"),
            JETFrameFingerprint(JET.UndefVarErrorReport, :Base, :copy_chunks_rtol!, "copy_chunks_rtol!(chunks::Vector{UInt64}, pos_d::Int64, pos_s::Int64, numbits::Int64)"),
        )

        is_ci() || jet_test_package(ProtoBuf; jet_frames_to_skip)
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
