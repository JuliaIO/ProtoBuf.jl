module ProtoBuf

import Base: setproperty!, getproperty, propertynames, show, copy!, deepcopy, hash, isequal, ==

if VERSION < v"1.2.0-DEV.272"
    hasproperty(x, s::Symbol) = s in propertynames(x)
else
    import Base: hasproperty
end

export writeproto, readproto, ProtoMeta, ProtoMetaAttribs, meta
export isfilled, which_oneof
export setproperty!, getproperty, hasproperty, show, copy!, deepcopy, clear, isinitialized
export hash, isequal, ==
export ProtoType, lookup, enumstr
export ProtoServiceException, ProtoRpcChannel, ProtoRpcController, MethodDescriptor, ServiceDescriptor, ProtoService,
       AbstractProtoServiceStub, GenericProtoServiceStub, ProtoServiceStub, ProtoServiceBlockingStub,
       find_method, get_request_type, get_response_type, get_descriptor_for_type, call_method

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
