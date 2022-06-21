using ProtocolBuffers: Lexers
using .Lexers: Tokens

const KEYWORDS_AND_TYPES = Dict{String, Tokens.Kind}()
@test allunique(Lexers._PROTOBUF_TYPES_AND_KEYWORDS)
for k in instances(Tokens.Kind)
    if Tokens.is_reserved_word(k) || k == Tokens.TRUE || k == Tokens.FALSE
        KEYWORDS_AND_TYPES[lowercase(string(k))] = k
    end
end
@test isempty(symdiff(keys(KEYWORDS_AND_TYPES), Lexers._PROTOBUF_TYPES_AND_KEYWORDS))


function lexer_test(s, k::Union{Tokens.Kind, Tokens.TokenError}, value=s)
    toks = collect(Lexers.Lexer(IOBuffer(s)))
    pop!(toks) # pop Token.ENDMARKER
    @test length(toks) == 1
    tok = toks[1]
    @testset "Lex $(repr(s)), expected token: $(k), (val: $(repr(value)))" begin
        if isa(k, Tokens.TokenError)
            @test tok.kind == Tokens.ERROR
            @test tok.error == k
        else
            @test tok.kind == k
            @test tok.error == Tokens.NO_ERROR
        end
        @test tok.val == value
    end
end

function lexer_test_first(s, k::Union{Tokens.Kind, Tokens.TokenError}, value=s)
    tok = first(collect(Lexers.Lexer(IOBuffer(s))))
    @testset "Lex $(repr(s)), expected token: $(k), (val: $(repr(value)))" begin
        if isa(k, Tokens.TokenError)
            @test tok.kind == Tokens.ERROR
            @test tok.error == k
        else
            @test tok.kind == k
            @test tok.error == Tokens.NO_ERROR
        end
        @test tok.val == value
    end
end

@testset "Lexers" begin
    @testset "comment" begin
        lexer_test("#", Tokens.COMMENT)
        lexer_test("##", Tokens.COMMENT)
        lexer_test_first("## \n aa", Tokens.COMMENT, "## ")

        lexer_test("//", Tokens.COMMENT)
        lexer_test("///", Tokens.COMMENT)
        lexer_test_first("// \n aa", Tokens.COMMENT, "// ")

        lexer_test("/**/", Tokens.COMMENT)
        lexer_test("/*a\nb*/", Tokens.COMMENT)
        lexer_test("/*/**/*/", Tokens.COMMENT)
        lexer_test("/*/**//**//*/**/*/*/", Tokens.COMMENT)
        lexer_test("/* /* */", Tokens.EOF_MULTICOMMENT)
    end

    @testset "string literals" begin
        lexer_test("\"a\"", Tokens.STRING_LIT)
        lexer_test("'a'", Tokens.STRING_LIT)
        lexer_test("\"proto3\"", Tokens.STRING_LIT)
        lexer_test("'\uffff'", Tokens.STRING_LIT)
        lexer_test("'\xff'", Tokens.STRING_LIT)
        lexer_test("'\777'", Tokens.STRING_LIT)
        lexer_test("'\U000fffff'", Tokens.STRING_LIT)
        lexer_test("'\U0010ffff'", Tokens.STRING_LIT)
    end

    @testset "numeric literals" begin
        lexer_test("0", Tokens.DEC_INT_LIT)
        lexer_test("01", Tokens.OCT_INT_LIT)
        lexer_test("123", Tokens.DEC_INT_LIT)
        lexer_test("123E", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123E+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123E-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123E-0", Tokens.FLOAT_LIT)
        lexer_test("123E-1", Tokens.FLOAT_LIT)
        lexer_test("123E-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123E+0", Tokens.FLOAT_LIT)
        lexer_test("123E+1", Tokens.FLOAT_LIT)
        lexer_test("123E+01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123e", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123e+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123e-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123e-0", Tokens.FLOAT_LIT)
        lexer_test("123e-1", Tokens.FLOAT_LIT)
        lexer_test("123e-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123e+0", Tokens.FLOAT_LIT)
        lexer_test("123e+1", Tokens.FLOAT_LIT)
        lexer_test("123e+01", Tokens.INVALID_NUMERIC_CONSTANT)

        lexer_test("0.0", Tokens.FLOAT_LIT)
        lexer_test("0.456", Tokens.FLOAT_LIT)
        lexer_test_first("01.456", Tokens.OCT_INT_LIT, "01")
        lexer_test("123.4", Tokens.FLOAT_LIT)
        lexer_test("123.456", Tokens.FLOAT_LIT)
        lexer_test("51.5", Tokens.FLOAT_LIT)
        lexer_test_first("123E.456", Tokens.INVALID_NUMERIC_CONSTANT, "123E")
        lexer_test("123.456E", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456E+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456E-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456E-0", Tokens.FLOAT_LIT)
        lexer_test("123.456E-1", Tokens.FLOAT_LIT)
        lexer_test("123.456E-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456E+0", Tokens.FLOAT_LIT)
        lexer_test("123.456E+1", Tokens.FLOAT_LIT)
        lexer_test("123.456E+01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456e", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456e+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456e-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456e-0", Tokens.FLOAT_LIT)
        lexer_test("123.456e-1", Tokens.FLOAT_LIT)
        lexer_test("123.456e-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.456e+0", Tokens.FLOAT_LIT)
        lexer_test("123.456e+1", Tokens.FLOAT_LIT)
        lexer_test("123.456e+01", Tokens.INVALID_NUMERIC_CONSTANT)

        lexer_test("0.", Tokens.FLOAT_LIT)
        lexer_test_first("01.", Tokens.OCT_INT_LIT, "01")
        lexer_test("123.", Tokens.FLOAT_LIT)
        lexer_test_first("123E.", Tokens.INVALID_NUMERIC_CONSTANT, "123E")
        lexer_test("123.E", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.E+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.E-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.E-0", Tokens.FLOAT_LIT)
        lexer_test("123.E-1", Tokens.FLOAT_LIT)
        lexer_test("123.E-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.E+0", Tokens.FLOAT_LIT)
        lexer_test("123.E+1", Tokens.FLOAT_LIT)
        lexer_test("123.E+01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.e", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.e+", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.e-", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.e-0", Tokens.FLOAT_LIT)
        lexer_test("123.e-1", Tokens.FLOAT_LIT)
        lexer_test("123.e-01", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("123.e+0", Tokens.FLOAT_LIT)
        lexer_test("123.e+1", Tokens.FLOAT_LIT)
        lexer_test("123.e+01", Tokens.INVALID_NUMERIC_CONSTANT)

        lexer_test("0x", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("0x0123456789abcdefABCDEF", Tokens.HEX_INT_LIT)
        lexer_test_first("0xG", Tokens.INVALID_NUMERIC_CONSTANT, "0x")
        lexer_test_first("0x1G", Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION, "0x1")
        lexer_test("0X", Tokens.INVALID_NUMERIC_CONSTANT)
        lexer_test("0X0123456789abcdefABCDEF", Tokens.HEX_INT_LIT)
        lexer_test_first("0X1G", Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION, "0X1")

        lexer_test("01234567", Tokens.OCT_INT_LIT)
        lexer_test_first("08", Tokens.INVALID_NUMERIC_CONSTANT, "0")
        lexer_test_first("01G", Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION, "01")
        lexer_test_first("0G", Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION, "0")
    end

    @testset "single letter lexical items" begin
        lexer_test("{", Tokens.LBRACE, "")
        lexer_test("}", Tokens.RBRACE, "")
        lexer_test(">", Tokens.GREATER, "")
        lexer_test("<", Tokens.LESS, "")
        lexer_test(",", Tokens.COMMA, "")
        lexer_test(".", Tokens.DOT, "")
        lexer_test("(", Tokens.LPAREN, "")
        lexer_test(")", Tokens.RPAREN, "")
        lexer_test("[", Tokens.LBRACKET, "")
        lexer_test("]", Tokens.RBRACKET, "")
        lexer_test("+", Tokens.PLUS, "")
        lexer_test("-", Tokens.MINUS, "")
        lexer_test(":", Tokens.COLON, "")
        lexer_test("=", Tokens.EQ, "")
        lexer_test(";", Tokens.SEMICOLON, "")
        lexer_test("\\", Tokens.BACKWARD_SLASH, "")
        lexer_test("/", Tokens.FORWARD_SLASH, "")
    end

    @testset "test quotes" begin
        lexer_test("\"\\\\\"", Tokens.STRING_LIT)
        lexer_test("\"\\a\"", Tokens.STRING_LIT)
        lexer_test("\"\\b\"", Tokens.STRING_LIT)
        lexer_test("\"\\f\"", Tokens.STRING_LIT)
        lexer_test("\"\\n\"", Tokens.STRING_LIT)
        lexer_test("\"\\r\"", Tokens.STRING_LIT)
        lexer_test("\"\\t\"", Tokens.STRING_LIT)
        lexer_test("\"\\v\"", Tokens.STRING_LIT)
        lexer_test("\"\\'\"", Tokens.STRING_LIT, "\"'\"")
        lexer_test("\"\\0\"", Tokens.STRING_LIT)
        lexer_test("\"'\"", Tokens.STRING_LIT)

        lexer_test("'\\\\'", Tokens.STRING_LIT)
        lexer_test("'\\a'", Tokens.STRING_LIT)
        lexer_test("'\\b'", Tokens.STRING_LIT)
        lexer_test("'\\f'", Tokens.STRING_LIT)
        lexer_test("'\\n'", Tokens.STRING_LIT)
        lexer_test("'\\r'", Tokens.STRING_LIT)
        lexer_test("'\\t'", Tokens.STRING_LIT)
        lexer_test("'\\v'", Tokens.STRING_LIT)
        lexer_test("'\\''", Tokens.STRING_LIT, "'''")
        lexer_test("'\\0'", Tokens.STRING_LIT)
        lexer_test("'\"'", Tokens.STRING_LIT)

        lexer_test("\"Hello\\\"World\\\"\"", Tokens.STRING_LIT)
        lexer_test("\"\\0\\001\\a\\b\\f\\n\\r\\t\\v\\\\\\'\\\"\\xfe\"", Tokens.STRING_LIT, "\"\\0\\001\\a\\b\\f\\n\\r\\t\\v\\\\'\\\"\\xfe\"")
        lexer_test("\"\\?\"", Tokens.STRING_LIT, "\"?\"")
        lexer_test("\"\${\"", Tokens.STRING_LIT, "\"\\\${\"")
        lexer_test("'Hello\\\"World\\\"'", Tokens.STRING_LIT)
        lexer_test("'\\0\\001\\a\\b\\f\\n\\r\\t\\v\\\\\\'\\\"\\xfe'", Tokens.STRING_LIT, "'\\0\\001\\a\\b\\f\\n\\r\\t\\v\\\\'\\\"\\xfe'")
        lexer_test("'\\?'", Tokens.STRING_LIT, "'?'")
        lexer_test("'\${'", Tokens.STRING_LIT, "'\\\${'")
    end

    @testset "identifiers" begin
        lexer_test("abc", Tokens.IDENTIFIER)
        lexer_test("a.b.c", Tokens.IDENTIFIER)
        lexer_test(".a.b.c", Tokens.IDENTIFIER)
    end

    @testset "keywords and types" begin
        for w in Lexers._PROTOBUF_TYPES_AND_KEYWORDS
            lexer_test(w, KEYWORDS_AND_TYPES[w])
        end
    end
end