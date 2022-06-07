module Tokens

include("enums.jl")

struct Token
    kind::Kind
    error::Tokens.TokenError
    startpos::Tuple{Int,Int}
    endtpos::Tuple{Int,Int}
    startbyte::Int
    endbyte::Int
    val::String
end
function Token(kind::Kind, startposition::Tuple{Int, Int}, endposition::Tuple{Int, Int}, startbyte::Int, endbyte::Int, val::String)
    return Token(kind, NO_ERROR, startposition, endposition, startbyte, endbyte, val)
end
kind(t::Token) = t.kind
val(t::Token) = t.val

end #module