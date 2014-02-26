
type CodeGeneratorRequest
    file_to_generate::Array{String,1}                   # repeated string file_to_generate = 1;
    parameter::String                                   # optional string parameter = 2;
    proto_file::Array{FileDescriptorProto,1}            # repeated FileDescriptorProto proto_file = 15;
end
meta(t::Type{CodeGeneratorRequest}) = meta(t, true, Symbol[], [1,2,15], Dict{Symbol,Any}())

type CodeGenFile
    name::String                                        # optional string name = 1;
    insertion_point::String                             # optional string insertion_point = 2;
    content::String                                     # optional string content = 15;
end
meta(t::Type{CodeGenFile}) = meta(t, true, Symbol[], [1,2,15], Dict{Symbol,Any}())

type CodeGeneratorResponse
    error::String                                       # optional string error = 1;
    file::Array{CodeGenFile,1}                          # repeated File file = 15;
end
meta(t::Type{CodeGeneratorResponse}) = meta(t, true, Symbol[], [1,15], Dict{Symbol,Any}())

