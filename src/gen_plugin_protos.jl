
type CodeGeneratorRequest
    file_to_generate::Array{AbstractString,1}           # repeated string file_to_generate = 1;
    parameter::AbstractString                           # optional string parameter = 2;
    proto_file::Array{FileDescriptorProto,1}            # repeated FileDescriptorProto proto_file = 15;
end
const __fnum_CodeGeneratorRequest = [1,2,15]
meta(t::Type{CodeGeneratorRequest}) = meta(t, DEF_REQ, __fnum_CodeGeneratorRequest, DEF_VAL, true, DEF_PACK)

type CodeGenFile
    name::AbstractString                                # optional string name = 1;
    insertion_point::AbstractString                     # optional string insertion_point = 2;
    content::AbstractString                             # optional string content = 15;
end
const __fnum_CodeGenFile = [1,2,15]
meta(t::Type{CodeGenFile}) = meta(t, DEF_REQ, __fnum_CodeGenFile, DEF_VAL, true, DEF_PACK)

type CodeGeneratorResponse
    error::AbstractString                               # optional string error = 1;
    file::Array{CodeGenFile,1}                          # repeated File file = 15;
end
const __fnum_CodeGeneratorResponse = [1,15]
meta(t::Type{CodeGeneratorResponse}) = meta(t, DEF_REQ, __fnum_CodeGeneratorResponse, DEF_VAL, true, DEF_PACK)

