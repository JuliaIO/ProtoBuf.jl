module Tokens

include("enums.jl")

struct Token
    kind::Kind
    error::Tokens.TokenError
    startpos::Tuple{Int,Int}  # row, col
    endtpos::Tuple{Int,Int}   # row, col
    val::String
end
function Token(kind::Kind, startposition::Tuple{Int, Int}, endposition::Tuple{Int, Int}, val::String)
    return Token(kind, NO_ERROR, startposition, endposition, val)
end
kind(t::Token) = t.kind
val(t::Token) = t.val

end #module