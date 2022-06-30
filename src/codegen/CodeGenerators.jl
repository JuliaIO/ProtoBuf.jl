module CodeGenerators


import ..Parsers
import ..Parsers: ProtoFile, DoubleType, FloatType, Int32Type
import ..Parsers: Int64Type, UInt32Type, UInt64Type, SInt32Type, SInt64Type
import ..Parsers: Fixed32Type, Fixed64Type, SFixed32Type, SFixed64Type, BoolType
import ..Parsers: StringType, BytesType
import ..Parsers: GroupType, OneOfType, MapType, FieldType
import ..Parsers: MessageType, EnumType, ServiceType, RPCType, ReferencedType
import ..Parsers: AbstractProtoType, AbstractProtoNumericType, AbstractProtoFixedType
import ..Parsers: AbstractProtoFloatType, AbstractProtoFieldType
import Dates
import ..ProtocolBuffers: VENDORED_WELLKNOWN_TYPES_PARENT_PATH, PACKAGE_VERSION
import ..ProtocolBuffers: _topological_sort, get_upstream_dependencies!

_is_repeated_field(f::AbstractProtoFieldType) = f.label == Parsers.REPEATED
_is_repeated_field(::OneOfType) = false

include("modules.jl")
include("names.jl")
include("types.jl")
include("defaults.jl")
include("decode_methods.jl")
include("encode_methods.jl")
include("metadata_methods.jl")
include("toplevel_definitions.jl")

export protojl

end # CodeGenerators