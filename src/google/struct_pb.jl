# syntax: proto3
const NullValue = (;[
    Symbol("NULL_VALUE") => Int32(0),
]...)

mutable struct Struct_FieldsEntry <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Struct_FieldsEntry(; kwargs...)
        obj = new(meta(Struct_FieldsEntry), Dict{Symbol,Any}())
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
end # mutable struct Struct_FieldsEntry (mapentry) (has cyclic type dependency)
const __meta_Struct_FieldsEntry = Ref{ProtoMeta}()
function meta(::Type{Struct_FieldsEntry})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Struct_FieldsEntry)
            __meta_Struct_FieldsEntry[] = target = ProtoMeta(Struct_FieldsEntry)
            allflds = Pair{Symbol,Union{Type,String}}[:key => AbstractString, :value => "Value"]
            meta(target, Struct_FieldsEntry, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Struct_FieldsEntry[]
    end
end
function Base.getproperty(obj::Struct_FieldsEntry, name::Symbol)
    if name === :key
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :value
        return (obj.__protobuf_jl_internal_values[name])::Any
    else
        getfield(obj, name)
    end
end

mutable struct Struct <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Struct(; kwargs...)
        obj = new(meta(Struct), Dict{Symbol,Any}())
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
end # mutable struct Struct (has cyclic type dependency)
const __meta_Struct = Ref{ProtoMeta}()
function meta(::Type{Struct})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Struct)
            __meta_Struct[] = target = ProtoMeta(Struct)
            allflds = Pair{Symbol,Union{Type,String}}[:fields => "Base.Dict{AbstractString,Value}"]
            meta(target, Struct, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Struct[]
    end
end
function Base.getproperty(obj::Struct, name::Symbol)
    if name === :fields
        return (obj.__protobuf_jl_internal_values[name])::Any
    else
        getfield(obj, name)
    end
end

mutable struct Value <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Value(; kwargs...)
        obj = new(meta(Value), Dict{Symbol,Any}())
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
end # mutable struct Value (has cyclic type dependency)
const __meta_Value = Ref{ProtoMeta}()
function meta(::Type{Value})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Value)
            __meta_Value[] = target = ProtoMeta(Value)
            allflds = Pair{Symbol,Union{Type,String}}[:null_value => Int32, :number_value => Float64, :string_value => AbstractString, :bool_value => Bool, :struct_value => Struct, :list_value => "ListValue"]
            oneofs = Int[1,1,1,1,1,1]
            oneof_names = Symbol[Symbol("kind")]
            meta(target, Value, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, oneofs, oneof_names)
        end
        __meta_Value[]
    end
end
function Base.getproperty(obj::Value, name::Symbol)
    if name === :null_value
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :number_value
        return (obj.__protobuf_jl_internal_values[name])::Float64
    elseif name === :string_value
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :bool_value
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :struct_value
        return (obj.__protobuf_jl_internal_values[name])::Struct
    elseif name === :list_value
        return (obj.__protobuf_jl_internal_values[name])::Any
    else
        getfield(obj, name)
    end
end

mutable struct ListValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function ListValue(; kwargs...)
        obj = new(meta(ListValue), Dict{Symbol,Any}())
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
end # mutable struct ListValue (has cyclic type dependency)
const __meta_ListValue = Ref{ProtoMeta}()
function meta(::Type{ListValue})
    ProtoBuf.metalock() do
        if !isassigned(__meta_ListValue)
            __meta_ListValue[] = target = ProtoMeta(ListValue)
            allflds = Pair{Symbol,Union{Type,String}}[:values => Base.Vector{Value}]
            meta(target, ListValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_ListValue[]
    end
end
function Base.getproperty(obj::ListValue, name::Symbol)
    if name === :values
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Value}
    else
        getfield(obj, name)
    end
end

export NullValue, Struct_FieldsEntry, Struct, Value, ListValue, Struct_FieldsEntry, Struct, Value, ListValue
# mapentries: "Struct_FieldsEntry" => ("AbstractString", "Value")
