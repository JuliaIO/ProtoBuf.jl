# syntax: proto3
mutable struct FieldMask <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function FieldMask(; kwargs...)
        obj = new(meta(FieldMask), Dict{Symbol,Any}())
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
end # mutable struct FieldMask
const __meta_FieldMask = Ref{ProtoMeta}()
function meta(::Type{FieldMask})
    ProtoBuf.metalock() do
        if !isassigned(__meta_FieldMask)
            __meta_FieldMask[] = target = ProtoMeta(FieldMask)
            allflds = Pair{Symbol,Union{Type,String}}[:paths => Base.Vector{AbstractString}]
            meta(target, FieldMask, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_FieldMask[]
    end
end
function Base.getproperty(obj::FieldMask, name::Symbol)
    if name === :paths
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{AbstractString}
    else
        getfield(obj, name)
    end
end

export FieldMask
