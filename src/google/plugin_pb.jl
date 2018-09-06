# syntax: proto2
using ProtoBuf
import ProtoBuf.meta

mutable struct Version <: ProtoType
    major::Int32
    minor::Int32
    patch::Int32
    suffix::AbstractString
    Version(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct Version

mutable struct CodeGeneratorRequest <: ProtoType
    file_to_generate::Base.Vector{AbstractString}
    parameter::AbstractString
    proto_file::Base.Vector{ProtoBuf.GoogleProtoBuf.FileDescriptorProto}
    compiler_version::Version
    CodeGeneratorRequest(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct CodeGeneratorRequest
const __fnum_CodeGeneratorRequest = Int[1,2,15,3]
meta(t::Type{CodeGeneratorRequest}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorRequest, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, ProtoBuf.DEF_FIELD_TYPES)

mutable struct CodeGeneratorResponse_File <: ProtoType
    name::AbstractString
    insertion_point::AbstractString
    content::AbstractString
    CodeGeneratorResponse_File(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct CodeGeneratorResponse_File
const __fnum_CodeGeneratorResponse_File = Int[1,2,15]
meta(t::Type{CodeGeneratorResponse_File}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse_File, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, ProtoBuf.DEF_FIELD_TYPES)

mutable struct CodeGeneratorResponse <: ProtoType
    error::AbstractString
    file::Base.Vector{CodeGeneratorResponse_File}
    CodeGeneratorResponse(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #mutable struct CodeGeneratorResponse
const __fnum_CodeGeneratorResponse = Int[1,15]
meta(t::Type{CodeGeneratorResponse}) = meta(t, ProtoBuf.DEF_REQ, __fnum_CodeGeneratorResponse, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES, ProtoBuf.DEF_FIELD_TYPES)

export Version, CodeGeneratorRequest, CodeGeneratorResponse_File, CodeGeneratorResponse
