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
    ctx = Context(
        p, r.import_path, imports, d,
        copy(p.cyclic_definitions),
        Ref(get(p.sorted_definitions, length(p.sorted_definitions), "")),
        options
    )
    return s, p, ctx
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
    ctx = Context(
        p, r.import_path, imports, d,
        copy(p.cyclic_definitions),
        Ref(get(p.sorted_definitions, length(p.sorted_definitions), "")),
        options
    )
    return s, d, ctx
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
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"
    end

    @testset "Struct fields are optional when not marked required" begin
        s, p, ctx = translate_simple_proto("message A {} message B { A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        s, p, ctx = translate_simple_proto("message A {} message B { required A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"
    end

    @testset "Struct fields are optional when the type is self referential" begin
        s, p, ctx = translate_simple_proto("message B { B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message B { B a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message B { required B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message B { optional B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: var"##AbstractB"
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"
    end

    @testset "Struct fields are optional when the type mutually recusrive dependency" begin
        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:Union{Nothing,var"##AbstractA"}} <: var"##AbstractB"
            a::T1
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        ctx._toplevel_name[] = "A"
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:Union{Nothing,var"##AbstractA"}} <: var"##AbstractB"
            a::T1
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        ctx._toplevel_name[] = "A"
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { required A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:Union{Nothing,var"##AbstractA"}} <: var"##AbstractB"
            a::T1
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        ctx._toplevel_name[] = "A"
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message A { B b = 1; } message B { optional A a = 1; }")
        ctx._toplevel_name[] = "B"
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B{T1<:Union{Nothing,var"##AbstractA"}} <: var"##AbstractB"
            a::T1
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        ctx._toplevel_name[] = "A"
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: var"##AbstractA"
            b::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"
    end

    @testset "OneOf field codegen" begin
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } }")
        @test occursin("""
        struct A{T1<:Union{Nothing,OneOf{<:Union{Int32,UInt32,var"##AbstractA"}}}} <: var"##AbstractA"
            a::T1
        end""", s)

        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; } }")
        ctx._toplevel_name[] = "A"
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A{T1<:Union{Nothing,OneOf{<:Union{Int32,UInt32}}}}
            a::T1
        end
        """
    end

    @testset "Basic enum codegen" begin
        s, p, ctx = translate_simple_proto("enum A { a = 0; b = 1; }")
        @test codegen_str(p.definitions["A"], ctx) == """
        @enumx A a=0 b=1
        """
    end

    @testset "Basic Types" begin
        s, p, ctx = translate_simple_proto("message A { bool a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Bool"
        s, p, ctx = translate_simple_proto("message A { uint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt32"
        s, p, ctx = translate_simple_proto("message A { uint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt64"
        s, p, ctx = translate_simple_proto("message A { int32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { int64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { sint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { sint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { fixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt32"
        s, p, ctx = translate_simple_proto("message A { fixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt64"
        s, p, ctx = translate_simple_proto("message A { sfixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { sfixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { float a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Float32"
        s, p, ctx = translate_simple_proto("message A { double a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Float64"
        s, p, ctx = translate_simple_proto("message A { string a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "String"
        s, p, ctx = translate_simple_proto("message A { bytes a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{UInt8}"

        s, p, ctx = translate_simple_proto("message A { repeated bool a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Bool}"
        s, p, ctx = translate_simple_proto("message A { repeated uint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{UInt32}"
        s, p, ctx = translate_simple_proto("message A { repeated uint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{UInt64}"
        s, p, ctx = translate_simple_proto("message A { repeated int32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int32}"
        s, p, ctx = translate_simple_proto("message A { repeated int64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int64}"
        s, p, ctx = translate_simple_proto("message A { repeated sint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int32}"
        s, p, ctx = translate_simple_proto("message A { repeated sint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int64}"
        s, p, ctx = translate_simple_proto("message A { repeated fixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{UInt32}"
        s, p, ctx = translate_simple_proto("message A { repeated fixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{UInt64}"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int32}"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Int64}"
        s, p, ctx = translate_simple_proto("message A { repeated float a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Float32}"
        s, p, ctx = translate_simple_proto("message A { repeated double a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Float64}"
        s, p, ctx = translate_simple_proto("message A { repeated string a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{String}"
        s, p, ctx = translate_simple_proto("message A { repeated bytes a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{Vector{UInt8}}"

        s, p, ctx = translate_simple_proto("message A { map<string,sint32> a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Dict{String,Int32}"
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "OneOf{Union{Int32,UInt32,A}}"
        s, p, ctx = translate_simple_proto("message A { repeated A a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{A}"
    end

    @testset "Default values" begin
        s, p, ctx = translate_simple_proto("message A { bool a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "false"
        s, p, ctx = translate_simple_proto("message A { uint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { uint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { int32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { int64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { sint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { sint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { fixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { fixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { sfixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { sfixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { float a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Float32)"
        s, p, ctx = translate_simple_proto("message A { double a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Float64)"
        s, p, ctx = translate_simple_proto("message A { string a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "\"\""
        s, p, ctx = translate_simple_proto("message A { bytes a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt8[]"

        s, p, ctx = translate_simple_proto("message A { bool a = 1 [default=true]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "true"
        s, p, ctx = translate_simple_proto("message A { uint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { uint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { int32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { int64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { sint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { sint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { fixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { fixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { sfixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { sfixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { float a = 1 [default=1.0]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Float32(1.0)"
        s, p, ctx = translate_simple_proto("message A { double a = 1  [default=1.0]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Float64(1.0)"
        s, p, ctx = translate_simple_proto("message A { string a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "\"1\""
        s, p, ctx = translate_simple_proto("message A { bytes a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "b\"1\""

        s, p, ctx = translate_simple_proto("message A { repeated bool a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Bool}()"
        s, p, ctx = translate_simple_proto("message A { repeated uint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{UInt32}()"
        s, p, ctx = translate_simple_proto("message A { repeated uint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{UInt64}()"
        s, p, ctx = translate_simple_proto("message A { repeated int32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated int64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated sint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated sint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated fixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{UInt32}()"
        s, p, ctx = translate_simple_proto("message A { repeated fixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{UInt64}()"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated float a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Float32}()"
        s, p, ctx = translate_simple_proto("message A { repeated double a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Float64}()"
        s, p, ctx = translate_simple_proto("message A { repeated string a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{String}()"
        s, p, ctx = translate_simple_proto("message A { repeated bytes a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{Vector{UInt8}}()"

        s, p, ctx = translate_simple_proto("message A { map<string,sint32> a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Dict{String,Int32}()"
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; } }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        s, p, ctx = translate_simple_proto("message A { repeated A a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Vector{A}()"
        s, p, ctx = translate_simple_proto("message A { group Aa = 1 { int32 b = 1; } }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"

    end

    @testset "Initial values" begin
        s, p, ctx = translate_simple_proto("message A { bool a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "false"
        s, p, ctx = translate_simple_proto("message A { uint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { uint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { int32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { int64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { sint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { sint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { fixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { fixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { sfixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { sfixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { float a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Float32)"
        s, p, ctx = translate_simple_proto("message A { double a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Float64)"
        s, p, ctx = translate_simple_proto("message A { string a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "\"\""
        s, p, ctx = translate_simple_proto("message A { bytes a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt8[]"

        s, p, ctx = translate_simple_proto("message A { bool a = 1 [default=true]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "true"
        s, p, ctx = translate_simple_proto("message A { uint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { uint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { int32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { int64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { sint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { sint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { fixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { fixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { sfixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { sfixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { float a = 1 [default=1.0]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Float32(1.0)"
        s, p, ctx = translate_simple_proto("message A { double a = 1  [default=1.0]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Float64(1.0)"
        s, p, ctx = translate_simple_proto("message A { string a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "\"1\""
        s, p, ctx = translate_simple_proto("message A { bytes a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "b\"1\""

        s, p, ctx = translate_simple_proto("message A { repeated bool a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Bool}()"
        s, p, ctx = translate_simple_proto("message A { repeated uint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{UInt32}()"
        s, p, ctx = translate_simple_proto("message A { repeated uint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{UInt64}()"
        s, p, ctx = translate_simple_proto("message A { repeated int32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated int64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated sint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated sint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated fixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{UInt32}()"
        s, p, ctx = translate_simple_proto("message A { repeated fixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{UInt64}()"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int32}()"
        s, p, ctx = translate_simple_proto("message A { repeated sfixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Int64}()"
        s, p, ctx = translate_simple_proto("message A { repeated float a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Float32}()"
        s, p, ctx = translate_simple_proto("message A { repeated double a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Float64}()"
        s, p, ctx = translate_simple_proto("message A { repeated string a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{String}()"
        s, p, ctx = translate_simple_proto("message A { repeated bytes a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{Vector{UInt8}}()"

        s, p, ctx = translate_simple_proto("message A { repeated A a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "PB.BufferedVector{A}()"
        s, p, ctx = translate_simple_proto("message A { map<string,sint32> a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Dict{String,Int32}()"
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; } }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "nothing"
        s, p, ctx = translate_simple_proto("message A { group Aa = 1 { int32 b = 1; } }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,var\"A.Aa\"}}(nothing)"
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
            s, p, ctx = translate_simple_proto("message A { reserved \"b\"; reserved 2; extensions 4 to max; A a = 1; oneof o { sfixed32 s = 3 [default = -1]; }}", Options(add_kwarg_constructors=true))
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method,          p.definitions["A"])      == "PB.reserved_fields(::Type{A}) = (names = [\"b\"], numbers = Union{UnitRange{Int64}, Int64}[2])\n"
            @test strify(CodeGenerators.maybe_generate_extendable_field_numbers_method, p.definitions["A"])      == "PB.extendable_field_numbers(::Type{A}) = Union{UnitRange{Int64}, Int64}[4:536870911]\n"
            @test strify(CodeGenerators.maybe_generate_default_values_method,           p.definitions["A"], ctx) == "PB.default_values(::Type{A}) = (;a = nothing, s = Int32(-1))\n"
            @test strify(CodeGenerators.maybe_generate_oneof_field_types_method,        p.definitions["A"], ctx) == "PB.oneof_field_types(::Type{A}) = (;\n    o = (;s=Int32)\n)\n"
            @test strify(CodeGenerators.maybe_generate_field_numbers_method,            p.definitions["A"])      == "PB.field_numbers(::Type{A}) = (;a = 1, s = 3)\n"
            @test strify(CodeGenerators.maybe_generate_kwarg_constructor_method,        p.definitions["A"], ctx) == "A(;a = nothing, o = nothing) = A(a, o)\n"
        end
    end
end