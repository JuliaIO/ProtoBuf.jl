using ProtoBuf
import ProtoBuf.meta

mutable struct V1 <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function V1(; kwargs...)
        obj = new(meta(V1), Dict{Symbol,Any}(), Set{Symbol}())
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
end
const __meta_V1 = Ref{ProtoMeta}()
function meta(::Type{V1})
    if !isassigned(__meta_V1)
        __meta_V1[] = target = ProtoMeta(V1)
        allflds = Pair{Symbol,Union{Type,String}}[:f1 => Int32, :f2 => Bool]
        meta(target, V1, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_V1[]
end
function Base.getproperty(obj::V1, name::Symbol)
    if name === :f1
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :f2
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end

mutable struct V2 <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function V2(; kwargs...)
        obj = new(meta(V2), Dict{Symbol,Any}(), Set{Symbol}())
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
end
const __meta_V2 = Ref{ProtoMeta}()
function meta(::Type{V2})
    if !isassigned(__meta_V2)
        __meta_V2[] = target = ProtoMeta(V2)
        allflds = Pair{Symbol,Union{Type,String}}[:f1 => Int64, :f2 => Bool, :f3 => Int64]
        meta(target, V2, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_V2[]
end
function Base.getproperty(obj::V2, name::Symbol)
    if name === :f1
        return (obj.__protobuf_jl_internal_values[name])::Int64
    elseif name === :f2
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :f3
        return (obj.__protobuf_jl_internal_values[name])::Int64
    else
        getfield(obj, name)
    end
end

function check_samestruct()
    iob = PipeBuffer();
    writeval = V1(; f1=1, f2=true);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    @test readval == writeval

    iob = PipeBuffer();
    writeval = V2(; f1=1, f2=true, f3=20);
    writeproto(iob, writeval);
    readval = readproto(iob, V2());
    @test readval == writeval
end

# write V1, read V2
# write V2, read V1
function check_V1_v2()
    iob = PipeBuffer();
    writeval = V1(; f1=1, f2=true);
    writeproto(iob, writeval);
    readval = readproto(iob, V2());
    checkval = V2(; f1=1, f2=true, f3=0)
    @test readval == checkval

    iob = PipeBuffer();
    writeval = V2(; f1=1, f2=true, f3=20);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    checkval = V1(; f1=1, f2=true)
    @test readval == checkval

    iob = PipeBuffer();
    writeval = V2(; f1=typemax(Int64), f2=true, f3=20);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    checkval = V1(; f1=-1, f2=true)  # overflow can't be detected as negative int32 is sign extended for serialization
    @test readval == checkval
end

@testset "Serialization across type versions" begin
    check_samestruct()
    check_V1_v2()
end
