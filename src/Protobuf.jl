module Protobuf

import Base.show

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, wiretype, wiretypes, meta, show, filled, fillset, fillunset

# enable logging only during debugging
using Logging
const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
logmsg(s) = debug(s)
#logmsg(s) = nothing

include("codec.jl")

end # module

