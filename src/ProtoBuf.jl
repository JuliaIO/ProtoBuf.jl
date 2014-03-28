module ProtoBuf

import Base.show, Base.copy!
#, Base.get, Base.has, Base.add

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, filled, isfilled, fillset, fillunset, show
export copy!, set_field, get_field, clear, add_field, has_field, isinitialized
export ProtoEnum, lookup

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
setfield!(a,b,c) = setfield(a,b,c)
read!(a::IO,b::Array) = read(a,b)
end

# enable logging only during debugging
#using Logging
#const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
#logmsg(s) = debug(s)
logmsg(s) = nothing

include("codec.jl")
include("gen.jl")

# utility methods
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

isinitialized(obj::Any) = isfilled(obj)
set_field(obj::Any, fld::Symbol, val) = (setfield!(obj, fld, val); fillset(obj, fld); nothing)
get_field(obj::Any, fld::Symbol) = isfilled(obj, fld) ? getfield(obj, fld) : error("uninitialized field $fld")
clear = fillunset
has_field(obj::Any, fld::Symbol) = isfilled(obj, fld)

function add_field(obj::Any, fld::Symbol, val)
    typ = typeof(obj)
    attrib = meta(typ).symdict[fld]
    (attrib.repeat != 2) && error("$(typ).$(fld) is not a repeating field")

    ptyp = attrib.ptyp
    jtyp = WIRETYPES[ptyp][4]
    (ptyp == :obj) && (jtyp = attrib.meta.jtype)

    !isdefined(obj, fld) && setfield(obj, fld, jtyp[])
    push!(getfield(obj, fld), val)
    nothing
end

end # module

