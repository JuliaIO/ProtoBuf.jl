using ProtocolBuffers
using ProtocolBuffers.CodeGenerators: Options, ResolvedProtoFile, translate, namespace
using ProtocolBuffers.CodeGenerators: import_paths, Context, generate_struct, codegen
using ProtocolBuffers.Parsers: parse_proto_file, ParserState, Parsers
using ProtocolBuffers.Lexers: Lexer
using Test

function generate_struct_str(args...)
    io = IOBuffer()
    generate_struct(io, args...)
    return String(take!(io))
end

function codegen_str(args...)
    io = IOBuffer()
    codegen(io, args...)
    return String(take!(io))
end

function translate_simple_proto(str::String, options=Options())
    buf = IOBuffer()
    l = Lexer(IOBuffer(str), "main")
    p = parse_proto_file(ParserState(l))
    r = ResolvedProtoFile("main", p)
    d = Dict{String, ResolvedProtoFile}("main" => r)
    translate(buf, r, d, options)
    s = String(take!(buf))
    s = join(filter!(!startswith(r"#|$^"), split(s, '\n')), '\n')
    imports = Set{String}(Iterators.map(i->namespace(d[i]), import_paths(p)))
    ctx = Context(p, r.import_path, imports, d, copy(p.cyclic_definitions), options)
    s, p, ctx
end

function translate_simple_proto(str::String, deps::Dict{String,String}, options=Options())
    buf = IOBuffer()
    l = Lexer(IOBuffer(str), "main")
    p = parse_proto_file(ParserState(l))
    r = ResolvedProtoFile("main", p)
    d = Dict{String, ResolvedProtoFile}("main" => r)
    for (k, v) in deps
        get!(d, k) do
            l = Lexer(IOBuffer(v), k)
            ResolvedProtoFile(k, parse_proto_file(ParserState(l)))
        end
    end
    d["main"] =  r
    translate(buf, r, d, options)
    s = String(take!(buf))
    s = join(filter!(!startswith(r"#|$^"), split(s, '\n')), '\n')
    imports = Set{String}(Iterators.map(i->namespace(d[i]), import_paths(p)))
    ctx = Context(p, r.import_path, imports, d, copy(p.cyclic_definitions), options)
    s, d, ctx
end

@testset "translate" begin
    @testset "Minimal proto file" begin
        s, p, ctx = translate_simple_proto("", Options(always_use_modules=false))
        @test s == """
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("", Options(always_use_modules=true))
        @test s == """
        module main_pb
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx
        end # module"""
    end

    @testset "Minimal proto file with file imports" begin
        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => ""), Options(always_use_modules=false))
        @test s == """
        include("a_pb.jl")
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => ""), Options(always_use_modules=true))
        @test s == """
        module main_pb
        include("a_pb.jl")
        import a_pb
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx
        end # module"""
    end

    @testset "Minimal proto file with package imports" begin
        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => "package p;"), Options(always_use_modules=false))
        @test s == """
        include($(repr(joinpath("p", "P_PB.jl"))))
        import .P_PB
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => "package p;"), Options(always_use_modules=true))
        @test s == """
        module main_pb
        include($(repr(joinpath("p", "P_PB.jl"))))
        import .P_PB
        import ProtocolBuffers as PB
        using ProtocolBuffers: OneOf
        using EnumX: @enumx
        end # module"""
    end

    @testset "`force_required` option makes optional fields required" begin
        s, p, ctx = translate_simple_proto("message A {} message B { A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
    end

    @testset "Struct fields are optional when not marked required" begin
        s, p, ctx = translate_simple_proto("message A {} message B { A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """

        s, p, ctx = translate_simple_proto("message A {} message B { required A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
    end

    @testset "Struct fields are optional when the type is self referential" begin
        s, p, ctx = translate_simple_proto("message B { B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message B { B a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message B { required B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message B { optional B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """
    end

    @testset "Struct fields are optional when the type mutually recusrive dependency" begin
        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:var"##AbstractA"} <: var"##AbstractB"
            a::Union{Nothing,T1}
        end
        """
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:var"##AbstractA"} <: var"##AbstractB"
            a::Union{Nothing,T1}
        end
        """
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { required A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:var"##AbstractA"} <: var"##AbstractB"
            a::Union{Nothing,T1}
        end
        """
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { optional A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:var"##AbstractA"} <: var"##AbstractB"
            a::Union{Nothing,T1}
        end
        """
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """
    end

    @testset "Basic enum codegen" begin
        s, p, ctx = translate_simple_proto("enum A { a = 0; b = 1; }")
        @test codegen_str(p.definitions["A"], ctx) == """
        @enumx A a=0 b=1
        """
    end
end