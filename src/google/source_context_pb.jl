# syntax: proto3
mutable struct SourceContext <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function SourceContext(; kwargs...)
        obj = new(meta(SourceContext), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct SourceContext
const __meta_SourceContext = Ref{ProtoMeta}()
function meta(::Type{SourceContext})
    ProtoBuf.metalock() do
        if !isassigned(__meta_SourceContext)
            __meta_SourceContext[] = target = ProtoMeta(SourceContext)
            allflds = Pair{Symbol,Union{Type,String}}[:file_name => AbstractString]
            meta(target, SourceContext, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_SourceContext[]
    end
end
function Base.getproperty(obj::SourceContext, name::Symbol)
    if name === :file_name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

export SourceContext
