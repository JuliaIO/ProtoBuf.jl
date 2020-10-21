# syntax: proto3
mutable struct Duration <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Duration(; kwargs...)
        obj = new(meta(Duration), Dict{Symbol,Any}())
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
end # mutable struct Duration
const __meta_Duration = Ref{ProtoMeta}()
function meta(::Type{Duration})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Duration)
            __meta_Duration[] = target = ProtoMeta(Duration)
            allflds = Pair{Symbol,Union{Type,String}}[:seconds => Int64, :nanos => Int32]
            meta(target, Duration, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Duration[]
    end
end
function Base.getproperty(obj::Duration, name::Symbol)
    if name === :seconds
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :nanos
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

export Duration
