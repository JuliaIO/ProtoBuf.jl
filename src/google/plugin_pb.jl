# syntax: proto2
using Compat
using ProtoBuf
import ProtoBuf.meta
import Base: hash, isequal, ==
using ProtoBuf.GoogleProtoBuf

mutable struct CodeGeneratorRequest
    file_to_generate::Array{AbstractString,1}
    parameter::AbstractString
    proto_file::Array{FileDescriptorProto,1}
    CodeGeneratorRequest(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorRequest
const __fnum_CodeGeneratorRequest = Int[1,2,15]
meta(t::Type{CodeGeneratorRequest}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorRequest, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
hash(v::CodeGeneratorRequest) = ProtoBuf.protohash(v)
isequal(v1::CodeGeneratorRequest, v2::CodeGeneratorRequest) = ProtoBuf.protoisequal(v1, v2)
==(v1::CodeGeneratorRequest, v2::CodeGeneratorRequest) = ProtoBuf.protoeq(v1, v2)

mutable struct CodeGeneratorResponse_File
    name::AbstractString
    insertion_point::AbstractString
    content::AbstractString
    CodeGeneratorResponse_File(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorResponse_File
const __fnum_CodeGeneratorResponse_File = Int[1,2,15]
meta(t::Type{CodeGeneratorResponse_File}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse_File, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
hash(v::CodeGeneratorResponse_File) = ProtoBuf.protohash(v)
isequal(v1::CodeGeneratorResponse_File, v2::CodeGeneratorResponse_File) = ProtoBuf.protoisequal(v1, v2)
==(v1::CodeGeneratorResponse_File, v2::CodeGeneratorResponse_File) = ProtoBuf.protoeq(v1, v2)

mutable struct CodeGeneratorResponse
    error::AbstractString
    file::Array{CodeGeneratorResponse_File,1}
    CodeGeneratorResponse(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type CodeGeneratorResponse
const __fnum_CodeGeneratorResponse = Int[1,15]
meta(t::Type{CodeGeneratorResponse}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
hash(v::CodeGeneratorResponse) = ProtoBuf.protohash(v)
isequal(v1::CodeGeneratorResponse, v2::CodeGeneratorResponse) = ProtoBuf.protoisequal(v1, v2)
==(v1::CodeGeneratorResponse, v2::CodeGeneratorResponse) = ProtoBuf.protoeq(v1, v2)

export CodeGeneratorRequest, CodeGeneratorResponse_File, CodeGeneratorResponse
