module ProtoBuf

import Base.show

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, show, filled, fillset, fillunset

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
import Base.Dict
function Dict{K,V}(kv::Associative{K,V})
    h = Dict{K,V}()
        for (k,v) in kv
            h[k] = v
        end
        return h
end
export Dict
end

# enable logging only during debugging
#using Logging
#const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
#logmsg(s) = debug(s)
logmsg(s) = nothing

include("codec.jl")
include("gen.jl")

end # module

