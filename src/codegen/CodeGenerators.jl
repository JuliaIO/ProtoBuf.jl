module CodeGenerators


import ..Parsers
import ..Parsers: ProtoFile, DoubleType, FloatType, Int32Type
import ..Parsers: Int64Type, UInt32Type, UInt64Type, SInt32Type, SInt64Type
import ..Parsers: Fixed32Type, Fixed64Type, SFixed32Type, SFixed64Type, BoolType
import ..Parsers: StringType, BytesType
import ..Parsers: GroupType, OneOfType, MapType, FieldType
import ..Parsers: MessageType, EnumType, ServiceType, ReferencedType
import ..Parsers: AbstractProtoType, AbstractProtoNumericType, AbstractProtoFixedType
import ..Parsers: AbstractProtoFloatType, AbstractProtoFieldType
import Pkg
import Dates
import ..ProtocolBuffers: VENDORED_WELLKNOWN_TYPES_PARENT_PATH

include("modules.jl")
include("translation.jl")

end # CodeGenerators