# syntax: proto2
using Compat
using ProtoBuf
import ProtoBuf.meta

mutable struct UninterpretedOption_NamePart <: ProtoType
    name_part::AbstractString
    is_extension::Bool
    UninterpretedOption_NamePart(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type UninterpretedOption_NamePart
const __req_UninterpretedOption_NamePart = Symbol[:name_part,:is_extension]
meta(t::Type{UninterpretedOption_NamePart}) = meta(t, __req_UninterpretedOption_NamePart, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct UninterpretedOption <: ProtoType
    name::Array{UninterpretedOption_NamePart,1}
    identifier_value::AbstractString
    positive_int_value::UInt64
    negative_int_value::Int64
    double_value::Float64
    string_value::Array{UInt8,1}
    aggregate_value::AbstractString
    UninterpretedOption(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type UninterpretedOption
const __fnum_UninterpretedOption = Int[2,3,4,5,6,7,8]
meta(t::Type{UninterpretedOption}) = meta(t, ProtoBuf.DEF_REQ, __fnum_UninterpretedOption, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

struct __enum_FieldOptions_CType <: ProtoEnum
    STRING::Int32
    CORD::Int32
    STRING_PIECE::Int32
    __enum_FieldOptions_CType() = new(0,1,2)
end #type __enum_FieldOptions_CType
const FieldOptions_CType = __enum_FieldOptions_CType()

struct __enum_FieldOptions_JSType <: ProtoEnum
    JS_NORMAL::Int32
    JS_STRING::Int32
    JS_NUMBER::Int32
    __enum_FieldOptions_JSType() = new(0,1,2)
end #type __enum_FieldOptions_JSType
const FieldOptions_JSType = __enum_FieldOptions_JSType()

mutable struct FieldOptions <: ProtoType
    ctype::Int32
    packed::Bool
    jstype::Int32
    lazy::Bool
    deprecated::Bool
    weak::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    FieldOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FieldOptions
const __val_FieldOptions = Dict(:ctype => FieldOptions_CType.STRING, :jstype => FieldOptions_JSType.JS_NORMAL, :lazy => false, :deprecated => false, :weak => false)
const __fnum_FieldOptions = Int[1,2,6,5,3,10,999]
meta(t::Type{FieldOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_FieldOptions, __val_FieldOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct MessageOptions <: ProtoType
    message_set_wire_format::Bool
    no_standard_descriptor_accessor::Bool
    deprecated::Bool
    map_entry::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    MessageOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type MessageOptions
const __val_MessageOptions = Dict(:message_set_wire_format => false, :no_standard_descriptor_accessor => false, :deprecated => false)
const __fnum_MessageOptions = Int[1,2,3,7,999]
meta(t::Type{MessageOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_MessageOptions, __val_MessageOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct EnumOptions <: ProtoType
    allow_alias::Bool
    deprecated::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    EnumOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type EnumOptions
const __val_EnumOptions = Dict(:deprecated => false)
const __fnum_EnumOptions = Int[2,3,999]
meta(t::Type{EnumOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_EnumOptions, __val_EnumOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct MethodOptions <: ProtoType
    deprecated::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    MethodOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type MethodOptions
const __val_MethodOptions = Dict(:deprecated => false)
const __fnum_MethodOptions = Int[33,999]
meta(t::Type{MethodOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_MethodOptions, __val_MethodOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

struct __enum_FileOptions_OptimizeMode <: ProtoEnum
    SPEED::Int32
    CODE_SIZE::Int32
    LITE_RUNTIME::Int32
    __enum_FileOptions_OptimizeMode() = new(1,2,3)
end #type __enum_FileOptions_OptimizeMode
const FileOptions_OptimizeMode = __enum_FileOptions_OptimizeMode()

mutable struct FileOptions <: ProtoType
    java_package::AbstractString
    java_outer_classname::AbstractString
    java_multiple_files::Bool
    java_generate_equals_and_hash::Bool
    java_string_check_utf8::Bool
    optimize_for::Int32
    go_package::AbstractString
    cc_generic_services::Bool
    java_generic_services::Bool
    py_generic_services::Bool
    deprecated::Bool
    cc_enable_arenas::Bool
    objc_class_prefix::AbstractString
    csharp_namespace::AbstractString
    uninterpreted_option::Array{UninterpretedOption,1}
    FileOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FileOptions
const __val_FileOptions = Dict(:java_multiple_files => false, :java_generate_equals_and_hash => false, :java_string_check_utf8 => false, :optimize_for => FileOptions_OptimizeMode.SPEED, :cc_generic_services => false, :java_generic_services => false, :py_generic_services => false, :deprecated => false, :cc_enable_arenas => false)
const __fnum_FileOptions = Int[1,8,10,20,27,9,11,16,17,18,23,31,36,37,999]
meta(t::Type{FileOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_FileOptions, __val_FileOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct EnumValueOptions <: ProtoType
    deprecated::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    EnumValueOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type EnumValueOptions
const __val_EnumValueOptions = Dict(:deprecated => false)
const __fnum_EnumValueOptions = Int[1,999]
meta(t::Type{EnumValueOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_EnumValueOptions, __val_EnumValueOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct OneofOptions <: ProtoType
    uninterpreted_option::Array{UninterpretedOption,1}
    OneofOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type OneofOptions
const __fnum_OneofOptions = Int[999]
meta(t::Type{OneofOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_OneofOptions, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct ServiceOptions <: ProtoType
    deprecated::Bool
    uninterpreted_option::Array{UninterpretedOption,1}
    ServiceOptions(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type ServiceOptions
const __val_ServiceOptions = Dict(:deprecated => false)
const __fnum_ServiceOptions = Int[33,999]
meta(t::Type{ServiceOptions}) = meta(t, ProtoBuf.DEF_REQ, __fnum_ServiceOptions, __val_ServiceOptions, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

struct __enum_FieldDescriptorProto_Type <: ProtoEnum
    TYPE_DOUBLE::Int32
    TYPE_FLOAT::Int32
    TYPE_INT64::Int32
    TYPE_UINT64::Int32
    TYPE_INT32::Int32
    TYPE_FIXED64::Int32
    TYPE_FIXED32::Int32
    TYPE_BOOL::Int32
    TYPE_STRING::Int32
    TYPE_GROUP::Int32
    TYPE_MESSAGE::Int32
    TYPE_BYTES::Int32
    TYPE_UINT32::Int32
    TYPE_ENUM::Int32
    TYPE_SFIXED32::Int32
    TYPE_SFIXED64::Int32
    TYPE_SINT32::Int32
    TYPE_SINT64::Int32
    __enum_FieldDescriptorProto_Type() = new(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18)
end #type __enum_FieldDescriptorProto_Type
const FieldDescriptorProto_Type = __enum_FieldDescriptorProto_Type()

struct __enum_FieldDescriptorProto_Label <: ProtoEnum
    LABEL_OPTIONAL::Int32
    LABEL_REQUIRED::Int32
    LABEL_REPEATED::Int32
    __enum_FieldDescriptorProto_Label() = new(1,2,3)
end #type __enum_FieldDescriptorProto_Label
const FieldDescriptorProto_Label = __enum_FieldDescriptorProto_Label()

mutable struct FieldDescriptorProto <: ProtoType
    name::AbstractString
    number::Int32
    label::Int32
    _type::Int32
    type_name::AbstractString
    extendee::AbstractString
    default_value::AbstractString
    oneof_index::Int32
    json_name::AbstractString
    options::FieldOptions
    FieldDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FieldDescriptorProto
const __fnum_FieldDescriptorProto = Int[1,3,4,5,6,2,7,9,10,8]
meta(t::Type{FieldDescriptorProto}) = meta(t, ProtoBuf.DEF_REQ, __fnum_FieldDescriptorProto, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct MethodDescriptorProto <: ProtoType
    name::AbstractString
    input_type::AbstractString
    output_type::AbstractString
    options::MethodOptions
    client_streaming::Bool
    server_streaming::Bool
    MethodDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type MethodDescriptorProto
const __val_MethodDescriptorProto = Dict(:client_streaming => false, :server_streaming => false)
meta(t::Type{MethodDescriptorProto}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, __val_MethodDescriptorProto, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct EnumValueDescriptorProto <: ProtoType
    name::AbstractString
    number::Int32
    options::EnumValueOptions
    EnumValueDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type EnumValueDescriptorProto

mutable struct EnumDescriptorProto <: ProtoType
    name::AbstractString
    value::Array{EnumValueDescriptorProto,1}
    options::EnumOptions
    EnumDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type EnumDescriptorProto

mutable struct OneofDescriptorProto <: ProtoType
    name::AbstractString
    options::OneofOptions
    OneofDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type OneofDescriptorProto

mutable struct DescriptorProto_ExtensionRange <: ProtoType
    start::Int32
    _end::Int32
    DescriptorProto_ExtensionRange(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type DescriptorProto_ExtensionRange

mutable struct DescriptorProto_ReservedRange <: ProtoType
    start::Int32
    _end::Int32
    DescriptorProto_ReservedRange(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type DescriptorProto_ReservedRange

mutable struct DescriptorProto <: ProtoType
    name::AbstractString
    field::Array{FieldDescriptorProto,1}
    extension::Array{FieldDescriptorProto,1}
    nested_type::Array{DescriptorProto,1}
    enum_type::Array{EnumDescriptorProto,1}
    extension_range::Array{DescriptorProto_ExtensionRange,1}
    oneof_decl::Array{OneofDescriptorProto,1}
    options::MessageOptions
    reserved_range::Array{DescriptorProto_ReservedRange,1}
    reserved_name::Array{AbstractString,1}
    DescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type DescriptorProto
const __fnum_DescriptorProto = Int[1,2,6,3,4,5,8,7,9,10]
meta(t::Type{DescriptorProto}) = meta(t, ProtoBuf.DEF_REQ, __fnum_DescriptorProto, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct ServiceDescriptorProto <: ProtoType
    name::AbstractString
    method::Array{MethodDescriptorProto,1}
    options::ServiceOptions
    ServiceDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type ServiceDescriptorProto

mutable struct SourceCodeInfo_Location <: ProtoType
    path::Array{Int32,1}
    span::Array{Int32,1}
    leading_comments::AbstractString
    trailing_comments::AbstractString
    leading_detached_comments::Array{AbstractString,1}
    SourceCodeInfo_Location(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type SourceCodeInfo_Location
const __fnum_SourceCodeInfo_Location = Int[1,2,3,4,6]
const __pack_SourceCodeInfo_Location = Symbol[:path,:span]
meta(t::Type{SourceCodeInfo_Location}) = meta(t, ProtoBuf.DEF_REQ, __fnum_SourceCodeInfo_Location, ProtoBuf.DEF_VAL, true, __pack_SourceCodeInfo_Location, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct SourceCodeInfo <: ProtoType
    location::Array{SourceCodeInfo_Location,1}
    SourceCodeInfo(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type SourceCodeInfo

mutable struct FileDescriptorProto <: ProtoType
    name::AbstractString
    package::AbstractString
    dependency::Array{AbstractString,1}
    public_dependency::Array{Int32,1}
    weak_dependency::Array{Int32,1}
    message_type::Array{DescriptorProto,1}
    enum_type::Array{EnumDescriptorProto,1}
    service::Array{ServiceDescriptorProto,1}
    extension::Array{FieldDescriptorProto,1}
    options::FileOptions
    source_code_info::SourceCodeInfo
    syntax::AbstractString
    FileDescriptorProto(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FileDescriptorProto
const __fnum_FileDescriptorProto = Int[1,2,3,10,11,4,5,6,7,8,9,12]
meta(t::Type{FileDescriptorProto}) = meta(t, ProtoBuf.DEF_REQ, __fnum_FileDescriptorProto, ProtoBuf.DEF_VAL, true, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct FileDescriptorSet <: ProtoType
    file::Array{FileDescriptorProto,1}
    FileDescriptorSet(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type FileDescriptorSet

mutable struct GeneratedCodeInfo_Annotation <: ProtoType
    path::Array{Int32,1}
    source_file::AbstractString
    _begin::Int32
    _end::Int32
    GeneratedCodeInfo_Annotation(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type GeneratedCodeInfo_Annotation
const __pack_GeneratedCodeInfo_Annotation = Symbol[:path]
meta(t::Type{GeneratedCodeInfo_Annotation}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, __pack_GeneratedCodeInfo_Annotation, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)

mutable struct GeneratedCodeInfo <: ProtoType
    annotation::Array{GeneratedCodeInfo_Annotation,1}
    GeneratedCodeInfo(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)
end #type GeneratedCodeInfo

export FileDescriptorSet, FileDescriptorProto, DescriptorProto_ExtensionRange, DescriptorProto_ReservedRange, DescriptorProto, FieldDescriptorProto_Type, FieldDescriptorProto_Label, FieldDescriptorProto, OneofDescriptorProto, EnumDescriptorProto, EnumValueDescriptorProto, ServiceDescriptorProto, MethodDescriptorProto, FileOptions_OptimizeMode, FileOptions, MessageOptions, FieldOptions_CType, FieldOptions_JSType, FieldOptions, OneofOptions, EnumOptions, EnumValueOptions, ServiceOptions, MethodOptions, UninterpretedOption_NamePart, UninterpretedOption, SourceCodeInfo_Location, SourceCodeInfo, GeneratedCodeInfo_Annotation, GeneratedCodeInfo
