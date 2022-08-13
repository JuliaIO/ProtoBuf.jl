
@enum(Kind,
    ENDMARKER, # EOF
    UNINIT, # used in uninitialized lexer and parser
    ERROR, # If we encounter an error during lexing, paired with TokenErorr
    COMMENT,
    begin_single_character_lexical_items,
        LBRACE, # {
        RBRACE, # }
        LESS,    # <
        GREATER, # >
        COMMA, # ,
        DOT, # .
        LPAREN, # (
        RPAREN, # )
        LBRACKET, # [
        RBRACKET, # ]
        MINUS, # -
        PLUS,  # +
        COLON, # :
        EQ, # =
        DOUBLE_QUOTE, # "
        SINGLE_QUOTE, # '
        WHITESPACE, # '\n \t'
        SEMICOLON, # ;
        UNDERSCORE, # _
        BACKWARD_SLASH, # \
        FORWARD_SLASH, # /
    end_single_character_lexical_items,

    begin_identifiers,
        IDENTIFIER,
    end_identifiers,

    begin_reserved_words,
        RESERVED,
        SYNTAX,
        PACKAGE,
        IMPORT,
        PUBLIC,
        WEAK,

        OPTION,
        EXTENSIONS,
        TO,
        MAX,

        SERVICE,
        STREAM,
        RPC,
        RETURNS,

        EXTEND,
        GROUP,

        REPEATED,
        ONEOF,
        OPTIONAL,
        REQUIRED,

        FLOAT,
        DOUBLE,
        INT32,
        INT64,
        UINT32,
        UINT64,
        SINT32,
        SINT64,
        FIXED32,
        FIXED64,
        SFIXED32,
        SFIXED64,
        BOOL,
        STRING,
        BYTES,

        MAP,
        MESSAGE,
        ENUM,
    end_reserved_words,

    begin_literals,
        DEC_INT_LIT, # 123
        OCT_INT_LIT, # 0173
        HEX_INT_LIT, # 0x7b
        FLOAT_LIT,   # 123.0
        STRING_LIT,  # "a" 'b'
        BYTES_LIT,
        TRUE,
        FALSE,
        INF,
        NAN,
    end_literals,
)

isident(k::Kind) = begin_identifiers < k < end_identifiers
isliteral(k::Kind) = begin_literals < k < end_literals

# TODO: proper handling of valid names, this rule is too loose
maybevalidname(k::Kind) = begin_identifiers < k < end_literals

is_reserved_word(k::Kind) = begin_reserved_words < k < end_reserved_words
is_single_letter_lexical_item(k::Kind) = begin_single_character_lexical_items < k < end_single_character_lexical_items


@enum(TokenError,
    NO_ERROR,
    EOF_STRING,
    EOL_STRING,
    INVALID_STRING_ESCAPE_SEQUENCE,
    INVALID_NUMERIC_CONSTANT,
    INVALID_IDENTIFIER,
    INVALID_NUMERIC_LITERAL_JUXTAPOSITION,
    EOF_MULTICOMMENT,
    UNKNOWN,
)