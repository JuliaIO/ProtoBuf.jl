module ProtoBuf

import Base.show, Base.copy!

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, filled, isfilled, fillset, fillunset, show, copy!

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

function copy!(to::Any, from::Any)
    totype = typeof(to)
    fromtype = typeof(from)
    (totype != fromtype) && error("Can't copy a type $fromtype to $totype")
    fillunset(to)
    for name in totype.names
        if isfilled(from, name)
            setfield!(to, name, getfield(from, name))
            fillset(to, name)
        end
    end
    nothing
end

end # module

