module ProtocolBuffers
import EnumX
import TranscodingStreams

const VENDORED_WELLKNOWN_TYPES_PARENT_PATH = dirname(@__FILE__)
struct OneOf{T}
    name::Symbol
    value::T
end

# Since `oneof` fields contain different names per type in the type union
# we can overload `Base.getproperty` to allow direcly reaching for the
# value we actually got, e.g. for this ProtoBuf message:
#   message MessageType {
#       oneof one_of_field {
#           string inner_field
#           int another_thing
#       }
#   }
# We can use one of the two:
#    MessageType.one_of_field.inner_field
#    MessageType.one_of_field.another_thing
#
# But I guess this will invalidate a lot of julia code?
# function Base.getproperty(t::OneOf, s::Symbol)
#     if s == Base.getfield(t, :name)
#         Base.getfield(t, :value)
#     else
#         error(string(
#             "This `OneOf` has no field `$(s)` (Did you mean `$(Base.getfield(t, :name))`? ",
#             "Alternatvely, you can get the value by invoking getinde `[]`)"
#         ))
#     end
# end
Base.getindex(t::OneOf) = getfield(t, :value)
Base.nameof(t::OneOf) = getfield(t, :name) # is this the right thing to overload?
Base.Pair(t::OneOf) = nameof(t) => t[]

include("lexing/Tokens.jl")
include("lexing/Lexers.jl")

include("parsing/Parsers.jl")
include("codegen/CodeGenerators.jl")
include("codec/Codecs.jl")

import .Parsers
import .CodeGenerators
import .CodeGenerators: protojl
import .Codecs: decode, decode!, encode, ProtoDecoder, BufferedVector, ProtoEncoder, message_done, try_eat_end_group, decode_tag, skip
import .Codecs

end # module
