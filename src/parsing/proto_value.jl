# abstract type ProtoValue end

# struct StringValue <: ProtoValue;     val::String end
# struct DecIntegerValue <: ProtoValue; val::String end
# struct OctIntegerValue <: ProtoValue; val::String end
# struct HexIntegerValue <: ProtoValue; val::String end
# struct FloatValue <: ProtoValue;      val::String end
# struct BoolValue <: ProtoValue;       val::String end
# struct ReferencedValue <: ProtoValue; val::String end

# # TODO: handle +,-... separate inf?
# function parse_value(ps::ParserState)
#     nk = dpeekkind(ps)
#     if nk == Tokens.ENDMARKER
#         return nothing 
#     elseif nk == Tokens.DEC_INT_LIT DecIntegerValue(val(readtoken(ps)))
#     elseif nk == Tokens.OCT_INT_LIT OctIntegerValue(val(readtoken(ps)))
#     elseif nk == Tokens.HEX_INT_LIT HexIntegerValue(val(readtoken(ps)))
#     elseif nk == Tokens.FLOAT_LIT   FloatValue(val(readtoken(ps)))
#     elseif nk == Tokens.STRING_LIT  StringValue(val(readtoken(ps)))
#     # elseif nk == Tokens.BYTES_LIT   
#     elseif nk == Tokens.TRUE        readtoken(ps); BoolValue("true")
#     elseif nk == Tokens.FALSE       readtoken(ps); BoolValue("false")
#     elseif nk == Tokens.IDENTIFIER  ReferencedValue(val(readtoken(ps)))
#     else
#         ps.errored = true
#         error("Unsupported value token $(peektoken(ps)) ($(nk))")
#     end

# end