
function _parse_identifier_with_url(ps)
    ident = val(expectnext(ps, Tokens.IDENTIFIER))
    if accept(ps, Tokens.FORWARD_SLASH)
        ident = string(ident, "/", val(expectnext(ps, Tokens.IDENTIFIER)))
    end
    return ident
end


function _parse_option_value(ps) # TODO: proper value parsing with validation
    accept(ps, Tokens.PLUS)
    has_minus = accept(ps, Tokens.MINUS)
    nk, nnk = dpeekkind(ps)
    str_val = val(readtoken(ps))
    # C-style string literals spanning multiple lines
    if nk == Tokens.STRING_LIT && nnk == Tokens.STRING_LIT
        iob = IOBuffer()
        write(iob, str_val)
        while peekkind(ps) == Tokens.STRING_LIT
            seek(iob, position(iob) - 1)
            write(iob, @view(val(readtoken(ps))[begin+1:end]))
        end
        str_val = String(take!(iob))
    end
    return has_minus ? string("-", str_val) : str_val
end

function _parse_julia_package(ps)
    val = _parse_option_value(ps)
    if startswith(val, "\"") && endswith(val, "\"") || startswith(val, "'") && endswith(val, "'")
        val = val[begin+1:end-1]
        if all(Lexers.is_fully_qualified_ident_char, val)
            return val
        end
    end
    error("Invalid value for julia_package option: $(val)")
end

function _parse_option_name(ps)
    buf = IOBuffer()
    option_name = ""
    last_name_part = ""
    prev_had_parens = false
    while true
        if accept(ps, Tokens.LPAREN)
            write(buf, "(", _parse_identifier_with_url(ps), ")")
            expectnext(ps, Tokens.RPAREN)
            prev_had_parens = true
        elseif accept(ps, Tokens.LBRACKET)
            write(buf, "[", _parse_identifier_with_url(ps), "]")
            expectnext(ps, Tokens.RBRACKET)
        elseif accept(ps, Tokens.IDENTIFIER)
            last_name_part = val(token(ps))
            if prev_had_parens
                startswith(last_name_part, '.') || error("Invalid option identifier $(option_name)$(last_name_part)")
            end
            write(buf, last_name_part)
        elseif accept(ps, Tokens.DOT)
            expectnext(ps, Tokens.LPAREN)
            write(buf, ".(", _parse_identifier_with_url(ps), ")")
            expectnext(ps, Tokens.RPAREN)
            prev_had_parens = true
        else
            break
        end
    end
    return String(take!(buf))
end

function _parse_aggregate_option(ps)
    # TODO: properly validate that `option (complex_opt2).waldo = { waldo: 212 }` doesn't happen
    #       `option (complex_opt2) = { waldo: 212 }` ok
    #       `option (complex_opt2).waldo = 212 ` ok
    option_value_dict = Dict{String,Union{Dict,String}}()
    while !accept(ps, Tokens.RBRACE)
        option_name = _parse_option_name(ps)
        accept(ps, Tokens.COLON)
        if accept(ps, Tokens.LBRACE)
            option_value_dict[option_name] = _parse_aggregate_option(ps)
        else
            option_value_dict[option_name] = _parse_option_value(ps)
        end
        accept(ps, Tokens.COMMA)
    end
    return option_value_dict
end

# We consumed a LBRACKET ([)
function parse_field_options!(ps::ParserState, options::Dict{String,Union{String,Dict{String}}})
    while true
        _parse_option!(ps, options)
        accept(ps, Tokens.COMMA) && continue
        accept(ps, Tokens.RBRACKET) && break
        error("Missing comma in option lists at $(ps.l.current_row):$(ps.l.current_col)")
    end
end

# We consumed OPTION
# NOTE: does not eat SEMICOLON
function _parse_option!(ps::ParserState, options::Dict{String,Union{String,Dict{String}}})
    option_name = _parse_option_name(ps)
    accept(ps, Tokens.COLON)
    expectnext(ps, Tokens.EQ)  # =
    if option_name == "julia_package"
        options[option_name] = _parse_julia_package(ps)
    else
        if accept(ps, Tokens.LBRACE) # {key: val, ...}
            options[option_name] = _parse_aggregate_option(ps)
            # accept(ps, Tokens.SEMICOLON)
        else
            options[option_name] = _parse_option_value(ps)
        end
    end
    return nothing
end
