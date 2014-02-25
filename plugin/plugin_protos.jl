
type CodeGeneratorRequest
    file_to_generate::Array{String,1}                   # repeated string file_to_generate = 1;
    parameter::String                                   # optional string parameter = 2;
    proto_file::Array{FileDescriptorProto,1}            # repeated FileDescriptorProto proto_file = 15;
end

type CodeGenFile
    name::String                                        # optional string name = 1;
    insertion_point::String                             # optional string insertion_point = 2;
    content::String                                     # optional string content = 15;
end

type CodeGeneratorResponse
    error::String                                       # optional string error = 1;
    file::Array{CodeGenFile,1}                          # repeated File file = 15;
end

meta(::Type{CodeGeneratorResponse}) = ProtoMeta(CodeGeneratorRequest,
    ProtoMetaAttribs[
        ProtoMetaAttribs(1,     :file_to_generate,  :string,        2,  false, [], nothing),
        ProtoMetaAttribs(2,     :parameter,         :string,        0,  false, [], nothing),
        ProtoMetaAttribs(15,    :proto_file,        :obj,           2,  false, [], meta(FileDescriptorProto))
    ])

meta(::Type{CodeGenFile}) = ProtoMeta(CodeGenFile,
    ProtoMetaAttribs[
        ProtoMetaAttribs(1,     :name,              :string,        0,  false, [], nothing),
        ProtoMetaAttribs(2,     :insertion_point,   :string,        0,  false, [], nothing),
        ProtoMetaAttribs(15,    :content,           :string,        0,  false, [], nothing)
    ])

meta(::Type{CodeGeneratorResponse}) = ProtoMeta(CodeGeneratorResponse, 
    ProtoMetaAttribs[
        ProtoMetaAttribs(1,     :error,             :string,        0, false, [], nothing),
        ProtoMetaAttribs(15,    :file,              :obj,           2, false, [], meta(CodeGenFile))
    ])

