module JETPerformanceAnalysis
using JET
using ProtoBuf: Codecs
using .Codecs: vbyte_decode, vbyte_encode, _encoded_size
using Test
using EnumX

@enumx TestEnum DEFAULT OTHER

macro test_noalloc(e)
    esc(Expr(:macrocall, Symbol("@test"), __source__,
        Expr(:call, :(==),
            Expr(:macrocall, Symbol("@allocated"), __source__, e),
            0)))
end


@testset "Performance checks" begin

io = IOBuffer(sizehint=8*1024*1024)

@test_opt vbyte_encode(io, typemax(UInt32))
@test_opt vbyte_encode(io, typemax(UInt64))
@test_opt vbyte_decode(io, UInt32)
@test_opt vbyte_decode(io, UInt64)

# to avoid compilation allocs
vbyte_encode(io, typemax(UInt32))
seekstart(io)
vbyte_decode(io, UInt32)
vbyte_encode(io, typemax(UInt64))
seekstart(io)
vbyte_decode(io, UInt64)

# A vbyte_decode that throws away the value so we don't count the results in the allocation tests
vbyte_decode_and_forget(::Type{T}, io) where {T} = (seekstart(io); vbyte_decode(io, T); nothing)

seekstart(io)
let x = typemax(UInt32)
    @test_noalloc vbyte_encode(io, x)
end
vbyte_decode_and_forget(UInt32, io) # precompile
@test_noalloc vbyte_decode_and_forget(UInt32, io)

let x = typemax(UInt64)
    @test_noalloc vbyte_encode(io, x)
end
vbyte_decode_and_forget(UInt64, io) # precompile
@test_noalloc vbyte_decode_and_forget(UInt64, io)

@enumx TestEnum DEFAULT=0 OTHER=1

struct EmptyMessage end
Codecs._encoded_size(x::EmptyMessage) = 0

abstract type var"##AbstractNonEmptyMessage" end
struct NonEmptyMessage <: var"##AbstractNonEmptyMessage"
    x::UInt32
    self_referential_field::Union{Nothing,NonEmptyMessage}
end
function Codecs._encoded_size(x::NonEmptyMessage)
    encoded_size = 0
    x.x != zero(UInt32) && (encoded_size += _encoded_size(x.x, 1))
    !isnothing(x.self_referential_field) && (encoded_size += _encoded_size(x.self_referential_field, 2))
    return encoded_size
end

# precompile
_encoded_size(UInt8[0xff])
_encoded_size("S")
_encoded_size(typemax(UInt32))
_encoded_size(typemax(UInt64))
_encoded_size(typemax(Int32))
_encoded_size(typemax(Int64))
_encoded_size(true)
_encoded_size(typemax(Int32), Val{:zigzag})
_encoded_size(typemax(Int64), Val{:zigzag})
_encoded_size(typemax(Int32), Val{:zigzag})
_encoded_size(typemax(Int64), Val{:zigzag})
_encoded_size(TestEnum.OTHER)
_encoded_size(typemax(Int32), Val{:fixed})
_encoded_size(typemax(Int64), Val{:fixed})
_encoded_size(typemax(UInt32), Val{:fixed})
_encoded_size(typemax(UInt64), Val{:fixed})
_encoded_size(EmptyMessage())
_encoded_size(NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing)))

_encoded_size([UInt8[0xff]])
_encoded_size(["S"])
_encoded_size([typemax(UInt32)])
_encoded_size([typemax(UInt64)])
_encoded_size([typemax(Int32)])
_encoded_size([typemax(Int64)])
_encoded_size([true])
_encoded_size([typemax(Int32)], Val{:zigzag})
_encoded_size([typemax(Int64)], Val{:zigzag})
_encoded_size([typemin(Int32)], Val{:zigzag})
_encoded_size([typemax(Int64)], Val{:zigzag})
_encoded_size([TestEnum.OTHER])
_encoded_size([typemax(Int32)], Val{:fixed})
_encoded_size([typemax(Int64)], Val{:fixed})
_encoded_size([typemax(UInt32)], Val{:fixed})
_encoded_size([typemax(UInt64)], Val{:fixed})
_encoded_size([EmptyMessage()])
_encoded_size([NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))])
_encoded_size(Dict("K" => UInt8[0xff]))
_encoded_size(Dict("K" => "S"))
_encoded_size(Dict("KEY" => "STR"))
_encoded_size(Dict("K" => typemax(UInt32)))
_encoded_size(Dict("K" => typemax(UInt64)))
_encoded_size(Dict("K" => typemax(Int32)))
_encoded_size(Dict("K" => typemax(Int64)))
_encoded_size(Dict("K" => true))
_encoded_size(Dict("K" => typemax(Int32)), Val{Tuple{Nothing,:zigzag}})
_encoded_size(Dict("K" => typemax(Int64)), Val{Tuple{Nothing,:zigzag}})
_encoded_size(Dict("K" => typemin(Int32)), Val{Tuple{Nothing,:zigzag}})
_encoded_size(Dict("K" => typemin(Int64)), Val{Tuple{Nothing,:zigzag}})
_encoded_size(Dict("K" => TestEnum.OTHER))

_encoded_size(Dict("K" => typemax(UInt32)), Val{Tuple{Nothing,:fixed}})
_encoded_size(Dict("K" => typemax(UInt64)), Val{Tuple{Nothing,:fixed}})
_encoded_size(Dict("K" => typemax(Int32)),  Val{Tuple{Nothing,:fixed}})
_encoded_size(Dict("K" => typemax(Int64)),  Val{Tuple{Nothing,:fixed}})

_encoded_size(Dict("K" => EmptyMessage()))
_encoded_size(Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))))
_encoded_size(Dict(typemax(UInt32) => "V"))
_encoded_size(Dict(typemax(UInt64) => "V"))
_encoded_size(Dict(typemax(Int32) => "V"))
_encoded_size(Dict(typemax(Int64) => "V"))
_encoded_size(Dict(true => "V"))
_encoded_size(Dict(typemax(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})
_encoded_size(Dict(typemax(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})
_encoded_size(Dict(typemin(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})
_encoded_size(Dict(typemin(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})
_encoded_size(Dict(TestEnum.OTHER => "V"))

_encoded_size(Dict(typemax(UInt32) => "V"), Val{Tuple{:fixed,Nothing}})
_encoded_size(Dict(typemax(UInt64) => "V"), Val{Tuple{:fixed,Nothing}})
_encoded_size(Dict(typemax(Int32) => "V"),  Val{Tuple{:fixed,Nothing}})
_encoded_size(Dict(typemax(Int64) => "V"),  Val{Tuple{:fixed,Nothing}})

_encoded_size(typemax(Float32))
_encoded_size(typemax(Float64))
_encoded_size([typemax(Float32)])
_encoded_size([typemax(Float64)])
_encoded_size(Dict("K" => typemax(Float32)))
_encoded_size(Dict("K" => typemax(Float64)))

# JET
@test_opt _encoded_size(UInt8[0xff])
@test_opt _encoded_size("S")
@test_opt _encoded_size(typemax(UInt32))
@test_opt _encoded_size(typemax(UInt64))
@test_opt _encoded_size(typemax(Int32))
@test_opt _encoded_size(typemax(Int64))
@test_opt _encoded_size(true)
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(TestEnum.OTHER)
@test_opt _encoded_size(typemax(Int32), Val{:fixed})
@test_opt _encoded_size(typemax(Int64), Val{:fixed})
@test_opt _encoded_size(typemax(UInt32), Val{:fixed})
@test_opt _encoded_size(typemax(UInt64), Val{:fixed})
@test_opt _encoded_size(EmptyMessage())
@test_opt _encoded_size(NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing)))


@test_opt _encoded_size(UInt8[0xff])
@test_opt _encoded_size("S")
@test_opt _encoded_size(typemax(UInt32))
@test_opt _encoded_size(typemax(UInt64))
@test_opt _encoded_size(typemax(Int32))
@test_opt _encoded_size(typemax(Int64))
@test_opt _encoded_size(true)
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(TestEnum.OTHER)
@test_opt _encoded_size(typemax(Int32), Val{:fixed})
@test_opt _encoded_size(typemax(Int64), Val{:fixed})
@test_opt _encoded_size(typemax(UInt32), Val{:fixed})
@test_opt _encoded_size(typemax(UInt64), Val{:fixed})
@test_opt _encoded_size(EmptyMessage())
@test_opt _encoded_size(NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing)))

@test_opt _encoded_size([UInt8[0xff]])
@test_opt _encoded_size(["S"])
@test_opt _encoded_size([typemax(UInt32)])
@test_opt _encoded_size([typemax(UInt64)])
@test_opt _encoded_size([typemax(Int32)])
@test_opt _encoded_size([typemax(Int64)])
@test_opt _encoded_size([true])
@test_opt _encoded_size([typemax(Int32)], Val{:zigzag})
@test_opt _encoded_size([typemax(Int64)], Val{:zigzag})
@test_opt _encoded_size([typemin(Int32)], Val{:zigzag})
@test_opt _encoded_size([typemax(Int64)], Val{:zigzag})
@test_opt _encoded_size([TestEnum.OTHER])
@test_opt _encoded_size([typemax(Int32)], Val{:fixed})
@test_opt _encoded_size([typemax(Int64)], Val{:fixed})
@test_opt _encoded_size([typemax(UInt32)], Val{:fixed})
@test_opt _encoded_size([typemax(UInt64)], Val{:fixed})
@test_opt _encoded_size([EmptyMessage()])
@test_opt _encoded_size([NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))])
@test_opt _encoded_size(Dict("K" => UInt8[0xff]))
@test_opt _encoded_size(Dict("K" => "S"))
@test_opt _encoded_size(Dict("KEY" => "STR"))
@test_opt _encoded_size(Dict("K" => typemax(UInt32)))
@test_opt _encoded_size(Dict("K" => typemax(UInt64)))
@test_opt _encoded_size(Dict("K" => typemax(Int32)))
@test_opt _encoded_size(Dict("K" => typemax(Int64)))
@test_opt _encoded_size(Dict("K" => true))
@test_opt _encoded_size(Dict("K" => typemax(Int32)), Val{Tuple{Nothing,:zigzag}})
@test_opt _encoded_size(Dict("K" => typemax(Int64)), Val{Tuple{Nothing,:zigzag}})
@test_opt _encoded_size(Dict("K" => typemin(Int32)), Val{Tuple{Nothing,:zigzag}})
@test_opt _encoded_size(Dict("K" => typemin(Int64)), Val{Tuple{Nothing,:zigzag}})
@test_opt _encoded_size(Dict("K" => TestEnum.OTHER))

@test_opt _encoded_size(Dict("K" => typemax(UInt32)), Val{Tuple{Nothing,:fixed}})
@test_opt _encoded_size(Dict("K" => typemax(UInt64)), Val{Tuple{Nothing,:fixed}})
@test_opt _encoded_size(Dict("K" => typemax(Int32)),  Val{Tuple{Nothing,:fixed}})
@test_opt _encoded_size(Dict("K" => typemax(Int64)),  Val{Tuple{Nothing,:fixed}})

@test_opt _encoded_size(Dict("K" => EmptyMessage()))
@test_opt _encoded_size(Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))))
@test_opt _encoded_size(Dict(typemax(UInt32) => "V"))
@test_opt _encoded_size(Dict(typemax(UInt64) => "V"))
@test_opt _encoded_size(Dict(typemax(Int32) => "V"))
@test_opt _encoded_size(Dict(typemax(Int64) => "V"))
@test_opt _encoded_size(Dict(true => "V"))
@test_opt _encoded_size(Dict(typemax(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})
@test_opt _encoded_size(Dict(typemax(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})
@test_opt _encoded_size(Dict(typemin(Int32) => "V"), Val{Tuple{:zigzag,Nothing}})
@test_opt _encoded_size(Dict(typemin(Int64) => "V"), Val{Tuple{:zigzag,Nothing}})
@test_opt _encoded_size(Dict(TestEnum.OTHER => "V"))

@test_opt _encoded_size(Dict(typemax(UInt32) => "V"), Val{Tuple{:fixed,Nothing}})
@test_opt _encoded_size(Dict(typemax(UInt64) => "V"), Val{Tuple{:fixed,Nothing}})
@test_opt _encoded_size(Dict(typemax(Int32) => "V"),  Val{Tuple{:fixed,Nothing}})
@test_opt _encoded_size(Dict(typemax(Int64) => "V"),  Val{Tuple{:fixed,Nothing}})

@test_opt _encoded_size(typemax(Float32))
@test_opt _encoded_size(typemax(Float64))
@test_opt _encoded_size([typemax(Float32)])
@test_opt _encoded_size([typemax(Float64)])
@test_opt _encoded_size(Dict("K" => typemax(Float32)))
@test_opt _encoded_size(Dict("K" => typemax(Float64)))

@test_opt _encoded_size(UInt8[0xff])
@test_opt _encoded_size("S")
@test_opt _encoded_size(typemax(UInt32))
@test_opt _encoded_size(typemax(UInt64))
@test_opt _encoded_size(typemax(Int32))
@test_opt _encoded_size(typemax(Int64))
@test_opt _encoded_size(true)
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(typemax(Int32), Val{:zigzag})
@test_opt _encoded_size(typemax(Int64), Val{:zigzag})
@test_opt _encoded_size(TestEnum.OTHER)
@test_opt _encoded_size(typemax(Int32), Val{:fixed})
@test_opt _encoded_size(typemax(Int64), Val{:fixed})
@test_opt _encoded_size(typemax(UInt32), Val{:fixed})
@test_opt _encoded_size(typemax(UInt64), Val{:fixed})
@test_opt _encoded_size(EmptyMessage())
@test_opt _encoded_size(NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing)))

# allocs
let x = [UInt8[0xff]]; @test_noalloc _encoded_size(x); nothing end
let x = ["S"]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(UInt32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(UInt64)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x); nothing end
let x = [true]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int32)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemin(Int32)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [TestEnum.OTHER]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int32)]; @test_noalloc _encoded_size(x, Val{:fixed}); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x, Val{:fixed}); nothing end
let x = [typemax(UInt32)]; @test_noalloc _encoded_size(x, Val{:fixed}); nothing end
let x = [typemax(UInt64)]; @test_noalloc _encoded_size(x, Val{:fixed}); nothing end
let x = [EmptyMessage()]; @test_noalloc _encoded_size(x); nothing end
let x = [NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))]; @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => UInt8[0xff]); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => "S"); @test_noalloc _encoded_size(x); nothing end
let x = Dict("KEY" => "STR"); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(UInt32)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(UInt64)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Int32)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Int64)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => true); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Int32)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemax(Int64)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemin(Int32)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemin(Int64)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => TestEnum.OTHER); @test_noalloc _encoded_size(x); nothing end

let x = Dict("K" => typemax(UInt32)), V=Val{Tuple{Nothing,:fixed}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemax(UInt64)), V=Val{Tuple{Nothing,:fixed}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemax(Int32)) , V=Val{Tuple{Nothing,:fixed}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemax(Int64)) , V=Val{Tuple{Nothing,:fixed}}; @test_noalloc _encoded_size(x, V); nothing end

let x = Dict("K" => EmptyMessage()); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => NonEmptyMessage(typemax(UInt32), NonEmptyMessage(typemax(UInt32), nothing))); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(UInt32) => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(UInt64) => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(Int32) => "V");  @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(Int64) => "V");  @test_noalloc _encoded_size(x); nothing end
let x = Dict(true => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(Int32) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int64) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemin(Int32) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemin(Int64) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(TestEnum.OTHER => "V"); @test_noalloc _encoded_size(x); nothing end

let x = Dict(typemax(UInt32) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(UInt64) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int32) => "V"),  V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int64) => "V"),  V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end

let x = typemax(Float32); @test_noalloc _encoded_size(x); nothing end
let x = typemax(Float64); @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Float32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Float64)]; @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Float32)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Float64)); @test_noalloc _encoded_size(x); nothing end
end # testset
end # module
