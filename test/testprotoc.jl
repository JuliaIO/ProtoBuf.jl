using Compat

if Compat.Sys.iswindows()
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
            modified_env["JULIA"] = joinpath(Compat.Sys.BINDIR, Base.julia_exename())
            println("testing protoc compiler plugin with ", protoc_compiler)
            run(setenv(`$test_script`, modified_env))
        end
    end
end
