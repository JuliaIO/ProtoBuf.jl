using ProtocolBuffers: Codecs
import ProtocolBuffers as PB
using .Codecs: decode, decode!, ProtoDecoder, BufferedVector
using Test
using EnumX: @enumx

# Without this, we'll get an invalid redefinition when re-running this file
if !isdefined(@__MODULE__, :TestEnum)
    @enumx TestEnum A B C
end
if !isdefined(@__MODULE__, :TestStruct)
    struct TestInner
        x::Int
        r::Union{Nothing,TestInner}
    end
    TestInner(x::Int) = TestInner(x, nothing)
    struct TestStruct{T<:Union{Vector{UInt8},TestEnum.T,TestInner}}
        oneof::Union{Nothing, PB.OneOf{T}}
    end
end

function PB.decode(d::PB.AbstractProtoDecoder, ::Type{TestInner})
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
        PB.try_eat_end_group(d, wire_type)
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
        PB.try_eat_end_group(d, wire_type)
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

function test_decode_message(input_bytes, expected::TestStruct)
    input_bytes = collect(input_bytes)
    e = ProtoDecoder(PipeBuffer(input_bytes))
    x = decode(e, typeof(expected))
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
            test_decode([0x02, 0x31, 0x32, 0x02, 0x33, 0x34], [[0x31, 0x32], [0x33, 0x34]])
        end

        @testset "repeated string" begin
            test_decode([0x02, 0x31, 0x32, 0x02, 0x33, 0x34], ["12", "34"])
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
            test_decode([0x02, 0x08, 0x03, 0x02, 0x08, 0x04], [TestInner(3), TestInner(4)])
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

            @testset "string,repeated int32" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x01], Dict{String,Vector{Int32}}("a" => [1])) end
            @testset "string,repeated int64" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x01], Dict{String,Vector{Int64}}("a" => [1])) end
            @testset "string,repeated uint32" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x01], Dict{String,Vector{UInt32}}("a" => [1])) end
            @testset "string,repeated uint64" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x01], Dict{String,Vector{UInt64}}("a" => [1])) end
            @testset "string,repeated bool" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x01], Dict{String,Vector{Bool}}("a" => [true])) end

            @testset "string,repeated sfixed32" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x04, 0x01, 0x00, 0x00, 0x00], Dict{String,Vector{Int32}}("a" => [1]), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated sfixed64" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,Vector{Int64}}("a" => [1]), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated fixed32" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x04, 0x01, 0x00, 0x00, 0x00], Dict{String,Vector{UInt32}}("a" => [1]), Val{Tuple{Nothing,:fixed}}) end
            @testset "string,repeated fixed64" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], Dict{String,Vector{UInt64}}("a" => [1]), Val{Tuple{Nothing,:fixed}}) end

            @testset "string,repeated sint32" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x02], Dict{String,Vector{Int32}}("a" => [1]), Val{Tuple{Nothing,:zigzag}}) end
            @testset "string,repeated sint64" begin test_decode([0x0a, 0x01, 0x61, 0x12, 0x01, 0x02], Dict{String,Vector{Int64}}("a" => [1]), Val{Tuple{Nothing,:zigzag}}) end
        end

        @testset "message" begin
            test_decode_message([0x0a, 0x03, 0x31, 0x32, 0x33], TestStruct(PB.OneOf(:bytes, collect(b"123"))))
            test_decode_message([0x10, 0x02], TestStruct(PB.OneOf(:enum, TestEnum.C)))
            test_decode_message([0x1a, 0x02, 0x08, 0x02], TestStruct(PB.OneOf(:struct, TestInner(2))))
            test_decode_message([0x1a, 0x06, 0x08, 0x02, 0x12, 0x02, 0x08, 0x03], TestStruct(PB.OneOf(:struct, TestInner(2, TestInner(3)))))
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
        end

        @testset "sint64" begin
            test_decode([0x04], Int64(2), Val{:zigzag})
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
end