# syntax: proto2
using Compat
using ProtoBuf
import ProtoBuf.meta
using ProtoBuf.GoogleProtoBuf

mutable struct CodeGeneratorRequest <: ProtoType
    file_to_generate::Array{AbstractString,1}
    parameter::AbstractString
    proto_file::Array{FileDescriptorProto,1}
    CodeGeneratorRequest(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorRequest
const __fnum_CodeGeneratorRequest = Int[1,2,15]
meta(t::Type{CodeGeneratorRequest}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorRequest, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct CodeGeneratorResponse_File <: ProtoType
    name::AbstractString
    insertion_point::AbstractString
    content::AbstractString
    CodeGeneratorResponse_File(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorResponse_File
const __fnum_CodeGeneratorResponse_File = Int[1,2,15]
meta(t::Type{CodeGeneratorResponse_File}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse_File, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct CodeGeneratorResponse <: ProtoType
    error::AbstractString
    file::Array{CodeGeneratorResponse_File,1}
    CodeGeneratorResponse(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorResponse
const __fnum_CodeGeneratorResponse = Int[1,15]
meta(t::Type{CodeGeneratorResponse}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

export CodeGeneratorRequest, CodeGeneratorResponse_File, CodeGeneratorResponse
