using ProtoBuf
using ProtoBuf.CodeGenerators: Options, ResolvedProtoFile, translate, namespace, jl_typename
using ProtoBuf.CodeGenerators: import_paths, Context, get_all_transitive_imports!
using ProtoBuf.CodeGenerators: resolve_inter_package_references!
using ProtoBuf.Parsers: parse_proto_file, ParserState, Parsers
using ProtoBuf.Lexers: Lexer
using Test

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
    ctx = Context(
        p, r.import_path, d,
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
    foreach(p->get_all_transitive_imports!(p, d), values(d))
    resolve_inter_package_references!(d, options)
    d["main"] =  r
    translate(buf, r, d, options)
    s = String(take!(buf))
    s = join(filter!(!startswith(r"#|$^"), split(s, '\n')), '\n')
    ctx = Context(
        p, r.import_path, d,
        copy(p.cyclic_definitions),
        Ref(get(p.sorted_definitions, length(p.sorted_definitions), "")),
        r.transitive_imports,
        options
    )
    return s, d, ctx
end

@testset "Parsers" begin
    @testset "Single empty message proto file" begin
        s, p, ctx = translate_simple_proto("message A {}")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
    end

    @testset "Single enum proto file" begin
        s, p, ctx = translate_simple_proto("enum A { a = 0; }")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.EnumType
        @test p.definitions["A"].element_names == [:a]
        @test p.definitions["A"].element_values == [0]
    end

    @testset "Trailing semicolon is fine" begin
        s, p, ctx = translate_simple_proto("message A {}; enum B { b = 0; };")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test haskey(p.definitions, "B")
        @test p.definitions["B"] isa Parsers.EnumType
    end

    @testset "Single enum with `allow_alias = true` proto file" begin
        s, p, ctx = translate_simple_proto("enum A { option allow_alias = true; a = 0; b = 0; }")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.EnumType
        @test p.definitions["A"].element_names == [:a, :b]
        @test p.definitions["A"].element_values == [0, 0]
    end

    @testset "Single nested empty message proto file" begin
        s, p, ctx = translate_simple_proto("message A { message B {} }")

        @test haskey(p.definitions, "A")
        @test haskey(p.definitions, "A.B")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A.B"] isa Parsers.MessageType
    end

    @testset "Single nested non-empty message proto file with field" begin
        s, p, ctx = translate_simple_proto("message A { message B {}\n optional B b = 1; }")

        @test haskey(p.definitions, "A")
        @test haskey(p.definitions, "A.B")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A.B"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        # the type name is expanded to include the enclosing type
        @test p.definitions["A"].fields[1].type.name == "A.B"
        p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
    end

    @testset "Single nested non-empty message proto file with namespaced field" begin
        s, p, ctx = translate_simple_proto("message A { message B {}\n optional A.B b = 1; }")

        @test haskey(p.definitions, "A")
        @test haskey(p.definitions, "A.B")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A.B"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
    end

    @testset "Single self-referential message proto file" begin
        s, p, ctx = translate_simple_proto("message A { optional A a = 1; }")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test "A" in p.cyclic_definitions
        @test p.definitions["A"].fields[1].name == "a"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "A"
    end

    for syntax in (("", "syntax = \"proto2\";", "syntax = \"proto3\";"))
        for (label_name, label) in (("", Parsers.DEFAULT), ("repeated", Parsers.REPEATED), ("optional", Parsers.OPTIONAL))
            syntax in ("", "syntax = \"proto2\";") && label_name == "" && continue
            syntax == "syntax = \"proto3\";" && label_name == "required" && continue
            for (type_name, type) in (
                    (:uint32, Parsers.UInt32Type), (:uint64, Parsers.UInt64Type), (:int32, Parsers.Int32Type), (:int64, Parsers.Int64Type),
                    (:fixed32, Parsers.Fixed32Type), (:fixed64, Parsers.Fixed64Type),  (:sfixed32, Parsers.SFixed32Type), (:sfixed64, Parsers.SFixed64Type),
                    (:sint32, Parsers.SInt32Type), (:sint64, Parsers.SInt64Type),  (:float, Parsers.FloatType), (:double, Parsers.DoubleType),
                    (:string, Parsers.StringType), (:bytes, Parsers.BytesType),
                )

                @testset "Single message with $label_name $type_name field with $(syntax == "syntax = \"proto3\";" ? "proto3" : "proto2") syntax" begin
                    s, p, ctx = translate_simple_proto("$syntax message A { $label_name $type_name a = 1; }")

                    @test haskey(p.definitions, "A")
                    @test p.definitions["A"] isa Parsers.MessageType
                    @test p.definitions["A"].fields[1].name == "a"
                    @test p.definitions["A"].fields[1].number == 1
                    @test p.definitions["A"].fields[1].label == label
                    @test p.definitions["A"].fields[1].type isa type
                end
            end
        end
    end

    @testset "Single message with file-imported field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { optional B b = 1; }
            """,
            Dict("path/to/a" => "message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        # we were able to infer the type of the dependency by finding it among imported modules
        @test p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
    end

    @testset "Single message with package-imported field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { optional B b = 1; }
            """,
            Dict("path/to/a" => "package P; message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        # we were able to infer the type of the dependency by finding it among imported modules
        @test p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
        @test p.definitions["A"].fields[1].type.package_namespace === "P"
    end

    @testset "Single message with package-imported namespaced field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { optional P.B b = 1; }
            """,
            Dict("path/to/a" => "package P; message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        @test p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
        @test p.definitions["A"].fields[1].type.package_namespace == "P"
        @test p.definitions["A"].fields[1].type.package_import_path == "path/to/a"
    end

    @testset "Message with a field that has to be namespaced to avoid name collision" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message B {}
            message A { optional P.B b_imported = 1; optional B b_local = 2; }
            """,
            Dict("path/to/a" => "package P; message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b_imported"
        @test p.definitions["A"].fields[1].number == 1
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        @test p.definitions["A"].fields[1].type.reference_type == Parsers.MESSAGE
        @test p.definitions["A"].fields[1].type.package_namespace == "P"
        @test p.definitions["A"].fields[1].type.package_import_path == "path/to/a"

        @test p.definitions["A"].fields[2].name == "b_local"
        @test p.definitions["A"].fields[2].number == 2
        @test p.definitions["A"].fields[2].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[2].type.name == "B"
        @test p.definitions["A"].fields[2].type.reference_type == Parsers.MESSAGE
        @test p.definitions["A"].fields[2].type.package_namespace === nothing
        @test p.definitions["A"].fields[2].type.package_import_path === nothing
    end

    @testset "Referenced Types are assumed to refer to messages defined within the parent message" begin
        s, p, ctx = translate_simple_proto(
            """
            message B { }
            message A {
                optional B nested_message = 3;
                oneof oneof_field {
                    B oneof_nested_message = 4;
                }
                map<string, B> map_string_nested_message = 5;
                message B {
                    optional int32 a = 1;
                    optional A corecursive = 2;
                }
            }
            """
        )
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[2].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[3].type.valuetype.name == "A.B"
    end

    @testset "Referenced Types are correctly namespaced when nested" begin
        s, p, ctx = translate_simple_proto(
            """
            message A {
                message B {
                    message B {
                        optional B b = 2;
                    }
                    optional A a = 1;
                }
                optional B b = 3;
              }
            """
        )
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].number == 3

        @test p.definitions["A.B"].fields[1].type.name == "A"
        @test p.definitions["A.B"].fields[1].number == 1

        @test p.definitions["A.B.B"].fields[1].type.name == "A.B.B"
        @test p.definitions["A.B.B"].fields[1].number == 2

        s, p, ctx = translate_simple_proto(
            """
            message A {
                message B {
                    oneof oneof_field {
                        C c = 1;
                    }
                }
                optional B b = 3;
                message C {
                    optional uint32 i = 2;
                }
              }
            """
        )
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A.B"].fields[1].fields[1].type.name == "A.C"

        @test_throws ErrorException translate_simple_proto(
            """
            message A {
                message B {
                    oneof oneof_field {
                        C c = 1;
                    }
                }
                optional B b = 3;
                message D {
                    message C {
                        optional uint32 i = 2;
                    }
                }
              }
            """
        )
    end

    @testset "Messages are not allowed to name-clash with modules" begin
        @test_throws ErrorException translate_simple_proto("""
            package Foo;

            message Foo {}
            """)

        @test_throws ErrorException translate_simple_proto("""
            import "main2";

            message Foo {}
            """,
            Dict("main2" => "package Foo;"))
    end

    @testset "Leading dot means resolving starts from outermost scope" begin
        s, d, ctx = translate_simple_proto("""
            message A {
                message B {
                    message A {
                        optional A inner = 1;
                        optional .A outer = 2;
                    }
                }
            }
            """)
        @test d.definitions["A.B.A"].fields[1].type.name == "A.B.A"
        @test d.definitions["A.B.A"].fields[2].type.name == "A"

        s, d, ctx = translate_simple_proto("""
            import "main2";
            message T {
                optional G.A.B.A inner = 1;
                optional .G.A outer = 2;
                optional G.A also_outer = 3;
            }
            """,
            Dict("main2" => """
            package G;
            message A {
                message B {
                    message A {
                    }
                }
            }
            """
            ))
        p = d["main"].proto_file
        @test p.definitions["T"].fields[1].type.name == "A.B.A"
        @test p.definitions["T"].fields[2].type.name == "A"
        @test p.definitions["T"].fields[3].type.name == "A"
    end
end
