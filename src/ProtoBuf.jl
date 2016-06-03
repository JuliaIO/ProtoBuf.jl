VERSION >= v"0.4.0-dev+6521" && __precompile__(true)

module ProtoBuf

import Base.show, Base.copy!

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, filled, isfilled, fillset, fillunset, show, protobuild, enumstr
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
rsplit{T<:AbstractString}(str::T, splitter; limit::Integer=0, keep::Bool=true) = rsplit(str, splitter, limit, keep)
end

if isless(Base.VERSION, v"0.4.0-")
fld_type(o, fld) = fieldtype(o, fld)
else
fld_type{T}(o::T, fld) = fieldtype(T, fld)
end

if isless(Base.VERSION, v"0.5.0-")
byte2str(x) = bytestring(x)
else
byte2str(x) = String(x)
end

# enable logging only during debugging
#using Logging
#const logger = Logging.configure(filename="protobuf.log", level=DEBUG)
#logmsg(s) = debug(s)
logmsg(s) = nothing

include("codec.jl")
include("svc.jl")
include("gen.jl")
include("utils.jl")

end # module
