# syntax: proto3
const Syntax = (;[
    Symbol("SYNTAX_PROTO2") => Int32(0),
    Symbol("SYNTAX_PROTO3") => Int32(1),
]...)

mutable struct Option <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Option(; kwargs...)
        obj = new(meta(Option), Dict{Symbol,Any}())
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
end # mutable struct Option
const __meta_Option = Ref{ProtoMeta}()
function meta(::Type{Option})
    if !isassigned(__meta_Option)
        __meta_Option[] = target = ProtoMeta(Option)
        allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :value => _Any]
        meta(target, Option, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_Option[]
end
function Base.getproperty(obj::Option, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :value
        return (obj.__protobuf_jl_internal_values[name])::_Any
    else
        getfield(obj, name)
    end
end

mutable struct EnumValue <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function EnumValue(; kwargs...)
        obj = new(meta(EnumValue), Dict{Symbol,Any}())
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
end # mutable struct EnumValue
const __meta_EnumValue = Ref{ProtoMeta}()
function meta(::Type{EnumValue})
    if !isassigned(__meta_EnumValue)
        __meta_EnumValue[] = target = ProtoMeta(EnumValue)
        allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :number => Int32, :options => Base.Vector{Option}]
        meta(target, EnumValue, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_EnumValue[]
end
function Base.getproperty(obj::EnumValue, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :number
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    else
        getfield(obj, name)
    end
end

const Field_Kind = (;[
    Symbol("TYPE_UNKNOWN") => Int32(0),
    Symbol("TYPE_DOUBLE") => Int32(1),
    Symbol("TYPE_FLOAT") => Int32(2),
    Symbol("TYPE_INT64") => Int32(3),
    Symbol("TYPE_UINT64") => Int32(4),
    Symbol("TYPE_INT32") => Int32(5),
    Symbol("TYPE_FIXED64") => Int32(6),
    Symbol("TYPE_FIXED32") => Int32(7),
    Symbol("TYPE_BOOL") => Int32(8),
    Symbol("TYPE_STRING") => Int32(9),
    Symbol("TYPE_GROUP") => Int32(10),
    Symbol("TYPE_MESSAGE") => Int32(11),
    Symbol("TYPE_BYTES") => Int32(12),
    Symbol("TYPE_UINT32") => Int32(13),
    Symbol("TYPE_ENUM") => Int32(14),
    Symbol("TYPE_SFIXED32") => Int32(15),
    Symbol("TYPE_SFIXED64") => Int32(16),
    Symbol("TYPE_SINT32") => Int32(17),
    Symbol("TYPE_SINT64") => Int32(18),
]...)

const Field_Cardinality = (;[
    Symbol("CARDINALITY_UNKNOWN") => Int32(0),
    Symbol("CARDINALITY_OPTIONAL") => Int32(1),
    Symbol("CARDINALITY_REQUIRED") => Int32(2),
    Symbol("CARDINALITY_REPEATED") => Int32(3),
]...)

mutable struct Field <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function Field(; kwargs...)
        obj = new(meta(Field), Dict{Symbol,Any}())
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
end # mutable struct Field
const __meta_Field = Ref{ProtoMeta}()
function meta(::Type{Field})
    if !isassigned(__meta_Field)
        __meta_Field[] = target = ProtoMeta(Field)
        fnum = Int[1,2,3,4,6,7,8,9,10,11]
        allflds = Pair{Symbol,Union{Type,String}}[:kind => Int32, :cardinality => Int32, :number => Int32, :name => AbstractString, :type_url => AbstractString, :oneof_index => Int32, :packed => Bool, :options => Base.Vector{Option}, :json_name => AbstractString, :default_value => AbstractString]
        meta(target, Field, allflds, ProtoBuf.DEF_REQ, fnum, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_Field[]
end
function Base.getproperty(obj::Field, name::Symbol)
    if name === :kind
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :cardinality
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :number
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :type_url
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :oneof_index
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :packed
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    elseif name === :json_name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :default_value
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct _Enum <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function _Enum(; kwargs...)
        obj = new(meta(_Enum), Dict{Symbol,Any}())
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
end # mutable struct _Enum
const __meta__Enum = Ref{ProtoMeta}()
function meta(::Type{_Enum})
    if !isassigned(__meta__Enum)
        __meta__Enum[] = target = ProtoMeta(_Enum)
        allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :enumvalue => Base.Vector{EnumValue}, :options => Base.Vector{Option}, :source_context => SourceContext, :syntax => Int32]
        meta(target, _Enum, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta__Enum[]
end
function Base.getproperty(obj::_Enum, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :enumvalue
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{EnumValue}
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    elseif name === :source_context
        return (obj.__protobuf_jl_internal_values[name])::SourceContext
    elseif name === :syntax
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

mutable struct _Type <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}

    function _Type(; kwargs...)
        obj = new(meta(_Type), Dict{Symbol,Any}())
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
end # mutable struct _Type
const __meta__Type = Ref{ProtoMeta}()
function meta(::Type{_Type})
    if !isassigned(__meta__Type)
        __meta__Type[] = target = ProtoMeta(_Type)
        allflds = Pair{Symbol,Union{Type,String}}[:name => AbstractString, :fields => Base.Vector{Field}, :oneofs => Base.Vector{AbstractString}, :options => Base.Vector{Option}, :source_context => SourceContext, :syntax => Int32]
        meta(target, _Type, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta__Type[]
end
function Base.getproperty(obj::_Type, name::Symbol)
    if name === :name
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :fields
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Field}
    elseif name === :oneofs
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{AbstractString}
    elseif name === :options
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{Option}
    elseif name === :source_context
        return (obj.__protobuf_jl_internal_values[name])::SourceContext
    elseif name === :syntax
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

export Syntax, _Type, Field_Kind, Field_Cardinality, Field, _Enum, EnumValue, Option
