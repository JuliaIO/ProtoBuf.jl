# ensure stdlib is in load path
function ensure_stdlib()
    if "JULIA_LOAD_PATH" in keys(ENV)
        _add_path = false
        comps = split(ENV["JULIA_LOAD_PATH"], ":")
        for needed in split("@:@v#.#:@stdlib", ":")
            if !(needed in comps)
                push!(comps, needed)
                _add_path = true
            end
        end
        if _add_path
            @show ENV["JULIA_LOAD_PATH"] = join(comps, ":")
        end
    end
    nothing
end

if Sys.iswindows()
    println("testing protobuf compiler plugin not enabled on windows")
else
    test_script = joinpath(@__DIR__, "testprotoc.sh")
    protogen_path = joinpath(@__DIR__, "..", "plugin")
    path_env = "$(protogen_path):$(ENV["PATH"])"
    modified_env = Dict{String, String}()
    is_ci = "CI" in keys(ENV)
    if is_ci
        modified_env["COVERAGE"] = "--code-coverage=user --inline=no"
    end
    protoc_compilers = []
    for protoc_env in ("PROTOC2", "PROTOC3")
        if protoc_env in keys(ENV)
            push!(protoc_compilers, ENV[protoc_env])
        end
    end
    if isempty(protoc_compilers)
        println("no protobuf compilers setup for testing compiler plugin, skipping compiler tests.")
    else
        println("testing protobuf compiler plugin...")
        is_ci && println("detected CI environment, will enable code coverage...")
        for protoc_compiler in protoc_compilers
            modified_env["PROTOC"] = protoc_compiler
            modified_env["PATH"] = path_env
            modified_env["JULIA"] = joinpath(Sys.BINDIR, Base.julia_exename())
            println("testing protoc compiler plugin with ", protoc_compiler)
            run(setenv(`$test_script`, modified_env))
        end

        # test ProtoBuf.protoc
        pathenv = get(ENV, "PATH", "")
        test_protos = joinpath(@__DIR__, "proto")
        test_proto = joinpath(test_protos, "plugin.proto")

        ensure_stdlib()

        for protoc_compiler in protoc_compilers
            # set path to pick up compiler
            ENV["PATH"] = string(dirname(protoc_compiler), ":", pathenv)
            println("testing ProtoBuf.protoc with ", protoc_compiler)
            run(ProtoBuf.protoc(`-I=$test_protos --julia_out=/tmp $test_proto`))
        end
    end
end
