# syntax: proto3
mutable struct Empty <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Empty(; kwargs...)
        obj = new(meta(Empty), Dict{Symbol,Any}())
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
end # mutable struct Empty
const __meta_Empty = Ref{ProtoMeta}()
function meta(::Type{Empty})
    if !isassigned(__meta_Empty)
        __meta_Empty[] = target = ProtoMeta(Empty)
        allflds = Pair{Symbol,Union{Type,String}}[]
        meta(target, Empty, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_Empty[]
end

export Empty
