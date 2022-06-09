module CodeGenerators

import ..Parsers
import ..Parsers: ProtoFile
import Pkg
import Dates
import ..ProtocolBuffers: VENDORED_WELLKNOWN_TYPES_PARENT_PATH

include("modules.jl")
include("translation.jl")

end # CodeGenerators