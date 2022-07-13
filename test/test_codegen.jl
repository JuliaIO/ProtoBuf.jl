using ProtocolBuffers
using ProtocolBuffers.CodeGenerators: Options, ResolvedProtoFile, translate, namespace
using ProtocolBuffers.CodeGenerators: import_paths, Context, generate_struct, codegen
using ProtocolBuffers.CodeGenerators: CodeGenerators
using ProtocolBuffers.Parsers: parse_proto_file, ParserState, Parsers
using ProtocolBuffers.Lexers: Lexer
using Test

strify(f, args...) = (io = IOBuffer(); f(io, args...); String(take!(io)))
generate_struct_str(args...) = strify(generate_struct, args...)
codegen_str(args...) = strify(codegen, args...)

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

    @testset "Metadata methods" begin
        @testset "metadata_methods have generic fallback" begin
            s, p, ctx = translate_simple_proto("message A { }")
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method, p.definitions["A"]) == ""
            @test strify(CodeGenerators.maybe_generate_extendable_field_numbers_method, p.definitions["A"]) == ""
            @test strify(CodeGenerators.maybe_generate_default_values_method, p.definitions["A"], ctx) == ""
            @test strify(CodeGenerators.maybe_generate_oneof_field_types_method, p.definitions["A"], ctx) == ""
            @test strify(CodeGenerators.maybe_generate_field_numbers_method, p.definitions["A"]) == ""

            struct A end
            @test reserved_fields(A) == (names = String[], numbers = Union{UnitRange{Int64}, Int64}[])
            @test extendable_field_numbers(A) == Union{UnitRange{Int64}, Int64}[]
            @test default_values(A) == (;)
            @test oneof_field_types(A) == (;)
            @test field_numbers(A) == (;)
        end

        @testset "metadata_methods are generated when needed" begin
            s, p, ctx = translate_simple_proto("message A { reserved \"b\"; reserved 2; extensions 4 to max; A a = 1; oneof o { sfixed32 s = 3 [default = -1]; }}")
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method,          p.definitions["A"])      == "PB.reserved_fields(::Type{A}) = (names = [\"b\"], numbers = Union{UnitRange{Int64}, Int64}[2])\n"
            @test strify(CodeGenerators.maybe_generate_extendable_field_numbers_method, p.definitions["A"])      == "PB.extendable_field_numbers(::Type{A}) = Union{UnitRange{Int64}, Int64}[4:536870911]\n"
            @test strify(CodeGenerators.maybe_generate_default_values_method,           p.definitions["A"], ctx) == "PB.default_values(::Type{A}) = (;a = Ref{Union{Nothing,A}}(nothing), s = Int32(-1))\n"
            @test strify(CodeGenerators.maybe_generate_oneof_field_types_method,        p.definitions["A"], ctx) == "PB.oneof_field_types(::Type{A}) = (;\n    o = (;s=Int32)\n)\n"
            @test strify(CodeGenerators.maybe_generate_field_numbers_method,            p.definitions["A"])      == "PB.field_numbers(::Type{A}) = (;a = 1, s = 3)\n"
        end
    end
end