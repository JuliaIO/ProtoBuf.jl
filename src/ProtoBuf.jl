__precompile__(true)

module ProtoBuf

if VERSION < v"0.7.0-DEV.4442"
    import Base: finalizer
    finalizer(f::Function, o) = finalizer(o, f)
end

import Base: show, copy!, hash, isequal, ==

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta, protobuild
export filled, isfilled, isfilled_default, which_oneof, fillset, fillset_default, fillunset
export show, copy!, set_field, set_field!, get_field, clear, add_field, add_field!, has_field, isinitialized
export hash, isequal, ==
export ProtoEnum, ProtoType, lookup, enumstr
export ProtoServiceException, ProtoRpcChannel, ProtoRpcController, MethodDescriptor, ServiceDescriptor, ProtoService,
       AbstractProtoServiceStub, GenericProtoServiceStub, ProtoServiceStub, ProtoServiceBlockingStub,
       find_method, get_request_type, get_response_type, get_descriptor_for_type, call_method

using Compat

fld_type(o::T, fld) where {T} = fieldtype(T, fld)
fld_names(x) = (x.name.names...,) # (avoid https://github.com/JuliaLang/julia/issues/27995) x.name.names

# enable logging only during debugging
macro logmsg(s)
end
#macro logmsg(s)
#    quote
#        open("/tmp/protobuf.log", "a") do f
#            println(f, $(esc(s)))
#        end
#    end
#end

include("codec.jl")
include("svc.jl")

include("google/google.jl")

include("gen.jl")
include("utils.jl")

# Include Google ProtoBuf well known types (https://developers.google.com/protocol-buffers/docs/reference/google.protobuf).
# These are part of the `google.protobuf` sub-module and are included automatically by the code generator.
# For hand coded modules, include them with: `using ProtoBuf; using ProtoBuf.google.protobuf`.
include("google/wellknown.jl")

end # module
