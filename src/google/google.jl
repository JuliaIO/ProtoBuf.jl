module GoogleProtoBuf
    using ..ProtoBuf
    import ..ProtoBuf: meta
    include("descriptor_pb.jl")
end
module GoogleProtoBufCompiler
    using ..ProtoBuf
    import ..ProtoBuf: meta
    include("plugin_pb.jl")
end
