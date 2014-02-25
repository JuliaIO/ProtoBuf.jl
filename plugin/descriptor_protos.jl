#========================================
# BEGIN OPTIONS
#========================================
type Location
    path::Array{Int32,1}                    # repeated int32 path = 1 [packed=true];
    span::Array{Int32,1}                    # repeated int32 span = 2 [packed=true];
    leading_comments::String                # optional string leading_comments = 3;
    trailing_comments::String               # optional string trailing_comments = 4;
end

type SourceCodeInfo
    location::Array{Location,1}             # repeated Location location = 1;
end

type NamePart
    name_part::String                       # required string name_part = 1;
    is_extension::Bool                      # required bool is_extension = 2;
end

type UninterpretedOption
    # The name of the uninterpreted option.  Each string represents a segment in
    # a dot-separated name.  is_extension is true iff a segment represents an
    # extension (denoted with parentheses in options specs in .proto files).
    # E.g.,{ ["foo", false], ["bar.baz", true], ["qux", false] } represents
    # "foo.(bar.baz).qux".
    name::Array{NamePart,1}                 # repeated NamePart name = 2;

    # The value of the uninterpreted option, in whatever type the tokenizer
    # identified it as during parsing. Exactly one of these should be set.
    identifier_value::String                # optional string identifier_value = 3;
    positive_int_value::Uint64              # optional uint64 positive_int_value = 4;
    negative_int_value::Int64               # optional int64 negative_int_value = 5;
    double_value::Float64                   # optional double double_value = 6;
    string_value::Array{Uint8,1}            # optional bytes string_value = 7;
    aggregate_value::String                 # optional string aggregate_value = 8;
end

type MethodOptions
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end

type ServiceOptions
    uninterpreted_option::Array{UninterpretedOption,1}      # repeated UninterpretedOption uninterpreted_option = 999;
end

type EnumValueOptions
    uninterpreted_option::Array{UninterpretedOption,1}      #repeated UninterpretedOption uninterpreted_option = 999;
end

type EnumOptions
    # Set this option to false to disallow mapping different tag names to a same value.
    allow_alias::Bool                                       #optional bool allow_alias = 2 [default=true];
    uninterpreted_option::Array{UninterpretedOption,1}      #repeated UninterpretedOption uninterpreted_option = 999;
end

#@enum CType STRING CORD STRING_PIECE
type FieldOptions
    ctype::Int64                                            # optional CType ctype = 1 [default = STRING];
    packed::Bool                                            # optional bool packed = 2;
    lazy::Bool                                              # optional bool lazy = 5 [default=false];
    deprecated::Bool                                        # optional bool deprecated = 3 [default=false];
    experimental_map_key::String                            # optional string experimental_map_key = 9;
    weak::Bool                                              # optional bool weak = 10 [default=false];
    uninterpreted_option::Array{UninterpretedOption,1}      #repeated UninterpretedOption uninterpreted_option = 999;
end

type MessageOptions 
    message_set_wire_format::Bool                           # optional bool message_set_wire_format = 1 [default=false];
    no_standard_descriptor_accessor::Bool                   # optional bool no_standard_descriptor_accessor = 2 [default=false];
    uninterpreted_option::Array{UninterpretedOption,1}      #repeated UninterpretedOption uninterpreted_option = 999;
end

#@enum OptimizeMode unused SPEED CODE_SIZE LITE_RUNTIME
type FileOptions
    java_package::String                                    # optional string java_package = 1;
    java_outer_classname::String                            # optional string java_outer_classname = 8;
    java_multiple_files::Bool                               # optional bool java_multiple_files = 10 [default=false];
    java_generate_equals_and_hash::Bool                     # optional bool java_generate_equals_and_hash = 20 [default=false];
    optimize_for::Int64                                     # optional OptimizeMode optimize_for = 9 [default=SPEED];

    go_package::String                                      # optional string go_package = 11;

    cc_generic_services::Bool                               # optional bool cc_generic_services = 16 [default=false];
    java_generic_services::Bool                             # optional bool java_generic_services = 17 [default=false];
    py_generic_services::Bool                               # optional bool py_generic_services = 18 [default=false];

    uninterpreted_option::Array{UninterpretedOption,1}      #repeated UninterpretedOption uninterpreted_option = 999;
end

#========================================
# END OPTIONS
#========================================


#========================================
# BEGIN DEFINITIONS
#========================================

type MethodDescriptorProto
    name::String                            # optional string name = 1;
    input_type::String                      # optional string input_type = 2;
    output_type::String                     # optional string output_type = 3;
    options::MethodOptions                  # optional MethodOptions options = 4;
end

type ServiceDescriptorProto 
    name::String                              # optional string name = 1;
    method::Array{MethodDescriptorProto,1}    # repeated MethodDescriptorProto method = 2;
    options::ServiceOptions                   # optional ServiceOptions options = 3;
end

type EnumValueDescriptorProto
    name::String                                # optional string name = 1;
    number::Int32                               # optional int32 number = 2;
    options::EnumValueOptions                   # optional EnumValueOptions options = 3;
end

type EnumDescriptorProto
    name::String                                # optional string name = 1;
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

const LABEL_OPTIONAL      = 1
const LABEL_REQUIRED      = 2
const LABEL_REPEATED      = 3

type FieldDescriptorProto
    name::String                                # optional string name = 1;
    number::Int32                               # optional int32 number = 3;
    label::Int32                                # optional Label label = 4;
    typ::Int32                                  # optional Type type = 5;
    typ_name::String                            # optional string type_name = 6;
    extendee::String                            # optional string extendee = 2;
    default_value::String                       # optional string default_value = 7;
    options::FieldOptions                       # optional FieldOptions options = 8;
end


type ExtensionRange
    start::Int32                            # optional int32 start = 1;
    end::Int32                              # optional int32 end = 2;
end


type DescriptorProto 
    name::String                                # optional string name = 1;
    field::Array{FieldDescriptorProto,1}        # repeated FieldDescriptorProto field = 2;
    extension::Array{FieldDescriptorProto,1}    # repeated FieldDescriptorProto extension = 6;
    nested_type::Array{DescriptorProto,1}       # repeated DescriptorProto nested_type = 3;
    enum_type::Array{EnumDescriptorProto,1}     # repeated EnumDescriptorProto enum_type = 4;
    extension_range::Array{ExtensionRange,1}    # repeated ExtensionRange extension_range = 5;
    options::MessageOptions                     # optional MessageOptions options = 7;
end

type FileDescriptorProto
    name::String                                # optional string name = 1;
    package::String                             # optional string package = 2;

    dependency::Array{String,1}                 # repeated string dependency = 3; 
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

type FileDescriptorSet
    file::FileDescriptorProto       # repeated FileDescriptorProto file = 1;
end
#========================================
# END DEFINITIONS
#========================================

