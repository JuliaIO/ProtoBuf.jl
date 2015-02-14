#using Compat
# ========================================
# BEGIN OPTIONS
# ========================================
type Location
    path::Array{Int32,1}                    # repeated int32 path = 1 [packed=true];
    span::Array{Int32,1}                    # repeated int32 span = 2 [packed=true];
    leading_comments::AbstractString        # optional string leading_comments = 3;
    trailing_comments::AbstractString       # optional string trailing_comments = 4;
end
const __pack_Location = [:path,:span]
meta(t::Type{Location}) = meta(t, DEF_REQ, DEF_FNUM, DEF_VAL, true, __pack_Location)


type SourceCodeInfo
    location::Array{Location,1}             # repeated Location location = 1;
end

type NamePart
    name_part::AbstractString               # required string name_part = 1;
    is_extension::Bool                      # required bool is_extension = 2;
end
const __req_NamePart = [:name_part, :is_extension]
meta(t::Type{NamePart}) = meta(t, __req_NamePart, DEF_FNUM, DEF_VAL)

type UninterpretedOption
    # The name of the uninterpreted option.  Each string represents a segment in
    # a dot-separated name.  is_extension is true iff a segment represents an
    # extension (denoted with parentheses in options specs in .proto files).
    # E.g.,{ ["foo", false], ["bar.baz", true], ["qux", false] } represents
    # "foo.(bar.baz).qux".
    name::Array{NamePart,1}                 # repeated NamePart name = 2;

    # The value of the uninterpreted option, in whatever type the tokenizer
    # identified it as during parsing. Exactly one of these should be set.
    identifier_value::AbstractString        # optional string identifier_value = 3;
    positive_int_value::UInt64              # optional uint64 positive_int_value = 4;
    negative_int_value::Int64               # optional int64 negative_int_value = 5;
    double_value::Float64                   # optional double double_value = 6;
    string_value::Array{UInt8,1}            # optional bytes string_value = 7;
    aggregate_value::AbstractString         # optional string aggregate_value = 8;
end
const __fnum_UninterpretedOption = [2:8]
meta(t::Type{UninterpretedOption}) = meta(t, DEF_REQ, __fnum_UninterpretedOption, DEF_VAL)

type MethodOptions
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_MethodOptions = [999]
meta(t::Type{MethodOptions}) = meta(t, DEF_REQ, __fnum_MethodOptions, DEF_VAL)

type ServiceOptions
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_ServiceOptions = [999]
meta(t::Type{ServiceOptions}) = meta(t, DEF_REQ, __fnum_ServiceOptions, DEF_VAL)

type EnumValueOptions
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_EnumValueOptions = [999]
meta(t::Type{EnumValueOptions}) = meta(t, DEF_REQ, __fnum_EnumValueOptions, DEF_VAL)

type EnumOptions
    # Set this option to false to disallow mapping different tag names to a same value.
    allow_alias::Bool                                       # optional bool allow_alias = 2 [default=true];
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_EnumOptions = [2,999]
const __val_EnumOptions = @compat Dict{Symbol,Any}(:allow_alias => true)
meta(t::Type{EnumOptions}) = meta(t, DEF_REQ, __fnum_EnumOptions, __val_EnumOptions)

#@enum CType STRING CORD STRING_PIECE
type FieldOptions
    ctype::Int64                                            # optional CType ctype = 1 [default = STRING];
    packed::Bool                                            # optional bool packed = 2;
    lazy::Bool                                              # optional bool lazy = 5 [default=false];
    deprecated::Bool                                        # optional bool deprecated = 3 [default=false];
    experimental_map_key::AbstractString                    # optional string experimental_map_key = 9;
    weak::Bool                                              # optional bool weak = 10 [default=false];
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_FieldOptions = [1,2,5,3,9,10,999]
const __val_FieldOptions = @compat Dict{Symbol,Any}(:ctype => 1, :lazy => false, :deprecated => false, :weak => false)
meta(t::Type{FieldOptions}) = meta(t, DEF_REQ, __fnum_FieldOptions, __val_FieldOptions)

type MessageOptions 
    message_set_wire_format::Bool                           # optional bool message_set_wire_format = 1 [default=false];
    no_standard_descriptor_accessor::Bool                   # optional bool no_standard_descriptor_accessor = 2 [default=false];
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_MessageOptions = [1,2,999]
const __val_MessageOptions = @compat Dict{Symbol,Any}(:message_set_wire_format => false, :no_standard_descriptor_accessor => false)
meta(t::Type{MessageOptions}) = meta(t, DEF_REQ, __fnum_MessageOptions, __val_MessageOptions)

#@enum OptimizeMode unused SPEED CODE_SIZE LITE_RUNTIME
type FileOptions
    java_package::AbstractString                            # optional string java_package = 1;
    java_outer_classname::AbstractString                    # optional string java_outer_classname = 8;
    java_multiple_files::Bool                               # optional bool java_multiple_files = 10 [default=false];
    java_generate_equals_and_hash::Bool                     # optional bool java_generate_equals_and_hash = 20 [default=false];
    optimize_for::Int64                                     # optional OptimizeMode optimize_for = 9 [default=SPEED];

    go_package::AbstractString                              # optional string go_package = 11;

    cc_generic_services::Bool                               # optional bool cc_generic_services = 16 [default=false];
    java_generic_services::Bool                             # optional bool java_generic_services = 17 [default=false];
    py_generic_services::Bool                               # optional bool py_generic_services = 18 [default=false];

    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end
const __fnum_FileOptions = [1,8,10,20,9,11,16,17,18,999]
const __val_FileOptions = @compat Dict{Symbol,Any}(:java_multiple_files => false,
                                        :java_generate_equals_and_hash => false,
                                        :optimize_for => 2,
                                        :cc_generic_services => false,
                                        :java_generic_services => false,
                                        :py_generic_services => false)
meta(t::Type{FileOptions}) = meta(t, DEF_REQ, __fnum_FileOptions, __val_FileOptions)

# ========================================
# END OPTIONS
# ========================================


# ========================================
# BEGIN DEFINITIONS
# ========================================

type MethodDescriptorProto
    name::AbstractString                    # optional string name = 1;
    input_type::AbstractString              # optional string input_type = 2;
    output_type::AbstractString             # optional string output_type = 3;
    options::MethodOptions                  # optional MethodOptions options = 4;
end

type ServiceDescriptorProto 
    name::AbstractString                      # optional string name = 1;
    method::Array{MethodDescriptorProto,1}    # repeated MethodDescriptorProto method = 2;
    options::ServiceOptions                   # optional ServiceOptions options = 3;
end

type EnumValueDescriptorProto
    name::AbstractString                        # optional string name = 1;
    number::Int32                               # optional int32 number = 2;
    options::EnumValueOptions                   # optional EnumValueOptions options = 3;
end

type EnumDescriptorProto
    name::AbstractString                        # optional string name = 1;
    value::Array{EnumValueDescriptorProto,1}    # repeated EnumValueDescriptorProto value = 2;
    options::EnumOptions                        # optional EnumOptions options = 3;
end

const TYPE_DOUBLE         = 1
const TYPE_FLOAT          = 2
const TYPE_INT64          = 3
const TYPE_UINT64         = 4
const TYPE_INT32          = 5
const TYPE_FIXED64        = 6
const TYPE_FIXED32        = 7
const TYPE_BOOL           = 8
const TYPE_STRING         = 9
const TYPE_GROUP          = 10
const TYPE_MESSAGE        = 11
const TYPE_BYTES          = 12
const TYPE_UINT32         = 13
const TYPE_ENUM           = 14
const TYPE_SFIXED32       = 15
const TYPE_SFIXED64       = 16
const TYPE_SINT32         = 17
const TYPE_SINT64         = 18

const JTYPES              = [Float64, Float32, Int64, UInt64, Int32, UInt64,  UInt32,  Bool, AbstractString, Any, Any, Array{UInt8,1}, UInt32, Int32, Int32, Int64, Int32, Int64]
const JTYPE_DEFAULTS      = [0,       0,       0,     0,      0,     0,       0,       false, "",    nothing, nothing, UInt8[], 0,     0,     0,       0,       0,     0]

const LABEL_OPTIONAL      = 1
const LABEL_REQUIRED      = 2
const LABEL_REPEATED      = 3

type FieldDescriptorProto
    name::AbstractString                        # optional string name = 1;
    number::Int32                               # optional int32 number = 3;
    label::Int32                                # optional Label label = 4;
    typ::Int32                                  # optional Type type = 5;
    typ_name::AbstractString                    # optional string type_name = 6;
    extendee::AbstractString                    # optional string extendee = 2;
    default_value::AbstractString               # optional string default_value = 7;
    options::FieldOptions                       # optional FieldOptions options = 8;
end
const __fnum_FieldDescriptorProto = [1,3,4,5,6,2,7,8]
meta(t::Type{FieldDescriptorProto}) = meta(t, DEF_REQ, __fnum_FieldDescriptorProto, DEF_VAL)


type ExtensionRange
    extn_start::Int32                            # optional int32 start = 1;
    extn_end::Int32                              # optional int32 end = 2;
end


type DescriptorProto 
    name::AbstractString                        # optional string name = 1;
    field::Array{FieldDescriptorProto,1}        # repeated FieldDescriptorProto field = 2;
    extension::Array{FieldDescriptorProto,1}    # repeated FieldDescriptorProto extension = 6;
    nested_type::Array{DescriptorProto,1}       # repeated DescriptorProto nested_type = 3;
    enum_type::Array{EnumDescriptorProto,1}     # repeated EnumDescriptorProto enum_type = 4;
    extension_range::Array{ExtensionRange,1}    # repeated ExtensionRange extension_range = 5;
    options::MessageOptions                     # optional MessageOptions options = 7;
end
const __fnum_DescriptorProto = [1,2,6,3,4,5,7]
meta(t::Type{DescriptorProto}) = meta(t, DEF_REQ, __fnum_DescriptorProto, DEF_VAL)

type FileDescriptorProto
    name::AbstractString                        # optional string name = 1;
    package::AbstractString                     # optional string package = 2;

    dependency::Array{AbstractString,1}         # repeated string dependency = 3; 
    public_dependency::Array{Int32,1}           # repeated int32 public_dependency = 10;
    weak_dependency::Array{Int32,1}             # repeated int32 weak_dependency = 11;

    # All top-level definitions in this file.
    message_type::Array{DescriptorProto,1}      # repeated DescriptorProto message_type = 4;
    enum_type::Array{EnumDescriptorProto,1}     # repeated EnumDescriptorProto enum_type = 5;
    service::Array{ServiceDescriptorProto,1}    # repeated ServiceDescriptorProto service = 6;
    extension::Array{FieldDescriptorProto,1}    # repeated FieldDescriptorProto extension = 7;

    options::FileOptions                        # optional FileOptions options = 8;
    source_code_info::SourceCodeInfo            # optional SourceCodeInfo source_code_info = 9;
end
const __fnum_FileDescriptorProto = [1,2,3,10,11,4,5,6,7,8,9]
meta(t::Type{FileDescriptorProto}) = meta(t, DEF_REQ, __fnum_FileDescriptorProto, DEF_VAL)

type FileDescriptorSet
    file::FileDescriptorProto       # repeated FileDescriptorProto file = 1;
end
# ========================================
# END DEFINITIONS
# ========================================

