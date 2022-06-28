module ProtocolBuffers
import EnumX
import TranscodingStreams
using TOML

# TODO:
# - configs for protojl:
#    * If a proto file is not a package, allow the generated julia code to not be a module
#    * Allow the user to use inline string for specific message string fields
#    * Allow the user to mark dict values and non-optional messages as Union{nothing,T} to
#      be more resilient to cases when the sender sends an incomplete message etc.
# - Always put julia code in modules, regardless of whether package is set (but see above) +
#   make the JULIA_RESERVED_KEYWORDS less strict

const PACKAGE_VERSION = let
    project = TOML.parsefile(joinpath(pkgdir(@__MODULE__), "Project.toml"))
    VersionNumber(project["version"])
end

const VENDORED_WELLKNOWN_TYPES_PARENT_PATH = dirname(@__FILE__)
struct OneOf{T}
    name::Symbol
    value::T
end

Base.getindex(t::OneOf) = t.value
Base.Pair(t::OneOf) = t.name => t.value


include("topological_sort.jl")

include("lexing/Tokens.jl")
include("lexing/Lexers.jl")

include("parsing/Parsers.jl")
include("codegen/CodeGenerators.jl")
include("codec/Codecs.jl")

import .Parsers
import .CodeGenerators
import .CodeGenerators: protojl
import .Codecs
import .Codecs: decode, decode!, encode, AbstractProtoDecoder, AbstractProtoEncoder, ProtoDecoder, BufferedVector, ProtoEncoder, message_done, try_eat_end_group, decode_tag, skip

export protojl, encode, ProtoEncoder, decode, decode!, ProtoDecoder

end # module
