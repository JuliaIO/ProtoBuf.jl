# syntax: proto3
mutable struct Method <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Method(; kwargs...)
        obj = new(meta(Method), Dict{Symbol,Any}())
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
end # mutable struct Method
const __meta_Method = Ref{ProtoMeta}()
function meta(::Type{Method})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Method)
            __meta_Method[] = target = ProtoMeta(Method)
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :request_type_url => AbstractString, :request_streaming => Bool, :response_type_url => AbstractString, :response_streaming => Bool, :options => Base.Vector{Option}, :syntax => Int32]
            meta(target, Method, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Method[]
    end
end
function Base.getproperty(obj::Method, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :request_type_url
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :request_streaming
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :response_type_url
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :response_streaming
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    elseif name === :syntax
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

mutable struct Mixin <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Mixin(; kwargs...)
        obj = new(meta(Mixin), Dict{Symbol,Any}())
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
end # mutable struct Mixin
const __meta_Mixin = Ref{ProtoMeta}()
function meta(::Type{Mixin})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Mixin)
            __meta_Mixin[] = target = ProtoMeta(Mixin)
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :root => AbstractString]
            meta(target, Mixin, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Mixin[]
    end
end
function Base.getproperty(obj::Mixin, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :root
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct Api <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Api(; kwargs...)
        obj = new(meta(Api), Dict{Symbol,Any}())
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
end # mutable struct Api
const __meta_Api = Ref{ProtoMeta}()
function meta(::Type{Api})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Api)
            __meta_Api[] = target = ProtoMeta(Api)
            allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :methods => Base.Vector{Method}, :options => Base.Vector{Option}, :version => AbstractString, :source_context => SourceContext, :mixins => Base.Vector{Mixin}, :syntax => Int32]
            meta(target, Api, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Api[]
    end
end
function Base.getproperty(obj::Api, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :methods
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Method}
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    elseif name === :version
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :source_context
        return (obj.__protobuf_jl_internal_values[name])::SourceContext
    elseif name === :mixins
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Mixin}
    elseif name === :syntax
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

export Api, Method, Mixin
