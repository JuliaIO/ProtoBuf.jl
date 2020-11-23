# syntax: proto3
mutable struct Timestamp <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Timestamp(; kwargs...)
        obj = new(meta(Timestamp), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct Timestamp
const __meta_Timestamp = Ref{ProtoMeta}()
function meta(::Type{Timestamp})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Timestamp)
            __meta_Timestamp[] = target = ProtoMeta(Timestamp)
            allflds = Pair{Symbol,Union{Type,String}}[:seconds => Int64, :nanos => Int32]
            meta(target, Timestamp, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Timestamp[]
    end
end
function Base.getproperty(obj::Timestamp, name::Symbol)
    if name === :seconds
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :nanos
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

export Timestamp
