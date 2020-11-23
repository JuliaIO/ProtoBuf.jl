# syntax: proto2
mutable struct Version <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Version(; kwargs...)
        obj = new(meta(Version), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct Version
const __meta_Version = Ref{ProtoMeta}()
function meta(::Type{Version})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Version)
            __meta_Version[] = target = ProtoMeta(Version)
            allflds = Pair{Symbol,Union{Type,String}}[:major => Int32, :minor => Int32, :patch => Int32, :suffix => AbstractString]
            meta(target, Version, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Version[]
    end
end
function Base.getproperty(obj::Version, name::Symbol)
    if name === :major
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :minor
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :patch
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :suffix
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct CodeGeneratorRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function CodeGeneratorRequest(; kwargs...)
        obj = new(meta(CodeGeneratorRequest), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct CodeGeneratorRequest
const __meta_CodeGeneratorRequest = Ref{ProtoMeta}()
function meta(::Type{CodeGeneratorRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_CodeGeneratorRequest)
            __meta_CodeGeneratorRequest[] = target = ProtoMeta(CodeGeneratorRequest)
            fnum = Int[1,2,15,3]
            allflds = Pair{Symbol,Union{Type,String}}[:file_to_generate => Base.Vector{AbstractString}, :parameter => AbstractString, :proto_file => Base.Vector{ProtoBuf.GoogleProtoBuf.FileDescriptorProto}, :compiler_version => Version]
            meta(target, CodeGeneratorRequest, allflds, ProtoBuf.DEF_REQ, fnum, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CodeGeneratorRequest[]
    end
end
function Base.getproperty(obj::CodeGeneratorRequest, name::Symbol)
    if name === :file_to_generate
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{AbstractString}
    elseif name === :parameter
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :proto_file
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{ProtoBuf.GoogleProtoBuf.FileDescriptorProto}
    elseif name === :compiler_version
        return (obj.__protobuf_jl_internal_values[name])::Version
    else
        getfield(obj, name)
    end
end

mutable struct CodeGeneratorResponse_File <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function CodeGeneratorResponse_File(; kwargs...)
        obj = new(meta(CodeGeneratorResponse_File), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct CodeGeneratorResponse_File
const __meta_CodeGeneratorResponse_File = Ref{ProtoMeta}()
function meta(::Type{CodeGeneratorResponse_File})
    ProtoBuf.metalock() do
        if !isassigned(__meta_CodeGeneratorResponse_File)
            __meta_CodeGeneratorResponse_File[] = target = ProtoMeta(CodeGeneratorResponse_File)
            fnum = Int[1,2,15]
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :insertion_point => AbstractString, :content => AbstractString]
            meta(target, CodeGeneratorResponse_File, allflds, ProtoBuf.DEF_REQ, fnum, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CodeGeneratorResponse_File[]
    end
end
function Base.getproperty(obj::CodeGeneratorResponse_File, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :insertion_point
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :content
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct CodeGeneratorResponse <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function CodeGeneratorResponse(; kwargs...)
        obj = new(meta(CodeGeneratorResponse), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end # mutable struct CodeGeneratorResponse
const __meta_CodeGeneratorResponse = Ref{ProtoMeta}()
function meta(::Type{CodeGeneratorResponse})
    ProtoBuf.metalock() do
        if !isassigned(__meta_CodeGeneratorResponse)
            __meta_CodeGeneratorResponse[] = target = ProtoMeta(CodeGeneratorResponse)
            fnum = Int[1,15]
            allflds = Pair{Symbol,Union{Type,String}}[:error => AbstractString, :file => Base.Vector{CodeGeneratorResponse_File}]
            meta(target, CodeGeneratorResponse, allflds, ProtoBuf.DEF_REQ, fnum, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CodeGeneratorResponse[]
    end
end
function Base.getproperty(obj::CodeGeneratorResponse, name::Symbol)
    if name === :error
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :file
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{CodeGeneratorResponse_File}
    else
        getfield(obj, name)
    end
end

export Version, CodeGeneratorRequest, CodeGeneratorResponse_File, CodeGeneratorResponse
