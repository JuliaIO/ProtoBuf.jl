module Parsers

using ..Lexers: Lexers, Lexer, next_token, filepath
using ..Tokens: Tokens, kind, val
import ..ProtocolBuffers: _topological_sort, get_upstream_dependencies!

const MAX_FIELD_NUMBER = Int(typemax(UInt32) >> 3)

mutable struct ParserState
    l::Lexer
    isdone::Bool
    t::Tokens.Token
    nt::Tokens.Token
    nnt::Tokens.Token
    errored::Bool
end

function readtoken(ps::ParserState)
    ps.isdone && (return ps.t)

    nnt = Lexers.next_token(ps.l)
    # Eat comments and whitespaces
    while (kind(nnt) == Tokens.COMMENT || kind(nnt) == Tokens.WHITESPACE)
        nnt = Lexers.next_token(ps.l)
    end

    ps.t = ps.nt
    ps.nt = ps.nnt
    ps.nnt = nnt
    ps.isdone = kind(ps.t) == Tokens.ENDMARKER
    return ps.t
end

function ParserState(l::Lexer)
    ps = ParserState(
        l,
        false,
        Tokens.Token(Tokens.UNINIT, Tokens.NO_ERROR, (0,0), (0,0), ""),
        Tokens.Token(Tokens.UNINIT, Tokens.NO_ERROR, (0,0), (0,0), ""),
        Tokens.Token(Tokens.UNINIT, Tokens.NO_ERROR, (0,0), (0,0), ""),
        false,
    )
    readtoken(ps)
    readtoken(ps)
    return ps
end
ParserState(input::Union{IO,String}) = ParserState(Lexer(input))

Tokens.kind(ps::ParserState) = kind(ps.t)
token(ps::ParserState) = ps.t
peektoken(ps::ParserState) = ps.nt
dpeektoken(ps::ParserState) = (ps.nt, ps.nnt)
peekkind(ps::ParserState) = kind(ps.nt)
dpeekkind(ps::ParserState) = (kind(ps.nt), kind(ps.nnt))

function expect(ps, k::Tokens.Kind)
    t = token(ps)
    if kind(ps) != k
        ps.errored = true
        throw(error("Found $(t) (value: `$(val(t))`), expected $(k) at $(t.startpos)"))
    end
    return token(ps)
end

function expectnext(ps, k::Tokens.Kind)
    t = peektoken(ps)
    if kind(t) != k
        ps.errored = true
        throw(error("Found $(t) (value: `$(val(t))`), expected $(k) at $(t.startpos)"))
    end
    return readtoken(ps)
end

function expectnext(ps, f::Function)
    t = peektoken(ps)
    if !f(kind(t))
        ps.errored = true
        throw(error("Found $(t) (value: `$(val(t))`), expected one of $(kind(t)) at $(t.startpos)"))
    end
    return readtoken(ps)
end

function accept(ps, f::Union{Function,Tokens.Kind,String})
    t = peektoken(ps)
    if isa(f, Function)
        ok = f(t)::Bool
    elseif isa(f, Tokens.Kind)
        ok = kind(t) == f
    else
        ok = val(t) == f
    end
    ok && readtoken(ps)
    return ok
end

function accept_batch(ps, f)
    ok = false
    while accept(ps, f)
        ok = true
    end
    return ok
end

function _parse_option_value(ps) # TODO: proper value parsing with validation
    accept(ps, Tokens.PLUS)
    has_minus = accept(ps, Tokens.MINUS)
    return has_minus ? string("-", val(readtoken(ps))) : val(readtoken(ps))
end

# We consumed a LBRACKET ([)
function parse_field_options!(ps::ParserState, options::Dict{String,<:Union{String,Dict{String,String}}})
    while true
        _parse_option!(ps, options)
        accept(ps, Tokens.COMMA) && continue
        accept(ps, Tokens.RBRACKET) && break
        error("Missing comma in option lists at $(ps.l.current_row):$(ps.l.current_col)")
    end
end


function parse_integer_value(ps)
    nk, nnk = dpeekkind(ps)
    if nk == Tokens.DEC_INT_LIT
        return parse(Int, val(readtoken(ps)))
    elseif nk == Tokens.HEX_INT_LIT
        return parse(Int, val(readtoken(ps))[3:end]; base=16)
    elseif nk == Tokens.OCT_INT_LIT
        return parse(Int, val(readtoken(ps)); base=8)
    elseif nk == Tokens.PLUS && nnk == Tokens.DEC_INT_LIT
        readtoken(ps)
        parse(Int, val(readtoken(ps)))
    elseif nk == Tokens.MINUS && nnk == Tokens.DEC_INT_LIT
        readtoken(ps)
        parse(Int, string("-", val(readtoken(ps))))
    else
        error("Encountered invalid token sequence while parsing integer value: $(dpeektoken(ps))")
    end
end

# We consumed OPTION
# NOTE: does not eat SEMICOLON
function _parse_option!(ps::ParserState, options::Dict{String,<:Union{String,Dict{String,String}}})
    option_name = ""
    last_name_part = ""
    prev_had_parens = false
    while true
        if accept(ps, Tokens.LPAREN)
            option_name *= string("(", val(expectnext(ps, Tokens.IDENTIFIER)), ")")
            expectnext(ps, Tokens.RPAREN)
            prev_had_parens = true
        elseif accept(ps, Tokens.IDENTIFIER)
            last_name_part = val(token(ps))
            if prev_had_parens
                startswith(last_name_part, '.') || error("Invalid option identifier $(option_name)$(last_name_part)")
            end
            option_name *= last_name_part
        elseif accept(ps, Tokens.DOT)
            expectnext(ps, Tokens.LPAREN)
            option_name *= option_name *= string(".(", val(expectnext(ps, Tokens.IDENTIFIER)), ")")
            expectnext(ps, Tokens.RPAREN)
            prev_had_parens = true
        else
            break
        end
    end

    expectnext(ps, Tokens.EQ)  # =

    is_aggregate = accept(ps, Tokens.LBRACE)
    if is_aggregate # {key: val, ...}
        # TODO: properly validate that `option (complex_opt2).waldo = { waldo: 212 }` doesn't happen
        #       `option (complex_opt2) = { waldo: 212 }` ok
        #       `option (complex_opt2).waldo = 212 ` ok
        option_value = Dict{String,String}()
        while !accept(ps, Tokens.RBRACE)
            if accept(ps, Tokens.IDENTIFIER)
                key = val(token(ps))
                @assert key != last_name_part
            elseif accept(ps, Tokens.RBRACKET)
                key = val(token(ps))
                expectnext(ps, Tokens.LBRACKET)
                key = string("[", key, "]")
            else
                error("Unexpected token name in option mapping $(peektoken(ps))")
            end

            expectnext(ps, Tokens.COLON)
            value = _parse_option_value(ps)
            option_value[key] = value
            accept(ps, Tokens.COMMA)
        end
        # accept(ps, Tokens.SEMICOLON)
    else
        option_value = _parse_option_value(ps)
    end
    options[option_name] = option_value
    return nothing
end

include("proto_types.jl")

@enum(ImportOption, NONE, PUBLIC, WEAK)

struct ProtoImportedPackage
    import_option::ImportOption
    path::String
end

struct ProtoFilePreamble
    isproto3::Bool
    namespace::String
    options::Dict{String,Union{String,Dict{String,String}}}
    imports::Vector{ProtoImportedPackage}
end

struct ProtoFile
    filepath::String
    preamble::ProtoFilePreamble
    definitions::Dict{String,AbstractProtoType}
    sorted_definitions::Vector{String}
    cyclic_definitions::Set{String}
    extends::Vector{ExtendType}
end

include("utils.jl")

parse_proto_file(path::String) = parse_proto_file(ParserState(path))
function parse_proto_file(ps::ParserState)
    if accept(ps, Tokens.SYNTAX)
        expectnext(ps, Tokens.EQ)
        proto_version_string = val(expectnext(ps, Tokens.STRING_LIT))[2:end-1] # drop quotes
        @assert (proto_version_string in ("proto3", "proto2"))
        expectnext(ps, Tokens.SEMICOLON)
    else
        proto_version_string = "proto2"
    end

    definitions = Dict{String,AbstractProtoType}()
    extends = ExtendType[]
    options = Dict{String,Union{String,Dict{String,String}}}()
    imported_packages = ProtoImportedPackage[]
    package_identifier = ""

    while !accept(ps, Tokens.ENDMARKER)
        if peekkind(ps) == Tokens.PACKAGE
            if !isempty(package_identifier)
                ps.errored = true
                error("Only a single package identifier permitted")
            end
            readtoken(ps)
            package_identifier = val(expectnext(ps, Tokens.IDENTIFIER))
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.OPTION)
            _parse_option!(ps, options)
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.IMPORT)
            import_option = accept(ps, Tokens.PUBLIC) ? PUBLIC : accept(ps, Tokens.WEAK) ? WEAK : NONE
            imported_package_name = val(expectnext(ps, Tokens.STRING_LIT))[2:end-1] # drop quotes
            push!(imported_packages, ProtoImportedPackage(import_option, imported_package_name))
            expectnext(ps, Tokens.SEMICOLON)
        elseif accept(ps, Tokens.EXTEND)
            # we collect top-level extends here
            # Scoped extends are extracted in find_external_references
            push!(extends, parse_extend_type(ps, definitions))
        else
            type = parse_type(ps, definitions)
            definitions[type.name] = type
        end
    end
    preamble = ProtoFilePreamble(
        proto_version_string=="proto3",
        package_identifier,
        options,
        imported_packages,
    )
    external_references = find_external_references_and_check_enums(definitions, preamble)
    topologically_sorted, cyclic_definitions = _topological_sort(definitions, external_references)
    return ProtoFile(
        filepath(ps.l),
        preamble,
        definitions,
        topologically_sorted,
        cyclic_definitions,
        extends,
    )
end


end # module