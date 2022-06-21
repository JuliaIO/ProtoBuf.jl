module Lexers

import ..Tokens
import ..TranscodingStreams

const EOF_CHAR = typemax(Char)

# Alias to avoid type piracy
@inline iseof(io::IO) = Base.eof(io)
@inline iseof(c::Char) = c == EOF_CHAR

@inline isoctal(c::Char) = c in '0':'7'
@inline isnewline(c::Char) = c in '\n':'\r'
@inline iswhitespace(c::Char) = c == ' ' || c in '\t':'\r'
@inline is_ident_first_char(c::Char) = isletter(c) || c == '_'
@inline is_ident_char(c::Char) = is_ident_first_char(c) || isdigit(c)
@inline is_fully_qualified_ident_char(c::Char) = is_ident_char(c) || c == '.'

mutable struct Lexer{IO_t <: IO}
    io::IO_t
    filepath::String
    # To know where to start from while iterating
    # tokens multiple times
    io_start_pos::Int

    # Start of the Token we're currently constructing
    token_start_row::Int
    token_start_col::Int
    token_start_pos::Int

    # Our current position in the buffer
    current_row::Int
    current_col::Int
    current_pos::Int

    # (current char, next char, the char after next)
    chars::Tuple{Char,Char,Char}
    charspos::Tuple{Int,Int,Int}

    # Should we start reading the contents of io into
    # charstore so that we can then dump it into the Token
    doread::Bool
    charstore::IOBuffer
end

filepath(l::Lexer) = l.filepath
filepath(io::IOStream) = abspath(io.name[7:end-1])
filepath(io::TranscodingStreams.TranscodingStream) = filepath(io.stream)
filepath(io::IO) = ""
# TODO: print nicer, clickable token locations with this function, esp for errors.
# How to get the Lexers' IO to the tokens' show method?
function file_location(l::Lexer)
    f = filepath(l)
    f = isempty(f) ? string(typeof(l.io), "(...)") : f
    return join((f, l.token_start_row, l.token_start_col), ':')
end

function Lexer(io::IO_t, path=nothing) where {IO_t}
    c1 = ' '
    p1 = position(io)
    if eof(io)
        c2, p2 = EOF_CHAR, p1
        c3, p3 = EOF_CHAR, p1
    else
        c2 = read(io, Char)
        p2 = position(io)
        if eof(io)
            c3, p3 = EOF_CHAR, p2
        else
            c3 = read(io, Char)
            p3 = position(io)
        end
    end
    path = isnothing(path) ? filepath(io) : abspath(path)
    return Lexer{IO_t}(io, path, p3, 1, 1, p3, 1, 1, p3, (c1,c2,c3), (p1,p2,p3), false, IOBuffer())
end
# Read the whole path at once, should cause no problems size-wise
Lexer(path::AbstractString) = Lexer(IOBuffer(read(path)), path)

Base.seekstart(l::Lexer) = seek(l.io, l.io_start_pos)
Base.position(l::Lexer) = l.charspos[1]
iseof(l::Lexer) = iseof(l.io)
Base.seek(l::Lexer, pos) = seek(l.io, pos)

peekchar(l::Lexer) = l.chars[2]
dpeekchar(l::Lexer) = (l.chars[2], l.chars[3])

readchar(io::IO) = iseof(io) ? EOF_CHAR : read(io, Char)
function readchar(l::Lexer{IO_t}) where {IO_t}
    c = readchar(l.io)
    l.chars = (l.chars[2], l.chars[3], c)
    l.charspos = (l.charspos[2], l.charspos[3], position(l.io))
    if l.doread
        write(l.charstore, l.chars[1])
    end
    if l.chars[1] == '\n'
        l.current_row += 1
        l.current_col = 1
    elseif !iseof(l.chars[1])
        l.current_col += 1
    end
    return l.chars[1]
end

# Start storing processed Chars into l.charstore
function readon(l::Lexer{IO_t})  where {IO_t <: IO}
    l.doread = true
    if l.charstore.size != 0
        take!(l.charstore)
    end
    write(l.charstore, l.chars[1])
    return l.chars[1]
end

# Stop with storing processed Chars into l.charstore
function readoff(l::Lexer{IO_t})  where {IO_t <: IO}
    l.doread = false
    return l.chars[1]
end

function accept(l::Lexer, f::Union{Function, Char, Vector{Char}, String})
    c = peekchar(l)
    if isa(f, Function)
        ok = f(c)::Bool
    elseif isa(f, Char)
        ok = c == f
    else
        ok = c in f
    end
    ok && readchar(l)
    return ok
end

function accept_batch(l::Lexer, f)
    ok = false
    while accept(l, f)::Bool
        ok = true
    end
    return ok
end

function emit(l::Lexer{IO_t}, kind::Tokens.Kind, err::Tokens.TokenError=Tokens.NO_ERROR) where IO_t
    if (kind == Tokens.WHITESPACE ||
        kind == Tokens.COMMENT ||
        Tokens.isident(kind) ||
        Tokens.is_reserved_word(kind) ||
        Tokens.isliteral(kind) ||
        kind == Tokens.FALSE ||
        kind == Tokens.TRUE)

        str = String(take!(l.charstore))
    elseif kind == Tokens.ERROR
        p = position(l)
        seek(l, l.token_start_pos)
        str = String(read(l.io, p-l.token_start_pos))
    else
        str = ""
    end
    tok = Tokens.Token(
        kind,
        err,
        (l.token_start_row, l.token_start_col),
        (l.current_row, l.current_col - 1),
        l.token_start_pos,
        position(l) - 1,
        str,
    )
    readoff(l)
    return tok
end

function emit_error(l::Lexer, err::Tokens.TokenError=Tokens.UNKNOWN)
    return emit(l, Tokens.ERROR, err)
end

# We consumed a whitespace
function lex_whitespace(l::Lexer)
    accept_batch(l, iswhitespace)
    return emit(l, Tokens.WHITESPACE)
end

# We consumed a '#' or //
function lex_single_line_comment(l::Lexer)
    accept_batch(l, !in(('\n', EOF_CHAR)))
    return emit(l, Tokens.COMMENT)
end

# We consumed a '.'
function lex_dot(l::Lexer)
    if is_ident_first_char(peekchar(l))
        readon(l)
        return lex_ident(l)
    elseif isdigit(peekchar(l))
        readon(l)
        return lex_digit(l, l.chars[1])
    end
    return emit(l, Tokens.DOT)
end

function lex_forwardslash(l::Lexer, c)
    pc, ppc = dpeekchar(l)
    if pc == '*'  # /*
        readon(l)
        n_start, n_end = 0, 0
        while true
            if c == '/' && pc == '*'
                n_start += 1
                iseof(ppc) && return emit_error(l, Tokens.EOF_MULTICOMMENT)
                readchar(l) # skip past the '*' to avoid ambiguities like "/*/*" being decomposed to "/*" "*/" "/*"
                c = readchar(l)
                pc, ppc = dpeekchar(l)
            elseif c == '*' && pc == '/'
                n_end += 1
                readchar(l) # skip past the '/' to avoid ambiguities like "/*/*" being decomposed to "/*" "*/" "/*"
                n_start == n_end && return emit(l, Tokens.COMMENT)
                iseof(ppc) && n_start != n_end && return emit_error(l, Tokens.EOF_MULTICOMMENT)
                c = readchar(l)
                pc, ppc = dpeekchar(l)
            else
                iseof(pc) && return emit_error(l, Tokens.EOF_MULTICOMMENT)
                c = readchar(l)
                pc, ppc = dpeekchar(l)
            end
        end
    elseif pc == '/' # //
        readon(l)
        readchar(l)
        return lex_single_line_comment(l)
    else
        return emit(l, Tokens.FORWARD_SLASH)
    end
end

# We consumed a a letter or a '_'
function lex_ident(l::Lexer)
    accept_batch(l, is_fully_qualified_ident_char)
    return emit(l, Tokens.IDENTIFIER)
end

function _tryparse_exponent(l)
    if accept(l, "eE")
        accept(l, "+-")
        pc, ppc = dpeekchar(l)
        if pc == '0' && isdigit(ppc)
            accept_batch(l, isdigit)
            return false
        end
        accept_batch(l, isdigit) || return false
    end
    return true
end

# floatLit = (
#     decimals "." [ decimals ] [ exponent ] |
#     decimals exponent |
#     "."decimals [ exponent ] ) |
# )
# decimals  = decimalDigit { decimalDigit }
# exponent  = ( "e" | "E" ) [ "+" | "-" ] decimals
# We consumed a DIGIT or '.'
function lex_digit(l::Lexer, c)
    pc, ppc = dpeekchar(l)
    if c == '0' && isoctal(pc) # lex OCTAL int
        accept_batch(l, isoctal)
        is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION) # number must not be immediately followed by an identifier
        return emit(l, Tokens.OCT_INT_LIT)
    elseif c == '0' && (pc == 'x' || pc == 'X') # lex HEX int
        readchar(l)
        pc, ppc = dpeekchar(l)
        !isxdigit(pc) && return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
        accept_batch(l, isxdigit)
        is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION)
        return emit(l, Tokens.HEX_INT_LIT)
    elseif c == '0' && isdigit(pc) # 09 (leading zero and non-oct digit after -> error)
        return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
    elseif c == '.' # starts with a digit [.]123
        accept_batch(l, isdigit) || return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
        _tryparse_exponent(l) || return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
        is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION)
        return emit(l, Tokens.FLOAT_LIT) # .123E-123
    elseif isdigit(c)
        accept_batch(l, isdigit) # 123
        if peekchar(l) == 'e' || peekchar(l) == 'E' # 123E-123
            _tryparse_exponent(l) || return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
            is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION)
            return emit(l, Tokens.FLOAT_LIT)
        elseif accept(l, '.') # 123.
            accept_batch(l, isdigit) # 123.[456]
            _tryparse_exponent(l) || return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
            is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION)
            return emit(l, Tokens.FLOAT_LIT)
        else
            is_ident_first_char(peekchar(l)) && return emit_error(l, Tokens.INVALID_NUMERIC_LITERAL_JUXTAPOSITION)
            return emit(l, Tokens.DEC_INT_LIT) # 123
        end
    else
        return emit_error(l, Tokens.INVALID_NUMERIC_CONSTANT)
    end
end

# `c` is a consumed '\'' or '"'
function lex_quote(l::Lexer, c)
    enclosing_quote = c
    other_quote = ifelse(c=='"', '\'', '"')
    while true
        pc, ppc = dpeekchar(l)
        if iseof(pc)
            return emit_error(l, Tokens.EOF_STRING)
        elseif isnewline(pc)
            readchar(l)
            return emit_error(l, Tokens.EOL_STRING)
        elseif pc == '\\'
            if ppc in "abfnrtv\\\""
                readchar(l)
                readchar(l)
            elseif ppc in "?'"
                # The single quote must not be escaped in the resulting julia string
                # Similarly, from unittest.proto:
                # // Tests for C++ trigraphs.
                # // Trigraphs should be escaped in C++ generated files, but they should not be
                # // escaped for other languages.
                # // Note that in .proto file, "\?" is a valid way to escape ? in string
                # // literals.
                l.doread = false
                readchar(l)
                l.doread = true
                readchar(l)
            # TODO: check that these codepoints are not immediately followed by a different string?
            elseif isoctal(ppc) # UTF-8 byte in octal
                readchar(l)
                readchar(l)
                accept(l, isoctal)
                accept(l, isoctal)
            elseif ppc == 'x' # UTF-8 byte in hexadecimal
                readchar(l)
                readchar(l)
                !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                accept(l, isxdigit)
            elseif ppc == 'u' # Unicode code point up to 0xffff
                readchar(l)
                readchar(l)
                !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
            elseif ppc == 'U'
                readchar(l)
                readchar(l)
                (readchar(l) != '0') && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                (readchar(l) != '0') && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                if accept(l, '0') # Unicode code point up to 0xfffff
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                elseif accept(l, '1') # Unicode code point between 0x100000 and 0x10ffff
                    (readchar(l) != '0') && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                    !isxdigit(readchar(l)) && return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                else
                    return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
                end
            else
                return emit_error(l, Tokens.INVALID_STRING_ESCAPE_SEQUENCE)
            end
        elseif pc == enclosing_quote
            readchar(l)
            break
        elseif pc == '$' && ppc == '{'
            write(l.charstore, '\\')
            readchar(l)
            readchar(l)
        else
            readchar(l)
        end
    end
    return emit(l, Tokens.STRING_LIT)
end

function start_token!(l)
    l.token_start_pos = l.charspos[1]
    l.token_start_row = l.current_row
    l.token_start_col = l.current_col
end

function next_token(l::Lexer)
    start_token!(l)
    c = readchar(l)
    if iseof(c)
        return emit(l, Tokens.ENDMARKER)
    elseif iswhitespace(c)
        readon(l)
        return lex_whitespace(l)
    elseif c == '#'
        readon(l)
        return lex_single_line_comment(l)
    elseif c == '{'
        return emit(l, Tokens.LBRACE)
    elseif c == '}'
        return emit(l, Tokens.RBRACE)
    elseif c == '>'
        return emit(l, Tokens.GREATER)
    elseif c == '<'
        return emit(l, Tokens.LESS)
    elseif c == ','
        return emit(l, Tokens.COMMA)
    elseif c == '.'
        return lex_dot(l) # Tokens.DOT or (fully qualified) Tokens.IDENTIFIER
    elseif c == '/'
        return lex_forwardslash(l, c) # Tokens.COMMENT or Tokens.FORWARD_SLASH
    elseif c == '\\'
        return emit(l, Tokens.BACKWARD_SLASH)
    elseif c == '('
        return emit(l, Tokens.LPAREN)
    elseif c == ')'
        return emit(l, Tokens.RPAREN)
    elseif c == '['
        return emit(l, Tokens.LBRACKET)
    elseif c == ']'
        return emit(l, Tokens.RBRACKET)
    elseif c == '-'
        return emit(l, Tokens.MINUS)
    elseif c == '+'
        return emit(l, Tokens.PLUS)
    elseif c == ':'
        return emit(l, Tokens.COLON)
    elseif c == '='
        return emit(l, Tokens.EQ)
    elseif c == '"' || c == '\''
        readon(l)
        return lex_quote(l, c)
    elseif c == ';'
        return emit(l, Tokens.SEMICOLON)
    elseif isdigit(c)
        readon(l)
        return lex_digit(l, c)
    elseif c == '_'
        readon(l)
        return lex_ident(l)
    elseif isletter(c)
        readon(l)
        return lex_type_or_keyword_or_identifier(l, c)
    else
        emit_error(l)
    end
end

Base.IteratorSize(::Type{Lexer{IO_t}}) where {IO_t} = Base.SizeUnknown()
Base.IteratorEltype(::Type{Lexer{IO_t}}) where {IO_t} = Base.HasEltype()
Base.eltype(::Type{Lexer{IO_t}}) where {IO_t} = Tokens.Token

function Base.iterate(l::Lexer)
    seekstart(l)
    l.token_start_row = 1
    l.token_start_col = 1
    l.token_start_pos = l.io_start_pos

    l.current_row = 1
    l.current_col = 1
    l.current_pos = l.io_start_pos
    t = next_token(l)
    return t, t.kind == Tokens.ENDMARKER
end

function Base.iterate(l::Lexer, isdone::Bool)
    isdone && return nothing
    t = next_token(l)
    return t, t.kind == Tokens.ENDMARKER
end

function tryread(l, chars, k)
    for s in chars
        c = peekchar(l)
        c != s && return lex_ident(l)
        readchar(l)
    end
    is_fully_qualified_ident_char(peekchar(l)) && return lex_ident(l)
    return emit(l, k)
end

const _PROTOBUF_TYPES_AND_KEYWORDS = [
    "reserved", "syntax", "package", "import", "public", "weak", "option", "extensions",
    "to", "max", "service", "stream", "rpc", "returns", "repeated", "oneof", "optional",
    "required", "float", "double", "int32", "int64", "uint32", "uint64", "sint32",
    "sint64", "fixed32", "fixed64", "sfixed32", "sfixed64", "bool", "string", "bytes",
    "map", "message", "enum", "extend", "group", "true", "false",
]

# using DataStructures
# function buildtrie(keywords)
#     t = Trie(keywords, [0 for _ in keywords])
#     t.value = 0
#     for w in keywords  # init all values zero
#         k = t.children
#         for c in w
#             k[c].value = 0
#             k = k[c].children
#         end
#     end
#     for w in keywords  # count passes through each node
#         t.value += 1
#         d = t.children
#         for c in w
#             d[c].value += 1
#             d = d[c].children
#         end
#     end
#     return t
# end
# function _build_lexer_str(t, i=1, prefix="", str_rest="")
#     is_shared = t.value > 1
#     is_shared_key = t.is_key && is_shared
#     n = length(keys(t.children))  # number of branches of the current prefix
#     if t.is_key # we are at the end of a keyword (which might be a subset of a longer one)
#         tok = uppercase(string(prefix, str_rest))
#         # if someone else went through here, this is not the longest keyword with this prefix
#         if is_shared_key
#             println("    " ^ (i+1), "return emit(l, Tokens.$(tok))")
#         else
#             println("    " ^ (i), "return tryread(l, ", Tuple(collect(str_rest)), ", Tokens.$(tok))")
#         end
#     end
#     j = 0  # the current branch number
#     for (next_char, child) in t.children
#         j += 1
#         is_shared_next = child.value > 1
#         is_non_terminal_next = child.is_key && is_shared_next
#         if (is_shared_next || is_shared || i == 1)
#             println("    " ^ i, (1 < j <= n) || is_shared_key ? "else" : "", "if c == '$(next_char)'")
#             i > 1 && println("    " ^ (i+1), "readchar(l)")
#             is_shared_next && println("    " ^ (i+1), "c = peekchar(l)")
#             is_non_terminal_next && println("    " ^ (i+1), "if !is_ident_char(c)")
#             _build_lexer_str(child, i+1, string(prefix, next_char), str_rest)
#             j == n && begin
#                 println("    " ^ i, "else")
#                 println("    " ^ (i+1), "return lex_ident(l)")
#                 println("    " ^ i, "end")
#             end
#         else
#             _build_lexer_str(child, i, prefix, string(str_rest, next_char))
#         end
#     end
# end
# function build_lexer_str(keywords)
#     @assert allunique(keywords)
#     println("function lex_type_or_keyword_or_identifier(l::Lexer, c)")
#     t = buildtrie(keywords)
#     _build_lexer_str(t)
#     println("end")
# end
# build_lexer_str(_PROTOBUF_TYPES_AND_KEYWORDS)
function lex_type_or_keyword_or_identifier(l::Lexer, c)
    if c == 'f'
        c = peekchar(l)
        if c == 'a'
            readchar(l)
            return tryread(l, ('l', 's', 'e'), Tokens.FALSE)
        elseif c == 'l'
            readchar(l)
            return tryread(l, ('o', 'a', 't'), Tokens.FLOAT)
        elseif c == 'i'
            readchar(l)
            c = peekchar(l)
            if c == 'x'
                readchar(l)
                c = peekchar(l)
                if c == 'e'
                    readchar(l)
                    c = peekchar(l)
                    if c == 'd'
                        readchar(l)
                        c = peekchar(l)
                        if c == '3'
                            readchar(l)
                            return tryread(l, ('2',), Tokens.FIXED32)
                        elseif c == '6'
                            readchar(l)
                            return tryread(l, ('4',), Tokens.FIXED64)
                        else
                            return lex_ident(l)
                        end
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        else
            return lex_ident(l)
        end
    elseif c == 'w'
        return tryread(l, ('e', 'a', 'k'), Tokens.WEAK)
    elseif c == 'd'
        return tryread(l, ('o', 'u', 'b', 'l', 'e'), Tokens.DOUBLE)
    elseif c == 'e'
        c = peekchar(l)
        if c == 'n'
            readchar(l)
            return tryread(l, ('u', 'm'), Tokens.ENUM)
        elseif c == 'x'
            readchar(l)
            c = peekchar(l)
            if c == 't'
                readchar(l)
                c = peekchar(l)
                if c == 'e'
                    readchar(l)
                    c = peekchar(l)
                    if c == 'n'
                        readchar(l)
                        c = peekchar(l)
                        if c == 's'
                            readchar(l)
                            return tryread(l, ('i', 'o', 'n', 's'), Tokens.EXTENSIONS)
                        elseif c == 'd'
                            readchar(l)
                            return tryread(l, (), Tokens.EXTEND)
                        else
                            return lex_ident(l)
                        end
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        else
            return lex_ident(l)
        end
    elseif c == 'o'
        c = peekchar(l)
        if c == 'n'
            readchar(l)
            return tryread(l, ('e', 'o', 'f'), Tokens.ONEOF)
        elseif c == 'p'
            readchar(l)
            c = peekchar(l)
            if c == 't'
                readchar(l)
                c = peekchar(l)
                if c == 'i'
                    readchar(l)
                    c = peekchar(l)
                    if c == 'o'
                        readchar(l)
                        c = peekchar(l)
                        if c == 'n'
                            readchar(l)
                            c = peekchar(l)
                            if !is_ident_char(c)
                                return emit(l, Tokens.OPTION)
                            elseif c == 'a'
                                readchar(l)
                                return tryread(l, ('l',), Tokens.OPTIONAL)
                            else
                                return lex_ident(l)
                            end
                        else
                            return lex_ident(l)
                        end
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        else
            return lex_ident(l)
        end
    elseif c == 's'
        c = peekchar(l)
        if c == 'f'
            readchar(l)
            c = peekchar(l)
            if c == 'i'
                readchar(l)
                c = peekchar(l)
                if c == 'x'
                    readchar(l)
                    c = peekchar(l)
                    if c == 'e'
                        readchar(l)
                        c = peekchar(l)
                        if c == 'd'
                            readchar(l)
                            c = peekchar(l)
                            if c == '3'
                                readchar(l)
                                return tryread(l, ('2',), Tokens.SFIXED32)
                            elseif c == '6'
                                readchar(l)
                                return tryread(l, ('4',), Tokens.SFIXED64)
                            else
                                return lex_ident(l)
                            end
                        else
                            return lex_ident(l)
                        end
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        elseif c == 'y'
            readchar(l)
            return tryread(l, ('n', 't', 'a', 'x'), Tokens.SYNTAX)
        elseif c == 'i'
            readchar(l)
            c = peekchar(l)
            if c == 'n'
                readchar(l)
                c = peekchar(l)
                if c == 't'
                    readchar(l)
                    c = peekchar(l)
                    if c == '3'
                        readchar(l)
                        return tryread(l, ('2',), Tokens.SINT32)
                    elseif c == '6'
                        readchar(l)
                        return tryread(l, ('4',), Tokens.SINT64)
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        elseif c == 'e'
            readchar(l)
            return tryread(l, ('r', 'v', 'i', 'c', 'e'), Tokens.SERVICE)
        elseif c == 't'
            readchar(l)
            c = peekchar(l)
            if c == 'r'
                readchar(l)
                c = peekchar(l)
                if c == 'i'
                    readchar(l)
                    return tryread(l, ('n', 'g'), Tokens.STRING)
                elseif c == 'e'
                    readchar(l)
                    return tryread(l, ('a', 'm'), Tokens.STREAM)
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        else
            return lex_ident(l)
        end
    elseif c == 'i'
        c = peekchar(l)
        if c == 'n'
            readchar(l)
            c = peekchar(l)
            if c == 't'
                readchar(l)
                c = peekchar(l)
                if c == '3'
                    readchar(l)
                    return tryread(l, ('2',), Tokens.INT32)
                elseif c == '6'
                    readchar(l)
                    return tryread(l, ('4',), Tokens.INT64)
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        elseif c == 'm'
            readchar(l)
            return tryread(l, ('p', 'o', 'r', 't'), Tokens.IMPORT)
        else
            return lex_ident(l)
        end
    elseif c == 'r'
        c = peekchar(l)
        if c == 'e'
            readchar(l)
            c = peekchar(l)
            if c == 's'
                readchar(l)
                return tryread(l, ('e', 'r', 'v', 'e', 'd'), Tokens.RESERVED)
            elseif c == 't'
                readchar(l)
                return tryread(l, ('u', 'r', 'n', 's'), Tokens.RETURNS)
            elseif c == 'p'
                readchar(l)
                return tryread(l, ('e', 'a', 't', 'e', 'd'), Tokens.REPEATED)
            elseif c == 'q'
                readchar(l)
                return tryread(l, ('u', 'i', 'r', 'e', 'd'), Tokens.REQUIRED)
            else
                return lex_ident(l)
            end
        elseif c == 'p'
            readchar(l)
            return tryread(l, ('c',), Tokens.RPC)
        else
            return lex_ident(l)
        end
    elseif c == 't'
        c = peekchar(l)
        if c == 'r'
            readchar(l)
            return tryread(l, ('u', 'e'), Tokens.TRUE)
        elseif c == 'o'
            readchar(l)
            return tryread(l, (), Tokens.TO)
        else
            return lex_ident(l)
        end
    elseif c == 'p'
        c = peekchar(l)
        if c == 'a'
            readchar(l)
            return tryread(l, ('c', 'k', 'a', 'g', 'e'), Tokens.PACKAGE)
        elseif c == 'u'
            readchar(l)
            return tryread(l, ('b', 'l', 'i', 'c'), Tokens.PUBLIC)
        else
            return lex_ident(l)
        end
    elseif c == 'm'
        c = peekchar(l)
        if c == 'a'
            readchar(l)
            c = peekchar(l)
            if c == 'x'
                readchar(l)
                return tryread(l, (), Tokens.MAX)
            elseif c == 'p'
                readchar(l)
                return tryread(l, (), Tokens.MAP)
            else
                return lex_ident(l)
            end
        elseif c == 'e'
            readchar(l)
            return tryread(l, ('s', 's', 'a', 'g', 'e'), Tokens.MESSAGE)
        else
            return lex_ident(l)
        end
    elseif c == 'g'
        return tryread(l, ('r', 'o', 'u', 'p'), Tokens.GROUP)
    elseif c == 'u'
        c = peekchar(l)
        if c == 'i'
            readchar(l)
            c = peekchar(l)
            if c == 'n'
                readchar(l)
                c = peekchar(l)
                if c == 't'
                    readchar(l)
                    c = peekchar(l)
                    if c == '3'
                        readchar(l)
                        return tryread(l, ('2',), Tokens.UINT32)
                    elseif c == '6'
                        readchar(l)
                        return tryread(l, ('4',), Tokens.UINT64)
                    else
                        return lex_ident(l)
                    end
                else
                    return lex_ident(l)
                end
            else
                return lex_ident(l)
            end
        else
            return lex_ident(l)
        end
    elseif c == 'b'
        c = peekchar(l)
        if c == 'y'
            readchar(l)
            return tryread(l, ('t', 'e', 's'), Tokens.BYTES)
        elseif c == 'o'
            readchar(l)
            return tryread(l, ('o', 'l'), Tokens.BOOL)
        else
            return lex_ident(l)
        end
    else
        return lex_ident(l)
    end
end


end # module