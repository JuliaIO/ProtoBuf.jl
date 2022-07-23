using ProtocolBuffers
using ProtocolBuffers.CodeGenerators: Options, ResolvedProtoFile, translate, namespace
using ProtocolBuffers.CodeGenerators: import_paths, Context
using ProtocolBuffers.Parsers: parse_proto_file, ParserState, Parsers
using ProtocolBuffers.Lexers: Lexer
using Test

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
        s, p, ctx = translate_simple_proto("message A { message B {}\n B b = 1; }")

        @test haskey(p.definitions, "A")
        @test haskey(p.definitions, "A.B")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A.B"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        # the type name is expanded to include the enclosing type
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].type.enclosing_type == "A"
    end

    @testset "Single nested non-empty message proto file with namespaced field" begin
        s, p, ctx = translate_simple_proto("message A { message B {}\n A.B b = 1; }")

        @test haskey(p.definitions, "A")
        @test haskey(p.definitions, "A.B")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A.B"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].type.namespace == "A"
        @test p.definitions["A"].fields[1].type.namespace_is_type
    end

    @testset "Single self-referential message proto file" begin
        s, p, ctx = translate_simple_proto("message A { A a = 1; }")

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test "A" in p.cyclic_definitions
        @test p.definitions["A"].fields[1].name == "a"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "A"
    end

    for (label_name, label) in (("", Parsers.DEFAULT), ("repeated", Parsers.REPEATED), ("optional", Parsers.OPTIONAL))
        for (type_name, type) in (
                (:uint32, Parsers.UInt32Type), (:uint64, Parsers.UInt64Type), (:int32, Parsers.Int32Type), (:int64, Parsers.Int64Type),
                (:fixed32, Parsers.Fixed32Type), (:fixed64, Parsers.Fixed64Type),  (:sfixed32, Parsers.SFixed32Type), (:sfixed64, Parsers.SFixed64Type),
                (:sint32, Parsers.SInt32Type), (:sint64, Parsers.SInt64Type),  (:float, Parsers.FloatType), (:double, Parsers.DoubleType),
                (:string, Parsers.StringType), (:bytes, Parsers.BytesType),
            )

            @testset "Single message with $label_name $type_name field" begin
                s, p, ctx = translate_simple_proto("message A { $label_name $type_name a = 1; }")

                @test haskey(p.definitions, "A")
                @test p.definitions["A"] isa Parsers.MessageType
                @test p.definitions["A"].fields[1].name == "a"
                @test p.definitions["A"].fields[1].number == 1
                @test p.definitions["A"].fields[1].label == label
                @test p.definitions["A"].fields[1].type isa type
            end
        end
    end

    @testset "Single message with file-imported field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { B b = 1; }
            """,
            Dict("path/to/a" => "message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        # we were able to infer the type of the dependency by finding it among importedm modules
        @test p.definitions["A"].fields[1].type.type_name == "message"
    end

    @testset "Single message with package-imported field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { B b = 1; }
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
        @test p.definitions["A"].fields[1].type.type_name == "message"
        # namespace is "" because B was not prefixed
        @test p.definitions["A"].fields[1].type.namespace == ""
    end

    @testset "Single message with package-imported namespaced field type" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message A { P.B b = 1; }
            """,
            Dict("path/to/a" => "package P; message B {}"),
        )
        p = d["main"].proto_file

        @test haskey(p.definitions, "A")
        @test p.definitions["A"] isa Parsers.MessageType
        @test p.definitions["A"].fields[1].name == "b"
        @test p.definitions["A"].fields[1].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[1].type.name == "B"
        @test p.definitions["A"].fields[1].type.type_name == "message"
        @test p.definitions["A"].fields[1].type.namespace == "P"
    end

    @testset "Message with a field that has to be namespaced to avoid name collision" begin
        s, d, ctx = translate_simple_proto("""
            import "path/to/a";
            message B {}
            message A { P.B b_imported = 1; B b_local = 2; }
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
        @test p.definitions["A"].fields[1].type.type_name == "message"
        @test p.definitions["A"].fields[1].type.namespace == "P"

        @test p.definitions["A"].fields[2].name == "b_local"
        @test p.definitions["A"].fields[2].number == 2
        @test p.definitions["A"].fields[2].type isa Parsers.ReferencedType
        @test p.definitions["A"].fields[2].type.name == "B"
        @test p.definitions["A"].fields[2].type.type_name == "message"
        @test p.definitions["A"].fields[2].type.namespace == ""
    end

    @testset "Referenced Types are assumed to refer to messages defined within the parent message" begin
        s, p, ctx = translate_simple_proto(
            """
            message B { }
            message A {
                B nested_message = 3;
                oneof oneof_field {
                    B oneof_nested_message = 4;
                }
                map<string, B> map_string_nested_message = 5;
                message B {
                    int32 a = 1;
                    A corecursive = 2;
                }
            }
            """
        )
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].type.enclosing_type == "A"
        @test p.definitions["A"].fields[2].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[2].fields[1].type.enclosing_type == "A"
        @test p.definitions["A"].fields[3].type.valuetype.name == "A.B"
        @test p.definitions["A"].fields[3].type.valuetype.enclosing_type == "A"
    end

    @testset "Referenced Types are correctly namespaced when nested" begin
        s, p, ctx = translate_simple_proto(
            """
            message A {
                message B {
                    message B {
                        B b = 2;
                      }
                  A a = 1;
                }
                B b = 3;
              }
            """
        )
        @test p.definitions["A"].fields[1].type.name == "A.B"
        @test p.definitions["A"].fields[1].type.enclosing_type == "A"
        @test p.definitions["A"].fields[1].number == 3

        @test p.definitions["A.B"].fields[1].type.name == "A"
        @test p.definitions["A.B"].fields[1].type.enclosing_type === nothing
        @test p.definitions["A.B"].fields[1].number == 1

        @test p.definitions["A.B.B"].fields[1].type.name == "A.B.B"
        @test p.definitions["A.B.B"].fields[1].type.enclosing_type == "A.B"
        @test p.definitions["A.B.B"].fields[1].number == 2
    end
end
