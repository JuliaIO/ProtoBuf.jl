using ProtoBuf
using ProtoBuf.CodeGenerators: Options, ResolvedProtoFile, translate, namespace
using ProtoBuf.CodeGenerators: import_paths, Context, codegen
using ProtoBuf.CodeGenerators: generate_struct, codegen_cylic_stub, _generate_struct_alias
using ProtoBuf.CodeGenerators: resolve_inter_package_references!, get_all_transitive_imports!
using ProtoBuf.CodeGenerators: CodeGenerators, types_needing_params
using ProtoBuf.Parsers: parse_proto_file, ParserState, Parsers
using ProtoBuf.Lexers: Lexer
using EnumX
using Test

strify(f, args...) = (io = IOBuffer(); f(io, args...); String(take!(io)))
codegen_str(args...) = strify(codegen, args...)
function generate_struct_str(def, ctx, ; remaining=copy(ctx._remaining_cyclic_defs))
    ctx._toplevel_raw_name[] = def.name
    if def.name in keys(ctx._types_and_oneofs_requiring_type_params)
        original_remaining = copy(ctx._remaining_cyclic_defs)
        empty!(ctx._remaining_cyclic_defs)
        union!(ctx._remaining_cyclic_defs, remaining)
        stub = strify(codegen_cylic_stub, def, ctx)
        empty!(ctx._remaining_cyclic_defs) # aliases are printed after all stubs, at which point the remaining defs are empty
        alias = strify(_generate_struct_alias, def, ctx)
        union!(ctx._remaining_cyclic_defs, original_remaining)
        return stub * alias
    else
        strify(generate_struct, def, ctx)
    end
end


function translate_simple_proto(str::String, options=Options())
    buf = IOBuffer()
    l = Lexer(IOBuffer(str), "main")
    p = parse_proto_file(ParserState(l))
    r = ResolvedProtoFile("main", p)
    d = Dict{String, ResolvedProtoFile}("main" => r)
    foreach(p->get_all_transitive_imports!(p, d), values(d))
    resolve_inter_package_references!(d, options)
    translate(buf, r, d, options)
    s = String(take!(buf))
    s = join(filter!(!startswith(r"#|$^"), split(s, '\n')), '\n')
    ncyclic = length(p.cyclic_definitions)
    ctx = Context(
        p, r.import_path, d,
        types_needing_params(@view(p.sorted_definitions[end-ncyclic+1:end]), p, options),
        copy(p.cyclic_definitions),
        Ref(get(p.sorted_definitions, length(p.sorted_definitions), "")),
        r.transitive_imports,
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
    foreach(p->get_all_transitive_imports!(p, d), values(d))
    resolve_inter_package_references!(d, options)
    original_cyclic_definitions = copy(p.cyclic_definitions)
    translate(buf, r, d, options)
    s = String(take!(buf))
    s = join(filter!(!startswith(r"#|$^"), split(s, '\n')), '\n')
    ncyclic = length(original_cyclic_definitions)
    ctx = Context(
        p, r.import_path, d,
        types_needing_params(@view(p.sorted_definitions[end-ncyclic+1:end]), p, options),
        copy(original_cyclic_definitions),
        Ref(get(p.sorted_definitions, length(p.sorted_definitions), "")),
        r.transitive_imports,
        options
    )
    return s, d, ctx
end

@testset "translate" begin
    @testset "Minimal proto file" begin
        s, p, ctx = translate_simple_proto("", Options(always_use_modules=false))
        @test s == """
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("", Options(always_use_modules=true))
        @test s == """
        module main_pb
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx
        end # module"""
    end

    @testset "Minimal proto file with common abstract type" begin
        s, p, ctx = translate_simple_proto("", Options(always_use_modules=false, common_abstract_type=true))
        @test s == """
        import ProtoBuf as PB
        using ProtoBuf: AbstractProtoBufMessage
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx"""
    end

    @testset "Minimal proto file with file imports" begin
        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => ""), Options(always_use_modules=false))
        @test s == """
        include("a_pb.jl")
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => ""), Options(always_use_modules=true))
        @test s == """
        module main_pb
        include("a_pb.jl")
        import a_pb
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx
        end # module"""
    end

    @testset "Minimal proto file with package imports" begin
        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => "package p;"), Options(always_use_modules=false))
        @test s == """
        include($(repr(joinpath("p", "p.jl"))))
        import .p
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx"""

        s, p, ctx = translate_simple_proto("import \"path/to/a\";", Dict("path/to/a" => "package p;"), Options(always_use_modules=true))
        @test s == """
        module main_pb
        include($(repr(joinpath("p", "p.jl"))))
        import .p
        import ProtoBuf as PB
        using ProtoBuf: OneOf
        using ProtoBuf.EnumX: @enumx
        end # module"""
    end

    @testset "`force_required` option makes optional fields required" begin
        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"
    end

    @testset "Struct fields are optional when not marked required" begin
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A {} message B { A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        s, p, ctx = translate_simple_proto("message A {} message B { optional A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,A}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        s, p, ctx = translate_simple_proto("message A {} message B { required A a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::A
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) === nothing
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{A}()"
    end

    @testset "Struct fields are optional when the type is self referential" begin
        s, p, ctx = translate_simple_proto("message B { optional B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message B { B a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message B { required B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        s, p, ctx = translate_simple_proto("message B { optional B a = 1; }")
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B
            a::Union{Nothing,B}
        end
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"
    end

    @testset "Struct fields are optional when the type has a mutually recursive dependency" begin
        # A <-> B
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { A a = 1; }")
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Union{Nothing,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        # A <-> B, A is repeated
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { repeated A a = 1; }")
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Vector{var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "Vector{A}()"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "PB.BufferedVector{A}()"

        # A <-> B, B is "required" by the user, but it still has to be optional to break the recursion
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { A a = 1; }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Union{Nothing,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        # A <-> B, A is a required field, but it still has to be optional to break the recursion
        s, p, ctx = translate_simple_proto("message A { optional B b = 1; } message B { required A a = 1; }")
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Union{Nothing,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        # A <-> B, A explicitly optional
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { optional A a = 1; }")
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Union{Nothing,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
    end

    @testset "Mutually recursive dependency involving a group field" begin
        s, p, ctx = translate_simple_proto("syntax = \"proto2\"; message A { optional B b = 1; } message B { optional group G = 1 { optional A a = 2; }; }")
        @assert p.sorted_definitions == ["A", "B.G", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B.G", "B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B.G"], ctx, remaining=Set{String}(["B.G", "B"])) == """
        struct var"##Stub#B.G"{T1<:var"##Abstract#B"} <: var"##Abstract#B.G"
            a::Union{Nothing,var"##Stub#A"{T1}}
        end
        const var"B.G" = var"##Stub#B.G"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["B.G"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B.G"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            g::Union{Nothing,var"##Stub#B.G"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,var\"B.G\"}}(nothing)"
    end

    @testset "Mutually recursive dependency involving a map field" begin
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { map<string, A> m = 1; }")
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            m::Dict{String,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "Dict{String,A}()"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Dict{String,A}()"
    end

    @testset "Mutually recursive dependency involving where type param is shared with a different dependency" begin
        # Basic message dependencies
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { A a = 1; B b = 2; C c = 3; }
        message B { A a = 1; }
        message C { A a = 1; B b = 2; C c = 3; }
        """)
        @assert p.sorted_definitions == ["B", "A", "C"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "C"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#C"} <: var"##Abstract#A"
            a::Union{Nothing,var"##Stub#A"{T1}}
            b::Union{Nothing,var"##Stub#B"{var"##Stub#A"{T1}}}
            c::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#C"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[2], ctx) == "Ref{Union{Nothing,B}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[3], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[3], ctx) == "Ref{Union{Nothing,C}}(nothing)"

        # Dependencies through maps and parametrized oneofs
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { A a = 1; oneof o { A a = 2; B b = 3; C c = 4; }; map<string,A> d1 = 5; map<string,B> d2 = 6; map<string,C> d3 = 7;  }
        message B { A a = 1; }
        message C { A a = 1; B b = 2; C c = 3; }
        """, Options(parametrize_oneofs=true))
        @assert p.sorted_definitions == ["B", "A", "C"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "C"])) == """
        struct var"##Stub#A"{T1<:Union{Nothing,OneOf{<:Union{var"##Abstract#A",var"##Abstract#B",var"##Abstract#C"}}},T2<:var"##Abstract#C"} <: var"##Abstract#A"
            a::Union{Nothing,var"##Stub#A"{<:Union{Nothing,<:OneOf},T2}}
            o::T1
            d1::Dict{String,var"##Stub#A"{<:Union{Nothing,<:OneOf},T2}}
            d2::Dict{String,var"##Stub#B"{var"##Stub#A"{<:Union{Nothing,<:OneOf},T2}}}
            d3::Dict{String,T2}
        end
        const A = var"##Stub#A"{<:Union{Nothing,<:OneOf},var"##Stub#C"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[3], ctx) == "Dict{String,A}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[3], ctx) == "Dict{String,A}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[5], ctx) == "Dict{String,C}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[5], ctx) == "Dict{String,C}()"

        # Dependencies through maps and non-parametrized oneofs
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { A a = 1; oneof o { A a = 2; B b = 3; C c = 4; }; map<string,A> d1 = 5; map<string,B> d2 = 6; map<string,C> d3 = 7;  }
        message B { A a = 1; }
        message C { A a = 1; B b = 2; C c = 3; }
        """)
        @assert p.sorted_definitions == ["B", "A", "C"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "C"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#C"} <: var"##Abstract#A"
            a::Union{Nothing,var"##Stub#A"{T1}}
            o::Union{Nothing,OneOf{<:Union{var"##Stub#A"{T1},var"##Stub#B"{var"##Stub#A"{T1}},T1}}}
            d1::Dict{String,var"##Stub#A"{T1}}
            d2::Dict{String,var"##Stub#B"{var"##Stub#A"{T1}}}
            d3::Dict{String,T1}
        end
        const A = var"##Stub#A"{var"##Stub#C"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[3], ctx) == "Dict{String,A}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[3], ctx) == "Dict{String,A}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[5], ctx) == "Dict{String,C}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[5], ctx) == "Dict{String,C}()"
    end

    @testset "Type params through transitive dependencies" begin
        # A will get parametrized on C, but only depends on C through its dependencies, B and D
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { B b = 1; D d = 2; oneof o { B b = 3; D d = 4; }; map<string,B> d1 = 5; map<string,D> d2 = 6; }
        message B { C c = 1; }
        message D { C c = 1; }
        message C { A a = 1; B b = 2; C c = 3; }
        """)
        @assert p.sorted_definitions == ["B", "D", "A", "C"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "C"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#C"} <: var"##Abstract#A"
            b::Union{Nothing,var"##Stub#B"{T1}}
            d::Union{Nothing,var"##Stub#D"{T1}}
            o::Union{Nothing,OneOf{<:Union{var"##Stub#B"{T1},var"##Stub#D"{T1}}}}
            d1::Dict{String,var"##Stub#B"{T1}}
            d2::Dict{String,var"##Stub#D"{T1}}
        end
        const A = var"##Stub#A"{var"##Stub#C"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[2], ctx) == "Ref{Union{Nothing,D}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[3], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[3], ctx) == "nothing"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[5], ctx) == "Dict{String,D}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[5], ctx) == "Dict{String,D}()"

        # Parametrized oneof
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { B b = 1; D d = 2; oneof o { B b = 3; D d = 4; }; map<string,B> d1 = 5; map<string,D> d2 = 6; }
        message B { C c = 1; }
        message D { C c = 1; }
        message C { A a = 1; B b = 2; C c = 3; }
        """, Options(parametrize_oneofs=true))
        @assert p.sorted_definitions == ["B", "D", "A", "C"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "C"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#C",T2<:Union{Nothing,OneOf{<:Union{var"##Abstract#B",var"##Abstract#D"}}}} <: var"##Abstract#A"
            b::Union{Nothing,var"##Stub#B"{T1}}
            d::Union{Nothing,var"##Stub#D"{T1}}
            o::T2
            d1::Dict{String,var"##Stub#B"{T1}}
            d2::Dict{String,var"##Stub#D"{T1}}
        end
        const A = var"##Stub#A"{var"##Stub#C",<:Union{Nothing,<:OneOf}}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[2], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[2], ctx) == "Ref{Union{Nothing,D}}(nothing)"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[3], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[3], ctx) == "nothing"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[4], ctx) == "Dict{String,B}()"
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[5], ctx) == "Dict{String,D}()"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[5], ctx) == "Dict{String,D}()"
    end

    @testset "Different oneof fields shouldn't share type param even their schemas are identical" begin
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { oneof o1 { string s1 = 1; sint32 i1 = 2; }; oneof o2 { string s2 = 3; sint32 i2 = 4; }; }
        """, Options(parametrize_oneofs=true))
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A{T1<:Union{Nothing,OneOf{<:Union{String,Int32}}},T2<:Union{Nothing,OneOf{<:Union{String,Int32}}}}
            o1::T1
            o2::T2
        end
        """
    end

    @testset "Constructors are adding necessary type params to stub definitions" begin
        s, p, ctx = translate_simple_proto("""
        syntax = "proto3";
        message A { oneof o1 { int32 a = 1; }; B b = 2; oneof o2 { uint32 u = 3; }; }
        message B { A a = 1; }
        """, Options(parametrize_oneofs=true, add_kwarg_constructors=true))
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["A", "B"])) == """
        struct var"##Stub#A"{T1<:Union{Nothing,OneOf{Int32}},T2<:var"##Abstract#B",T3<:Union{Nothing,OneOf{UInt32}}} <: var"##Abstract#A"
            o1::T1
            b::Union{Nothing,T2}
            o2::T3
        end
        const A = var"##Stub#A"{<:Union{Nothing,<:OneOf},var"##Stub#B",<:Union{Nothing,<:OneOf}}
        """
        @test strify(CodeGenerators.maybe_generate_constructor_for_type_alias, p.definitions["A"], ctx) == "A(o1, b, o2) = var\"##Stub#A\"{typeof(o1),B,typeof(o2)}(o1, b, o2)\n"
        @test strify(CodeGenerators.maybe_generate_kwarg_constructor_method, p.definitions["A"], ctx) == "A(;o1 = nothing, b = nothing, o2 = nothing) = var\"##Stub#A\"{typeof(o1),B,typeof(o2)}(o1, b, o2)\n"
    end

    @testset "Simple type with a common abstract type" begin
        s, p, ctx = translate_simple_proto("message B { optional int32 b = 1; }", Options(always_use_modules=false, common_abstract_type=true))
        @test generate_struct_str(p.definitions["B"], ctx) == """
        struct B <: AbstractProtoBufMessage
            b::Int32
        end
        """
    end

    @testset "Mutually recursive type with a common abstract type" begin
        s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { B b = 1; } message B { A a = 1; }", Options(always_use_modules=false, common_abstract_type=true))
        @assert p.sorted_definitions == ["A", "B"]
        @test generate_struct_str(p.definitions["A"], ctx, remaining=Set{String}(["B", "A"])) == """
        struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
            b::Union{Nothing,T1}
        end
        const A = var"##Stub#A"{var"##Stub#B"}
        """
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,B}}(nothing)"

        @test generate_struct_str(p.definitions["B"], ctx, remaining=Set{String}(["B"])) == """
        struct var"##Stub#B" <: var"##Abstract#B"
            a::Union{Nothing,var"##Stub#A"{var"##Stub#B"}}
        end
        const B = var"##Stub#B"
        """
        @test CodeGenerators.jl_default_value(p.definitions["B"].fields[1], ctx) == "nothing"
        @test CodeGenerators.jl_init_value(p.definitions["B"].fields[1], ctx) == "Ref{Union{Nothing,A}}(nothing)"
        @test occursin("abstract type var\"##Abstract#A\" <: AbstractProtoBufMessage end", s)
        @test occursin("abstract type var\"##Abstract#B\" <: AbstractProtoBufMessage end", s)
    end

    @testset "Empty struct with common abstract type" begin
        s, p, ctx = translate_simple_proto("message A { }", Options(always_use_modules=false, common_abstract_type=true))
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A <: AbstractProtoBufMessage end
        """
    end

    @testset "OneOf field codegen" begin
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; } }", Options(parametrize_oneofs=true))
        @test occursin("""
        struct A{T1<:Union{Nothing,OneOf{Int32}}}
            a::T1
        end""", s)

        # Self-referential parametrized OneOf and duplicate variant types
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } }", Options(parametrize_oneofs=true))
        @test occursin("""
        struct A{T1<:Union{Nothing,OneOf{<:Union{Int32,UInt32,var"##Abstract#A"}}}} <: var"##Abstract#A"
            a::T1
        end""", s)

        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; } }", Options(parametrize_oneofs=true))
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A{T1<:Union{Nothing,OneOf{<:Union{Int32,UInt32}}}}
            a::T1
        end
        """

        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } }", Options(parametrize_oneofs=false))
        @test occursin("""
        struct A
            a::Union{Nothing,OneOf{<:Union{Int32,UInt32,A}}}
        end""", s)

        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; } }", Options(parametrize_oneofs=false))
        @test generate_struct_str(p.definitions["A"], ctx) == """
        struct A
            a::Union{Nothing,OneOf{<:Union{Int32,UInt32}}}
        end
        """
    end

    @testset "`force_required` OneOf field" begin
        s, p, ctx = translate_simple_proto("message B { oneof a { int32 a = 1; } }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test occursin("""
        struct B
            a::OneOf{Int32}
        end""", s)

        s, p, ctx = translate_simple_proto("message B { oneof a { int32 a = 1; uint32 b = 2; } }", Options(force_required=Dict("main" => Set(["B.a"]))))
        @test occursin("""
        struct B
            a::OneOf{<:Union{Int32,UInt32}}
        end""", s)

        s, p, ctx = translate_simple_proto("message B { oneof a { int32 a = 1; } }", Options(force_required=Dict("main" => Set(["B.a"])), parametrize_oneofs=true))
        @test occursin("""
        struct B{T1<:OneOf{Int32}}
            a::T1
        end""", s)

        s, p, ctx = translate_simple_proto("message B { oneof a { int32 a = 1; uint32 b = 2; } }", Options(force_required=Dict("main" => Set(["B.a"])), parametrize_oneofs=true))
        @test occursin("""
        struct B{T1<:OneOf{<:Union{Int32,UInt32}}}
            a::T1
        end""", s)
    end

    @testset "Basic enum codegen" begin
        s, p, ctx = translate_simple_proto("enum A { a = 0; b = 1; }")
        @test codegen_str(p.definitions["A"], ctx) == """
        @enumx A a=0 b=1
        """
    end

    @testset "Basic Types" begin
        s, p, ctx = translate_simple_proto("message A { optional bool a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Bool"
        s, p, ctx = translate_simple_proto("message A { optional uint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt32"
        s, p, ctx = translate_simple_proto("message A { optional uint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt64"
        s, p, ctx = translate_simple_proto("message A { optional int32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { optional int64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { optional sint32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { optional sint64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { optional fixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt32"
        s, p, ctx = translate_simple_proto("message A { optional fixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "UInt64"
        s, p, ctx = translate_simple_proto("message A { optional sfixed32 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int32"
        s, p, ctx = translate_simple_proto("message A { optional sfixed64 a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Int64"
        s, p, ctx = translate_simple_proto("message A { optional float a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Float32"
        s, p, ctx = translate_simple_proto("message A { optional double a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Float64"
        s, p, ctx = translate_simple_proto("message A { optional string a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "String"
        s, p, ctx = translate_simple_proto("message A { optional bytes a = 1; }")
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
        s, p, ctx = translate_simple_proto("message A { map<string,A> a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Dict{String,A}"
        s, p, ctx = translate_simple_proto("message A { oneof a { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "OneOf{Union{Int32,UInt32,A}}"
        s, p, ctx = translate_simple_proto("message A { repeated A a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{A}"
        s, p, ctx = translate_simple_proto("message B { repeated A a = 1; } message A { repeated B b = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{B}"
        s, p, ctx = translate_simple_proto("message B { oneof o { int32 b = 1; int32 c = 2; uint32 d = 3; A e = 4; } } message A { repeated B b = 1; }", Options(parametrize_oneofs=true))
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Vector{<:B}"
        s, p, ctx = translate_simple_proto("message B { repeated A a = 1; } message A { map<string,B> a = 1; }")
        @test CodeGenerators.jl_typename(p.definitions["A"].fields[1], ctx) == "Dict{String,B}"
    end

    @testset "Default values" begin
        s, p, ctx = translate_simple_proto("message A { optional bool a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "false"
        s, p, ctx = translate_simple_proto("message A { optional uint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { optional uint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { optional int32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional int64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional sint32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional sint64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional fixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { optional fixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed32 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed64 a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional float a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Float32)"
        s, p, ctx = translate_simple_proto("message A { optional double a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "zero(Float64)"
        s, p, ctx = translate_simple_proto("message A { optional string a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "\"\""
        s, p, ctx = translate_simple_proto("message A { optional bytes a = 1; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt8[]"

        s, p, ctx = translate_simple_proto("message A { optional bool a = 1 [default=true]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "true"
        s, p, ctx = translate_simple_proto("message A { optional uint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { optional uint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { optional int32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional int64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional sint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional sint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional fixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { optional fixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional float a = 1 [default=1.0]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Float32(1.0)"
        s, p, ctx = translate_simple_proto("message A { optional double a = 1  [default=1.0]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "Float64(1.0)"
        s, p, ctx = translate_simple_proto("message A { optional string a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "\"1\""
        s, p, ctx = translate_simple_proto("message A { optional bytes a = 1 [default=\"1\"]; }")
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
        s, p, ctx = translate_simple_proto("message A { optional group Aa = 1 { optional int32 b = 1; } }")
        @test CodeGenerators.jl_default_value(p.definitions["A"].fields[1], ctx) == "nothing"

    end

    @testset "Initial values" begin
        s, p, ctx = translate_simple_proto("message A { optional bool a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "false"
        s, p, ctx = translate_simple_proto("message A { optional uint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { optional uint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { optional int32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional int64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional sint32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional sint64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional fixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt32)"
        s, p, ctx = translate_simple_proto("message A { optional fixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(UInt64)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed32 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int32)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed64 a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Int64)"
        s, p, ctx = translate_simple_proto("message A { optional float a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Float32)"
        s, p, ctx = translate_simple_proto("message A { optional double a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "zero(Float64)"
        s, p, ctx = translate_simple_proto("message A { optional string a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "\"\""
        s, p, ctx = translate_simple_proto("message A { optional bytes a = 1; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt8[]"

        s, p, ctx = translate_simple_proto("message A { optional bool a = 1 [default=true]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "true"
        s, p, ctx = translate_simple_proto("message A { optional uint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { optional uint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { optional int32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional int64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional sint32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional sint64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional fixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt32(0x00000001)"
        s, p, ctx = translate_simple_proto("message A { optional fixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "UInt64(0x0000000000000001)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed32 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int32(1)"
        s, p, ctx = translate_simple_proto("message A { optional sfixed64 a = 1 [default=1]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Int64(1)"
        s, p, ctx = translate_simple_proto("message A { optional float a = 1 [default=1.0]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Float32(1.0)"
        s, p, ctx = translate_simple_proto("message A { optional double a = 1  [default=1.0]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Float64(1.0)"
        s, p, ctx = translate_simple_proto("message A { optional string a = 1 [default=\"1\"]; }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "\"1\""
        s, p, ctx = translate_simple_proto("message A { optional bytes a = 1 [default=\"1\"]; }")
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
        s, p, ctx = translate_simple_proto("message A { optional group Aa = 1 { optional int32 b = 1; } }")
        @test CodeGenerators.jl_init_value(p.definitions["A"].fields[1], ctx) == "Ref{Union{Nothing,var\"A.Aa\"}}(nothing)"
    end

    @testset "Metadata methods" begin
        @testset "metadata_methods have generic fallback" begin
            s, p, ctx = translate_simple_proto("message A { } enum Foo { }")
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method, p.definitions["A"]) == ""
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method, p.definitions["Foo"]) == ""
            @test strify(CodeGenerators.maybe_generate_extendable_field_numbers_method, p.definitions["A"]) == ""
            @test strify(CodeGenerators.maybe_generate_default_values_method, p.definitions["A"], ctx) == ""
            @test strify(CodeGenerators.maybe_generate_oneof_field_types_method, p.definitions["A"], ctx) == ""
            @test strify(CodeGenerators.maybe_generate_field_numbers_method, p.definitions["A"]) == ""

            mod = Module()
            Core.eval(mod, Meta.parse(s))
            @test reserved_fields(mod.main_pb.A) == (names = String[], numbers = Union{Int,UnitRange{Int}}[])
            @test reserved_fields(mod.main_pb.Foo.T) == (names = String[], numbers = Union{Int,UnitRange{Int}}[])
            @test extendable_field_numbers(mod.main_pb.A) == Union{Int,UnitRange{Int}}[]
            @test default_values(mod.main_pb.A) == (;)
            @test oneof_field_types(mod.main_pb.A) == (;)
            @test field_numbers(mod.main_pb.A) == (;)
        end

        @testset "metadata_methods are generated when needed" begin
            s, p, ctx = translate_simple_proto("syntax = \"proto3\"; message A { reserved \"b\"; reserved 2; extensions 4 to max; A a = 1; oneof o { sfixed32 s = 3 [default = -1]; }}", Options(add_kwarg_constructors=true))
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method,          p.definitions["A"])      == "PB.reserved_fields(::Type{A}) = (names = [\"b\"], numbers = Union{Int,UnitRange{Int}}[2])\n"
            @test strify(CodeGenerators.maybe_generate_extendable_field_numbers_method, p.definitions["A"])      == "PB.extendable_field_numbers(::Type{A}) = Union{Int,UnitRange{Int}}[4:536870911]\n"
            @test strify(CodeGenerators.maybe_generate_default_values_method,           p.definitions["A"], ctx) == "PB.default_values(::Type{A}) = (;a = nothing, s = Int32(-1))\n"
            @test strify(CodeGenerators.maybe_generate_oneof_field_types_method,        p.definitions["A"], ctx) == "PB.oneof_field_types(::Type{A}) = (;\n    o = (;s=Int32),\n)\n"
            @test strify(CodeGenerators.maybe_generate_field_numbers_method,            p.definitions["A"])      == "PB.field_numbers(::Type{A}) = (;a = 1, s = 3)\n"
            @test strify(CodeGenerators.maybe_generate_kwarg_constructor_method,        p.definitions["A"], ctx) == "A(;a = nothing, o = nothing) = A(a, o)\n"
        end

        @testset "reserved fields are available for enums" begin
            s, p, ctx = translate_simple_proto("""
            enum Foo {
                reserved 2, 15, 9 to 11, 40 to max;
                reserved "FOO", "BAR";
              }
            """)
            @test strify(CodeGenerators.maybe_generate_reserved_fields_method, p.definitions["Foo"]) =="PB.reserved_fields(::Type{Foo.T}) = (names = [\"FOO\", \"BAR\"], numbers = Union{Int,UnitRange{Int}}[2, 15, 9:11, 40:536870911])\n"
        end
    end

    @testset "Imports within a leaf module which name-clashes with top module" begin
        s, d, ctx = translate_simple_proto(
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
        );
        @test  d["main"].proto_file.definitions["FromA"].fields[1].type.package_namespace == "var\"#A\".B"
    end
end
