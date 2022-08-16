module TestDecode
using ProtoBuf: Codecs
import ProtoBuf as PB
using .Codecs: decode, decode!, ProtoDecoder, BufferedVector
using Test
using EnumX: @enumx

@enumx TestEnum A B C
struct TestInner
    x::Int
    r::Union{Nothing,TestInner}
end
TestInner(x::Int) = TestInner(x, nothing)
struct TestStruct{T1<:Union{Nothing,PB.OneOf{<:Union{Vector{UInt8},TestEnum.T,TestInner}}}}
    oneof::T1
end

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:TestInner})
    x = 0
    r = Ref{Union{Nothing,TestInner}}(nothing)
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            x = PB.decode(d, Int64)
        elseif field_number == 2
            PB.decode!(d, r)
        else
            PB.skip(d, wire_type)
        end
    end
    return TestInner(x, r[])
end

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{<:TestStruct})
    oneof = nothing
    while !PB.message_done(d)
        field_number, wire_type = PB.decode_tag(d)
        if field_number == 1
            oneof = PB.OneOf(:bytes, PB.decode(d, Vector{UInt8}))
        elseif field_number == 2
            oneof = PB.OneOf(:enum, PB.decode(d, TestEnum.T))
        elseif field_number == 3
            oneof = PB.OneOf(:struct, PB.decode(d, Ref{TestInner}))
        else
            PB.skip(d, wire_type)
        end
    end
    return TestStruct(oneof)
end

const _Varint = Union{UInt32,UInt64,Int64,Int32,Bool,Enum}

wire_type(::Type{<:Union{Int32,Int64}},  V::Type{Val{:zigzag}}) = Codecs.VARINT
wire_type(::Type{<:_Varint},             V::Type{Nothing})      = Codecs.VARINT
wire_type(::Type{<:Union{UInt32,Int32}}, V::Type{Val{:fixed}})  = Codecs.FIXED32
wire_type(::Type{Float32},               V::Type{Nothing})      = Codecs.FIXED32
wire_type(::Type{<:Union{UInt64,Int64}}, V::Type{Val{:fixed}})  = Codecs.FIXED64
wire_type(::Type{Float64},               V::Type{Nothing})      = Codecs.FIXED64
wire_type(::Type{<:AbstractVector},      V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractDict},        V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractString},      V::Type)               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:_Varint})                                    = Codecs.VARINT
wire_type(::Type{Float64})                                      = Codecs.FIXED64
wire_type(::Type{Float32})                                      = Codecs.FIXED32
wire_type(::Type{<:AbstractVector})                             = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractDict})                               = Codecs.LENGTH_DELIMITED
wire_type(::Type{<:AbstractString})                             = Codecs.LENGTH_DELIMITED

function test_decode(input_bytes, expected, V::Type=Nothing)
    w = wire_type(typeof(expected), V)
    input_bytes = collect(input_bytes)
    if w == Codecs.LENGTH_DELIMITED
        input_bytes = vcat(UInt8(length(input_bytes)), input_bytes)
    end

    e = ProtoDecoder(IOBuffer(input_bytes))
    if V === Nothing
        if eltype(expected) <: Union{String,Vector{UInt8},TestInner}
            skip(e.io, 1)
            x = BufferedVector{eltype(expected)}()
            while !eof(e.io)
                num, tag = PB.decode_tag(e)
                decode!(e, x)
            end
            x = x[]
        elseif isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x)
            x = x[]
        elseif isa(expected, Dict)
            x = Dict{keytype(expected), valtype(expected)}()
            decode!(e, x)
        else
            x = decode(e, typeof(expected))
        end
    else
        if isa(expected, Vector)
            x = BufferedVector{eltype(expected)}()
            decode!(e, w, x, V)
            x = x[]
        elseif isa(expected, Dict)
            x = Dict{keytype(expected), valtype(expected)}()
            decode!(e, x, V)
        else
            x = decode(e, typeof(expected), V)
        end
    end

    @test x == expected
end

function test_decode_message(input_bytes, expected::TestStruct, V=nothing)
    input_bytes = collect(input_bytes)
    e = ProtoDecoder(PipeBuffer(input_bytes))
    if isnothing(V)
        x = decode(e, typeof(expected))
    else
        _, tag = PB.decode_tag(e)
        @assert tag == Codecs.START_GROUP
        x = decode(e, Ref{typeof(expected)}, V)
    end
    @test x.oneof[] == expected.oneof[]
    @test typeof(x) === typeof(expected)
    @test typeof(x.oneof) === typeof(expected.oneof)
end

@testset "decode" begin
    @testset "length delimited" begin
        @testset "bytes" begin
            test_decode(b"123456789", b"123456789")
        end

        @testset "string" begin
            test_decode(b"123456789", "123456789")
        end

        @testset "repeated bytes" begin
            test_decode([0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34], [[0x31, 0x32], [0x33, 0x34]])
        end

        @testset "repeated string" begin
            test_decode([0x12, 0x02, 0x31, 0x32, 0x12, 0x02, 0x33, 0x34], ["12", "34"])
        end

        @testset "repeated uint32" begin
            test_decode([0x01, 0x02], UInt32[1, 2])
        end

        @testset "repeated uint64" begin
            test_decode([0x01, 0x02], UInt64[1, 2])
        end

        @testset "repeated int32" begin
            test_decode([0x01, 0x02], Int32[1, 2])
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int32[-1])
        end

        @testset "repeated enum" begin
            test_decode([0x01, 0x02], [TestEnum.B, TestEnum.C])
        end

        @testset "repeated int64" begin
            test_decode([0x01, 0x02], Int64[1, 2])
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int64[-1])
        end

        @testset "repeated bool" begin
            test_decode([0x00, 0x01, 0x00], Bool[false, true, false])
        end

        @testset "repeated float64" begin
            test_decode(reinterpret(UInt8, Float64[1.0, 2.0]), Float64[1.0, 2.0])
        end

        @testset "repeated float32" begin
            test_decode(reinterpret(UInt8, Float32[1.0, 2.0]), Float32[1.0, 2.0])
        end

        @testset "repeated sfixed32" begin
            test_decode(reinterpret(UInt8, Int32[1, 2]), Int32[1, 2], Val{:fixed})
        end

        @testset "repeated sfixed64" begin
            test_decode(reinterpret(UInt8, Int64[1, 2]), Int64[1, 2], Val{:fixed})
        end

        @testset "repeated fixed32" begin
            test_decode(reinterpret(UInt8, UInt32[1, 2]), UInt32[1, 2], Val{:fixed})
        end

        @testset "repeated fixed64" begin
            test_decode(reinterpret(UInt8, UInt64[1, 2]), UInt64[1, 2], Val{:fixed})
        end

        @testset "repeated sint32" begin
            test_decode([0x02, 0x04, 0x01, 0x03], Int32[1, 2, -1, -2], Val{:zigzag})
        end

        @testset "repeated sint64" begin
            test_decode([0x02, 0x04, 0x01, 0x03], Int64[1, 2, -1, -2], Val{:zigzag})
        end

        @testset "repeated message" begin
            test_decode([0x12, 0x02, 0x08, 0x03, 0x12, 0x02, 0x08, 0x04], [TestInner(3), TestInner(4)])
        end

        @testset "map" begin
            @testset "string,string" begin test_decode([0x0a, 0x01, 0x62, 0x12, 0x01, 0x61], Dict{String,String}("b" => "a")) end

            @testset "int32,string" begin test_decode([0x08, 0x01, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a")) end
            @testset "int64,string" begin test_decode([0x08, 0x01, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a")) end
            @testset "uint32,string" begin test_decode([0x08, 0x01, 0x12, 0x01, 0x61], Dict{UInt32,String}(1 => "a")) end
            @testset "uint64,string" begin test_decode([0x08, 0x01, 0x12, 0x01, 0x61], Dict{UInt64,String}(1 => "a")) end
            @testset "bool,string" begin test_decode([0x08, 0x01, 0x12, 0x01, 0x61], Dict{Bool,String}(true => "a")) end

            @testset "sfixed32,string" begin test_decode([0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "sfixed64,string" begin test_decode([0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed32,string" begin test_decode([0x0d, 0x01, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{UInt32,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end
            @testset "fixed64,string" begin test_decode([0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x01, 0x61], Dict{UInt64,String}(1 => "a"), Val{Tuple{:fixed,Nothing}}) end

            @testset "sint32,string" begin test_decode([0x08, 0x02, 0x12, 0x01, 0x61], Dict{Int32,String}(1 => "a"), Val{Tuple{:zigzag,Nothing}}) end
            @testset "sint64,string" begin test_decode([0x08, 0x02, 0x12, 0x01, 0x61], Dict{Int64,String}(1 => "a"), Val{Tuple{:zigzag,Nothing}}) end

            @testset "string,int32" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Int32}("a" => 1)) end
            @testset "string,int64" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Int64}("a" => 1)) end
            @testset "string,uint32" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,UInt32}("a" => 1)) end
            @testset "string,uint64" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,UInt64}("a" => 1)) end
            @testset "string,bool" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x01], Dict{String,Bool}("a" => true)) end

            @testset "string,sfixed32" begin test_decode([0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{String,Int32}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,sfixed64" begin test_decode([0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,Int64}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed32" begin test_decode([0x0a, 0x01, 0x61, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{String,UInt32}("a" => 1), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,fixed64" begin test_decode([0x0a, 0x01, 0x61, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,UInt64}("a" => 1), Val{Tuple{Nothing,:fixed}}) end

            @testset "string,sint32" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x02], Dict{String,Int32}("a" => 1), Val{Tuple{Nothing,:zigzag}}) end
            @testset "string,sint64" begin test_decode([0x0a, 0x01, 0x61, 0x10, 0x02], Dict{String,Int64}("a" => 1), Val{Tuple{Nothing,:zigzag}}) end


            @testset "sfixed32,sfixed32" begin test_decode([0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{Int32,Int32}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "sfixed64,sfixed64" begin test_decode([0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{Int64,Int64}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed32,fixed32" begin test_decode([0x0d, 0x01, 0x00, 0x00, 0x00, 0x15, 0x01, 0x00, 0x00, 0x00], Dict{UInt32,UInt32}(1 => 1), Val{Tuple{:fixed,:fixed}}) end
            @testset "fixed64,fixed64" begin test_decode([0x09, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x11, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{UInt64,UInt64}(1 => 1), Val{Tuple{:fixed,:fixed}}) end

            @testset "sint32,sint32" begin test_decode([0x08, 0x02, 0x10, 0x02], Dict{Int32,Int32}(1 => 1), Val{Tuple{:zigzag,:zigzag}}) end
            @testset "sint64,sint64" begin test_decode([0x08, 0x02, 0x10, 0x02], Dict{Int64,Int64}(1 => 1), Val{Tuple{:zigzag,:zigzag}}) end
        end

        @testset "message" begin
            test_decode_message([0x0a, 0x03, 0x31, 0x32, 0x33], TestStruct(PB.OneOf(:bytes, collect(b"123"))))
            test_decode_message([0x10, 0x02], TestStruct(PB.OneOf(:enum, TestEnum.C)))
            test_decode_message([0x1a, 0x02, 0x08, 0x02], TestStruct(PB.OneOf(:struct, TestInner(2))))
            test_decode_message([0x1a, 0x06, 0x08, 0x02, 0x12, 0x02, 0x08, 0x03], TestStruct(PB.OneOf(:struct, TestInner(2, TestInner(3)))))
        end

        @testset "group message" begin
            test_decode_message([0x03, 0x0a, 0x03, 0x31, 0x32, 0x33, 0x04], TestStruct(PB.OneOf(:bytes, collect(b"123"))), Val{:group})
            test_decode_message([0x03, 0x10, 0x02, 0x04], TestStruct(PB.OneOf(:enum, TestEnum.C)), Val{:group})
            test_decode_message([0x03, 0x1a, 0x02, 0x08, 0x02, 0x04], TestStruct(PB.OneOf(:struct, TestInner(2))), Val{:group})
            test_decode_message([0x03, 0x1a, 0x06, 0x08, 0x02, 0x12, 0x02, 0x08, 0x03, 0x04], TestStruct(PB.OneOf(:struct, TestInner(2, TestInner(3)))), Val{:group})
        end
    end

    @testset "varint" begin
        @testset "uint32" begin
            test_decode([0x02], UInt32(2))
        end

        @testset "uint64" begin
            test_decode([0x02], UInt64(2))
        end

        @testset "int32" begin
            test_decode([0x02], Int32(2))
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int32(-1))
        end

        @testset "int64" begin
            test_decode([0x02], Int64(2))
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], Int64(-1))
        end

        @testset "bool" begin
            test_decode([0x01], true)
        end

        @testset "sint32" begin
            test_decode([0x04], Int32(2), Val{:zigzag})
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF], typemin(Int32), Val{:zigzag})
            test_decode([0xFE, 0xFF, 0xFF, 0xFF, 0xFF], typemax(Int32), Val{:zigzag})
        end

        @testset "sint64" begin
            test_decode([0x04], Int64(2), Val{:zigzag})
            test_decode([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], typemin(Int64), Val{:zigzag})
            test_decode([0xFE, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01], typemax(Int64), Val{:zigzag})
        end

        @testset "enum" begin
            test_decode([0x02], TestEnum.C)
        end
    end

    @testset "fixed" begin
        @testset "sfixed32" begin
            test_decode(reinterpret(UInt8, [Int32(2)]), Int32(2), Val{:fixed})
        end

        @testset "sfixed64" begin
            test_decode(reinterpret(UInt8, [Int64(2)]), Int64(2), Val{:fixed})
        end

        @testset "fixed32" begin
            test_decode(reinterpret(UInt8, [UInt32(2)]), UInt32(2), Val{:fixed})
        end

        @testset "fixed64" begin
            test_decode(reinterpret(UInt8, [UInt64(2)]), UInt64(2), Val{:fixed})
        end
    end

    @testset "skipping" begin
        io = IOBuffer()
        d = PB.ProtoDecoder(io)
        e = PB.ProtoEncoder(io)
        PB.encode(e, 3, UInt32(42)) # VARINT
        PB.encode(e, 4, [UInt32(42)]) # LENGTH_DELIMITED
        PB.encode(e, 5, Float64(42)) # FIXED64
        PB.encode(e, 6, Float32(42)) # FIXED32
        write(io, 0x03) # START_GROUP
            PB.encode(e, 1, UInt32(42)) # VARINT
            PB.encode(e, 2, [UInt32(42)]) # LENGTH_DELIMITED
            PB.encode(e, 3, Float64(42)) # FIXED64
            PB.encode(e, 4, Float32(42)) # FIXED32
        write(io, 0x04) # END_GROUP
        write(io, 0x03) # START_GROUP
            write(io, 0x03) # START_GROUP
                PB.encode(e, 1, UInt32(42)) # VARINT
                PB.encode(e, 2, [UInt32(42)]) # LENGTH_DELIMITED
                PB.encode(e, 3, Float64(42)) # FIXED64
                PB.encode(e, 4, Float32(42)) # FIXED32
            write(io, 0x04) # END_GROUP
        write(io, 0x04) # END_GROUP
        seekstart(io)

        @test decode(d, TestInner) == TestInner(0)
    end
end
end # module