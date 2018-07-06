struct ProtoServiceException <: Exception
    msg::AbstractString
end

abstract type ProtoRpcChannel end
abstract type ProtoRpcController end
abstract type AbstractProtoServiceStub{B} end

#
# MethodDescriptor begin
# ==============================
struct MethodDescriptor
    name::AbstractString
    index::Int
    input_type::DataType
    output_type::DataType
end
get_request_type(meth::MethodDescriptor) = meth.input_type
get_response_type(meth::MethodDescriptor) = meth.output_type

# ==============================
# MethodDescriptor end
#

#
# ServiceDescriptor begin
# ==============================
struct ServiceDescriptor
    name::AbstractString
    index::Int
    methods::Array{MethodDescriptor}
    _method_name_idx::Dict{AbstractString,MethodDescriptor}
    _method_index_idx::Dict{Int,MethodDescriptor}

    function ServiceDescriptor(name::AbstractString, index::Int, methods::Array{MethodDescriptor})
        name_idx = Dict{AbstractString,MethodDescriptor}()
        index_idx = Dict{Int,MethodDescriptor}()
        for method in methods
            name_idx[method.name] = method
            index_idx[method.index] = method
        end
        new(name, index, methods, name_idx, index_idx)
    end
end

function find_method(svc::ServiceDescriptor, name::AbstractString)
    (name in keys(svc._method_name_idx)) || throw(ProtoServiceException("Service $(svc.name) has no method named $(name)"))
    svc._method_name_idx[name]
end
function find_method(svc::ServiceDescriptor, index::Int)
    (0 < index <= length(svc.methods)) || throw(ProtoServiceException("Service $(svc.name) has no method at index $(index)"))
    svc._method_index_idx[index]
end
find_method(svc::ServiceDescriptor, meth::MethodDescriptor) = isempty(meth.name) ? find_method(svc, meth.index) : find_method(svc, meth.name)
# ==============================
# ServiceDescriptor end
#

#
# Service begin
# ==============================
struct ProtoService
    desc::ServiceDescriptor
    impl_module::Module
end

find_method(svc::ProtoService, name_or_index) = find_method(svc.desc, name_or_index)
get_request_type(svc::ProtoService, meth::MethodDescriptor) = get_request_type(find_method(svc, meth))
get_response_type(svc::ProtoService, meth::MethodDescriptor) = get_response_type(find_method(svc, meth))
get_descriptor_for_type(svc::ProtoService) = svc.desc
call_method(svc::ProtoService, meth::MethodDescriptor, controller::ProtoRpcController, request, done::Function) = @async done(call_method(svc, meth, controller, request))
function call_method(svc::ProtoService, meth::MethodDescriptor, controller::ProtoRpcController, request)
    meth_desc = find_method(svc, meth)
    m = Core.eval(svc.impl_module, Symbol(meth_desc.name))
    isa(request, meth_desc.input_type) || throw(ProtoServiceException("Invalid input type $(typeof(request)) for service $(meth_desc.name). Expected type $(meth_desc.input_type)"))
    m(request)
end
# ==============================
# Service end
#

#
# Service Stubs begin
# ==============================
struct GenericProtoServiceStub{B} <: AbstractProtoServiceStub{B}
    desc::ServiceDescriptor
    channel::ProtoRpcChannel
    blocking::Bool

    # This inner constructor syntax works with both Julia .5 and .6
    function GenericProtoServiceStub{B}(desc::ServiceDescriptor,
                                        channel::ProtoRpcChannel) where B
        new{B}(desc, channel, B)
    end
end

const ProtoServiceStub = GenericProtoServiceStub{false}
const ProtoServiceBlockingStub = GenericProtoServiceStub{true}

find_method(stub::GenericProtoServiceStub, name_or_index) = find_method(stub.desc, name_or_index)
call_method(stub::ProtoServiceBlockingStub, meth::MethodDescriptor, controller::ProtoRpcController, request) = call_method(stub.channel, stub.desc, find_method(stub, meth), controller, request)
call_method(stub::ProtoServiceStub, meth::MethodDescriptor, controller::ProtoRpcController, request, done::Function) = @async done(call_method(stub.channel, stub.desc, find_method(stub, meth), controller, request))
# ==============================
# Service Stubs end
#
