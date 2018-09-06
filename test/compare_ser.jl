# test code to check protobuf performance
# compare protobuf serialization performance with julia serialization (benchmark)
#
# last result:
# nloops: 10000
# julia serialization...
# ser byte sz: 38280000
# elapsed time: 10.340241002 seconds (803842820 bytes allocated)
# protobuf serialization...
# ser byte sz: 21670000
# elapsed time: 4.703561939 seconds (433986864 bytes allocated)

module ProtoBufCompareSer
using ProtoBuf
using JSON
using Random
using Serialization

import ProtoBuf.meta

mutable struct TestType
    b::Bool
    i32::Int32
    iu32::UInt32
    i64::Int64
    ui64::UInt64
    f32::Float32
    f64::Float64
    s::AbstractString
    
    ab::Array{Bool,1}
    ai32::Array{Int32,1}
    ai64::Array{Int64,1}
    af32::Array{Float32,1}
    af64::Array{Float64,1}
    as::Array{AbstractString,1}
    
    function TestType(fill=false)
        !fill && (return new())
        new(rand(Bool), 
            rand(-100:100), rand(1:100),
            rand(-100:100), rand(1:100),
            Float32(rand()*100), Float64(rand()*100),
            randstring(100), 
            convert(Array{Bool,1}, rand(Bool,100)),
            round.(Int32, 127*rand(50)),
            round.(Int64, 127*rand(50)),
            rand(Float32, 50),
            rand(Float64, 50),
            [randstring(10) for i in 1:50]
            )
    end
end # type TestType
const __pack_TestType = Symbol[:ab, :ai32, :ai64, :af32, :af64]
meta(t::Type{TestType}) = meta(t, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, true, __pack_TestType)


function julia_ser(t::TestType, n::Int)
    iob = PipeBuffer()
    sz = 0
    for idx in 1:n
        serialize(iob, t)
        sz += iob.size
        deserialize(iob)
    end
    sz
end

function proto_ser(t::TestType, n::Int)
    iob = PipeBuffer()
    sz = 0
    for idx in 1:n
        writeproto(iob, t)
        sz += iob.size
        readproto(iob, TestType())
    end
    sz
end

function json_ser(t::TestType, n::Int)
    iob = PipeBuffer()
    sz = 0
    for idx in 1:n
        JSON.print(iob, t)
        sz += iob.size
        JSON.parse(iob)
    end
    sz
end


println(meta(TestType))

t = TestType(true)
nloops = 10000

println("nloops: $nloops")
GC.gc()
println("julia serialization...")
@time println("ser byte sz: $(julia_ser(t, nloops))")
GC.gc()
println("protobuf serialization...")
@time println("ser byte sz: $(proto_ser(t, nloops))")
GC.gc()
println("JSON serialization...")
@time println("ser byte sz: $(json_ser(t, nloops))")


end # module
