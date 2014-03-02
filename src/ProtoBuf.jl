module ProtoBuf

import Base.show

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, show, filled, fillset, fillunset

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
setfield!(a,b,c) = setfield(a,b,c)
end

# enable logging only during debugging
#using Logging
#const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
#logmsg(s) = debug(s)
logmsg(s) = nothing

include("codec.jl")
include("gen.jl")

end # module

