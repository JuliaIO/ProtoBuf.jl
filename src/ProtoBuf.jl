module ProtoBuf

import Base.show, Base.copy!
#, Base.get, Base.has, Base.add

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, filled, isfilled, fillset, fillunset, show, protobuild
export copy!, set_field, set_field!, get_field, clear, add_field, add_field!, has_field, isinitialized
export ProtoEnum, lookup
export ProtoServiceException, ProtoRpcChannel, ProtoRpcController, MethodDescriptor, ServiceDescriptor, ProtoService,
       AbstractProtoServiceStub, GenericProtoServiceStub, ProtoServiceStub, ProtoServiceBlockingStub,
       find_method, get_request_type, get_response_type, get_descriptor_for_type, call_method

using Compat

# Julia 0.2 compatibility patch
if isless(Base.VERSION, v"0.3.0-")
setfield!(a,b,c) = setfield(a,b,c)
read!(a::IO,b::Array) = read(a,b)
end
if isless(Base.VERSION, v"0.4.0-")
import Base.rsplit
rsplit{T<:String}(str::T, splitter; limit::Integer=0, keep::Bool=true) = rsplit(str, splitter, limit, keep)
end

if isless(Base.VERSION, v"0.4.0-")
fld_type(o, fld) = fieldtype(o, fld)
else
fld_type{T}(o::T, fld) = fieldtype(T, fld)
end

# enable logging only during debugging
#using Logging
#const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
#logmsg(s) = debug(s)
logmsg(s) = nothing

include("codec.jl")
include("svc.jl")
include("gen.jl")

# utility methods
isinitialized(obj::Any) = isfilled(obj)
set_field!(obj::Any, fld::Symbol, val) = (setfield!(obj, fld, val); fillset(obj, fld); nothing)
@deprecate set_field(obj::Any, fld::Symbol, val) set_field!(obj, fld, val)
get_field(obj::Any, fld::Symbol) = isfilled(obj, fld) ? getfield(obj, fld) : error("uninitialized field $fld")
clear = fillunset
has_field(obj::Any, fld::Symbol) = isfilled(obj, fld)

function copy!{T}(to::T, from::T)
    fillunset(to)
    for name in @compat fieldnames(T)
        if isfilled(from, name)
            set_field!(to, name, getfield(from, name))
        end
    end
    nothing
end

function add_field!(obj::Any, fld::Symbol, val)
    typ = typeof(obj)
    attrib = meta(typ).symdict[fld]
    (attrib.occurrence != 2) && error("$(typ).$(fld) is not a repeating field")

    ptyp = attrib.ptyp
    jtyp = WIRETYPES[ptyp][4]
    (ptyp == :obj) && (jtyp = attrib.meta.jtype)

    !isdefined(obj, fld) && setfield!(obj, fld, jtyp[])
    push!(getfield(obj, fld), val)
    nothing
end
@deprecate add_field(obj::Any, fld::Symbol, val) add_field!(obj, fld, val)

function protobuild{T}(::Type{T}, nv::Dict{Symbol}=Dict{Symbol,Any}())
    obj = T()
    for (n,v) in nv
        fldtyp = fld_type(obj, n)
        set_field!(obj, n, isa(v, fldtyp) ? v : convert(fldtyp, v))
    end
    obj
end

end # module
