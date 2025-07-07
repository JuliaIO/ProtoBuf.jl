using ProtoBuf
using ProtoBuf: _topological_sort
using ProtoBuf.CodeGenerators: ResolvedProtoFile
using ProtoBuf.CodeGenerators: Options
using ProtoBuf.CodeGenerators: Namespaces
using ProtoBuf.CodeGenerators: generate_module_file
using ProtoBuf.Parsers: parse_proto_file, ParserState
using ProtoBuf.Lexers: Lexer
using Test

function simple_namespace_from_protos(str::String, deps::Dict{String,String}=Dict{String, String}(), pkg::String="", options::Options=Options())
    l = Lexer(IOBuffer(str), "main")
    p = parse_proto_file(ParserState(l))
    r = ResolvedProtoFile("main", p)
    d = Dict{String, ResolvedProtoFile}("main" => r)
    io = IOBuffer()
    for (k, v) in deps
        get!(d, k) do
            l = Lexer(IOBuffer(v), k)
            ResolvedProtoFile(k, parse_proto_file(ParserState(l)))
        end
    end
    d["main"] = r
    sorted_files = _topological_sort(d, Set{String}())[1]
    sorted_files = [d[sorted_file] for sorted_file in sorted_files]
    n = Namespaces(sorted_files, "out", d)
    !isempty(pkg) && generate_module_file(io, n.packages[pkg], "out", d, options, 1)
    return String(take!(io)), d, n
end

@testset "Non-packaged proto imports packaged proto" begin
    s, d, n = simple_namespace_from_protos(
        "import \"path/to/a\";",
        Dict("path/to/a" => "package P;"),
    );
    @test length(n.non_namespaced_protos) == 1
    @test n.non_namespaced_protos[1].import_path == "main"
    @test length(n.packages) == 1
    @test haskey(n.packages, "P")
    @test n.packages["P"].name == "P"
    @test n.packages["P"].proto_files[1].import_path == "path/to/a"
end

@testset "Packaged proto imports non-packaged proto" begin
    s, d, n = simple_namespace_from_protos(
        "package P; import \"path/to/a\";",
        Dict("path/to/a" => ""),
    );
    @test length(n.non_namespaced_protos) == 1
    @test n.non_namespaced_protos[1].import_path == "path/to/a"
    @test length(n.packages) == 1
    @test haskey(n.packages, "P")
    @test n.packages["P"].nonpkg_imports == Set(["a_pb"])
    @test n.packages["P"].name == "P"
    @test n.packages["P"].proto_files[1].import_path == "main"
end

@testset "Non-packaged proto imports non-packaged proto" begin
    s, d, n = simple_namespace_from_protos(
        "import \"path/to/a\";",
        Dict("path/to/a" => ""),
    );
    @test length(n.non_namespaced_protos) == 2
    @test sort([p.import_path for p in n.non_namespaced_protos]) == ["main", "path/to/a"]
    @test isempty(n.packages)
end

@testset "Packaged proto imports packaged proto" begin
    s, d, n = simple_namespace_from_protos(
        "package A.B; import \"path/to/a\";",
        Dict("path/to/a" => "package B.A;"),
    );
    @test isempty(n.non_namespaced_protos)
    @test haskey(n.packages, "A")
    @test haskey(n.packages, "B")
    @test n.packages["A"].name == "A"
    @test isempty(n.packages["A"].nonpkg_imports)
    @test n.packages["A"].external_imports == Set([joinpath("..", "B", "B.jl")])
    @test n.packages["A"].submodules[["A", "B"]].name == "B"
    @test n.packages["A"].submodules[["A", "B"]].proto_files[1].import_path == "main"
    @test n.packages["B"].name == "B"
    @test n.packages["B"].submodules[["B", "A"]].name == "A"
    @test n.packages["B"].submodules[["B", "A"]].proto_files[1].import_path == "path/to/a"
end

@testset "External dependencies are imported in in the topmost module where all downstreams can reach it" begin
    s, d, n = simple_namespace_from_protos(
        "package A.B.C.D.E; import \"path/to/a\"; import \"path/to/b\";",
        Dict(
            "main2" => "package A.B.C; import \"path/to/a\";",
            "path/to/a" => "package B.A;",
            "path/to/b" => "package B.A;",
        ),
        "A"
    );
    @test n.packages["A"].external_imports == Set([joinpath("..", "B", "B.jl")])
    @test n.packages["A"].submodules[["A", "B"]].external_imports == Set{String}()
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "C"]].external_imports == Set(["...B"])
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "C"]].submodules[["A", "B", "C", "D"]].external_imports == Set{String}()
    @test s == """
    module A

    include($(repr(joinpath("..", "B", "B.jl"))))

    include($(repr(joinpath("B", "B.jl"))))

    end # module A
    """

    s, d, n = simple_namespace_from_protos(
        "package A.B.C.D.E; import \"path/to/a\"; import \"path/to/b\";",
        Dict(
            "main2" => "package A.B.C; import \"path/to/a\";",
            "path/to/a" => "",
            "path/to/b" => "",
        ),
        "A"
    );
    @test n.packages["A"].nonpkg_imports == Set(["a_pb", "b_pb"])
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "C"]].external_imports == Set(["...a_pb"])
    @test s == """
    module A

    include($(repr(joinpath("..", "a_pb.jl"))))
    include($(repr(joinpath("..", "b_pb.jl"))))

    include($(repr(joinpath("B", "B.jl"))))

    end # module A
    """
end

@testset "Imported non-namespaced protos are put in artificial modules internally" begin
    s, d, n = simple_namespace_from_protos(
        "package A.B.C.D.E; import \"path/to/a\"; import \"path/to/b\";",
        Dict(
            "main2" => "package A.B.C; import \"path/to/a\";",
            "path/to/a" => "",
            "path/to/b" => "",
        ),
        "A",
        Options(always_use_modules=false)
    );
    @test n.packages["A"].nonpkg_imports == Set(["a_pb", "b_pb"])
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "C"]].external_imports == Set(["...a_pb"])
    @test s == """
    module A

    module a_pb
        include($(repr(joinpath("..", "a_pb.jl"))))
    end
    module b_pb
        include($(repr(joinpath("..", "b_pb.jl"))))
    end

    include($(repr(joinpath("B", "B.jl"))))

    end # module A
    """
end

@testset "Repeated julia module names are made unique" begin
    s, d, n = simple_namespace_from_protos(
        "package A.B.A.D.B.A;",
    );
    @test haskey(n.packages, "A")
    @test n.packages["A"].name == "A"
    @test n.packages["A"].submodules[["A", "B"]].name == "B"
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "A"]].name == "A"
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "A"]].submodules[["A", "B", "A", "D"]].name == "D"
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "A"]].submodules[["A", "B", "A", "D"]].submodules[["A", "B", "A", "D", "B"]].name == "B"
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "A"]].submodules[["A", "B", "A", "D"]].submodules[["A", "B", "A", "D", "B"]].submodules[["A", "B", "A", "D", "B", "A"]].name == "A"
end

@testset "Relative internal imports" begin
    s, d, n = simple_namespace_from_protos(
        "package A.B.C; import \"main2\";",
        Dict(
            "main2" => "package A.B.C.D;",
        ),
        "A",
    );
    @test n.packages["A"].submodules[["A", "B"]].submodules[["A", "B", "C"]].internal_imports == Set([["A", "B", "C", "D"]])

    s, d, n = simple_namespace_from_protos(
        "package A.B; import \"main2\";",
        Dict(
            "main2" => "package A.B.C.D;",
        ),
        "A",
    );
    @test n.packages["A"].submodules[["A", "B"]].internal_imports == Set([["A", "B", "C", "D"]])
    @test n.packages["A"].submodules[["A", "B"]].name == "B"
end

@testset "Imports within a leaf module which name-clashes with top module" begin
    s, d, n = simple_namespace_from_protos(
        """
        package A.A;
        import \"main2\";
        message FromA {
            optional FromB f = 1;
        }
        """,
        Dict(
            "main2" => """package A.B; message FromB {}""",
        ),
        "A",
    );
    @test s == """
    module A

    import .A as var"#A"

    include("main_pb.jl")
    include($(repr(joinpath("B", "B.jl"))))

    end # module A
    """
end
