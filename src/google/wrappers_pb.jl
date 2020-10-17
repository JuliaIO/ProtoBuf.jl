# syntax: proto3
mutable struct DoubleValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function DoubleValue(; kwargs...)
        obj = new(meta(DoubleValue), Dict{Symbol,Any}())
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
end # mutable struct DoubleValue
const __meta_DoubleValue = Ref{ProtoMeta}()
function meta(::Type{DoubleValue})
    if !isassigned(__meta_DoubleValue)
        __meta_DoubleValue[] = target = ProtoMeta(DoubleValue)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Float64]
        meta(target, DoubleValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_DoubleValue[]
end
function Base.getproperty(obj::DoubleValue, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Float64
    else
        getfield(obj, name)
    end
end

mutable struct FloatValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function FloatValue(; kwargs...)
        obj = new(meta(FloatValue), Dict{Symbol,Any}())
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
end # mutable struct FloatValue
const __meta_FloatValue = Ref{ProtoMeta}()
function meta(::Type{FloatValue})
    if !isassigned(__meta_FloatValue)
        __meta_FloatValue[] = target = ProtoMeta(FloatValue)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Float32]
        meta(target, FloatValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_FloatValue[]
end
function Base.getproperty(obj::FloatValue, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

mutable struct Int64Value <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Int64Value(; kwargs...)
        obj = new(meta(Int64Value), Dict{Symbol,Any}())
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
end # mutable struct Int64Value
const __meta_Int64Value = Ref{ProtoMeta}()
function meta(::Type{Int64Value})
    if !isassigned(__meta_Int64Value)
        __meta_Int64Value[] = target = ProtoMeta(Int64Value)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Int64]
        meta(target, Int64Value, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_Int64Value[]
end
function Base.getproperty(obj::Int64Value, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Int64
    else
        getfield(obj, name)
    end
end

mutable struct UInt64Value <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function UInt64Value(; kwargs...)
        obj = new(meta(UInt64Value), Dict{Symbol,Any}())
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
end # mutable struct UInt64Value
const __meta_UInt64Value = Ref{ProtoMeta}()
function meta(::Type{UInt64Value})
    if !isassigned(__meta_UInt64Value)
        __meta_UInt64Value[] = target = ProtoMeta(UInt64Value)
        allflds = Pair{Symbol,Union{Type,String}}[:value => UInt64]
        meta(target, UInt64Value, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_UInt64Value[]
end
function Base.getproperty(obj::UInt64Value, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::UInt64
    else
        getfield(obj, name)
    end
end

mutable struct Int32Value <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Int32Value(; kwargs...)
        obj = new(meta(Int32Value), Dict{Symbol,Any}())
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
end # mutable struct Int32Value
const __meta_Int32Value = Ref{ProtoMeta}()
function meta(::Type{Int32Value})
    if !isassigned(__meta_Int32Value)
        __meta_Int32Value[] = target = ProtoMeta(Int32Value)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Int32]
        meta(target, Int32Value, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_Int32Value[]
end
function Base.getproperty(obj::Int32Value, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

mutable struct UInt32Value <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function UInt32Value(; kwargs...)
        obj = new(meta(UInt32Value), Dict{Symbol,Any}())
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
end # mutable struct UInt32Value
const __meta_UInt32Value = Ref{ProtoMeta}()
function meta(::Type{UInt32Value})
    if !isassigned(__meta_UInt32Value)
        __meta_UInt32Value[] = target = ProtoMeta(UInt32Value)
        allflds = Pair{Symbol,Union{Type,String}}[:value => UInt32]
        meta(target, UInt32Value, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_UInt32Value[]
end
function Base.getproperty(obj::UInt32Value, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    else
        getfield(obj, name)
    end
end

mutable struct BoolValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function BoolValue(; kwargs...)
        obj = new(meta(BoolValue), Dict{Symbol,Any}())
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
end # mutable struct BoolValue
const __meta_BoolValue = Ref{ProtoMeta}()
function meta(::Type{BoolValue})
    if !isassigned(__meta_BoolValue)
        __meta_BoolValue[] = target = ProtoMeta(BoolValue)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Bool]
        meta(target, BoolValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_BoolValue[]
end
function Base.getproperty(obj::BoolValue, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end

mutable struct StringValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function StringValue(; kwargs...)
        obj = new(meta(StringValue), Dict{Symbol,Any}())
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
end # mutable struct StringValue
const __meta_StringValue = Ref{ProtoMeta}()
function meta(::Type{StringValue})
    if !isassigned(__meta_StringValue)
        __meta_StringValue[] = target = ProtoMeta(StringValue)
        allflds = Pair{Symbol,Union{Type,String}}[:value => AbstractString]
        meta(target, StringValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_StringValue[]
end
function Base.getproperty(obj::StringValue, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct BytesValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function BytesValue(; kwargs...)
        obj = new(meta(BytesValue), Dict{Symbol,Any}())
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
end # mutable struct BytesValue
const __meta_BytesValue = Ref{ProtoMeta}()
function meta(::Type{BytesValue})
    if !isassigned(__meta_BytesValue)
        __meta_BytesValue[] = target = ProtoMeta(BytesValue)
        allflds = Pair{Symbol,Union{Type,String}}[:value => Array{UInt8,1}]
        meta(target, BytesValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_BytesValue[]
end
function Base.getproperty(obj::BytesValue, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Array{UInt8,1}
    else
        getfield(obj, name)
    end
end

export DoubleValue, FloatValue, Int64Value, UInt64Value, Int32Value, UInt32Value, BoolValue, StringValue, BytesValue
