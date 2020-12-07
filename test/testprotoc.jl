# ensure stdlib is in load path
function ensure_stdlib()
    separator = Sys.iswindows() ? ';' : ':'
    if "JULIA_LOAD_PATH" in keys(ENV)
        _add_path = false
        comps = split(ENV["JULIA_LOAD_PATH"], separator)
        for needed in split("@:@v#.#:@stdlib", separator)
            if !(needed in comps)
                push!(comps, needed)
                _add_path = true
            end
        end
        if _add_path
            ENV["JULIA_LOAD_PATH"] = join(comps, separator)
        end
    end
    nothing
end

const PROTOC_TESTCASES = [
    (
        files=["t1.proto"],
        check="include(\"t1_pb.jl\")",
        envs=[],
    ),
    (
        files=["t2.proto"],
        check="include(\"t2_pb.jl\")",
        envs=[],
    ),
    (
        files=["recursive.proto"],
        check="include(\"recursive_pb.jl\")",
        envs=[],
    ),
    (
        files=["a.proto", "b.proto"],
        check="include(\"AB.jl\"); using .AB; using .AB.A, .AB.B",
        envs=[],
    ),
    (
        files=["p1proto.proto", "p2proto.proto"],
        check="include(\"P1.jl\"); include(\"P2.jl\"); using .P1; using .P2",
        envs=[],
    ),
    (
        files=["module_type_name_collision.proto"],
        check="include(\"Foo_pb.jl\"); using .Foo_pb",
        envs=["JULIA_PROTOBUF_MODULE_POSTFIX"=>"1"],
    ),
    (
        files=["packed2.proto"],
        check="include(\"packed2_pb.jl\")",
        envs=[],
    ),
    (
        files=["inf_nan.proto"],
        check="include(\"inf_nan_pb.jl\")",
        envs=[],
    ),
    (
        files=["map3.proto"],
        check="include(\"map3_pb.jl\"); @test meta(MapTest).ordered[3].jtyp <: Dict; mv(\"map3_pb.jl\", \"map3_dict_pb.jl\"; force=true);",
        envs=[],
    ),
    (
        files=["map3.proto"],
        check="include(\"map3_pb.jl\"); @test meta(MapTest).ordered[3].jtyp <: Array; mv(\"map3_pb.jl\", \"map3_array_pb.jl\"; force=true);",
        envs=["JULIA_PROTOBUF_MAP_AS_ARRAY"=>"1"],
    ),
    (
        files=["oneof3.proto"],
        check="include(\"oneof3_pb.jl\")",
        envs=[],
    ),
    (
        files=["packed3.proto"],
        check="include(\"packed3_pb.jl\")",
        envs=[],
    ),
    (
        files=["any_test.proto"],
        check="include(\"any_test_pb.jl\")",
        envs=[],
    ),
    (
        files=["svc3.proto"],
        check="include(\"svc3_pb.jl\")",
        envs=[],
    ),
]

function protoc_test(files, check, envs, outdir)
    srcdir = joinpath(@__DIR__, "proto")
    well_known_proto_srcdir = abspath(joinpath(@__DIR__, "..", "gen"))
    srcpaths = join([joinpath(srcdir, file) for file in files], ' ')
    testscript = joinpath(outdir, "testprotoc_run.jl")

    is_ci = "CI" in keys(ENV)

    open(testscript, "w") do os
        if "JULIA_LOAD_PATH" in keys(ENV)
            loadpath = ENV["JULIA_LOAD_PATH"]
            if Sys.iswindows()
                # escape separator for printing
                loadpath = replace(loadpath, "\\"=>"\\\\")
                outdir = replace(outdir, "\\"=>"\\\\")
                srcdir = replace(srcdir, "\\"=>"\\\\")
                well_known_proto_srcdir = replace(well_known_proto_srcdir, "\\"=>"\\\\")
                srcpaths = replace(srcpaths, "\\"=>"\\\\")
            end
            println(os, "ENV[\"JULIA_LOAD_PATH\"] = \"$loadpath\"")
        end
        println(os, "using ProtoBuf, Test")
        for (env_name, env_val) in envs
            println(os, "ENV[\"$env_name\"]=\"$env_val\"")
        end
        if is_ci
            println(os, "ENV[\"COVERAGE\"]=\"--code-coverage=user --inline=no\"")
        end
        println(os, "cd(\"$outdir\")")
        println(os, "ProtoBuf.protoc(`-I=$srcdir -I=$well_known_proto_srcdir --julia_out=$outdir $srcpaths`)")
        println(os, check)
    end
    julia_fullpath = joinpath(Sys.BINDIR, Base.julia_exename())
    julia = is_ci ? `$julia_fullpath` : `$julia_fullpath --code-coverage=user --inline=no`
    proc = run(`$julia $testscript`)
    proc.exitcode
end

@info("testing protoc")
@testset "protoc" begin
    ensure_stdlib()
    mktempdir() do outdir
        for testcase in PROTOC_TESTCASES
            if Sys.iswindows() && !isempty(testcase.envs)
                @info("skipping protoc tests that need environment variables on windows")
            else
                @test protoc_test(testcase.files, testcase.check, testcase.envs, outdir) == 0
            end
        end
    end
end