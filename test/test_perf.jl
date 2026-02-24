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
@test_opt _encoded_size(typemax(UInt32), Val{:zigzag})
@test_opt _encoded_size(typemax(UInt64), Val{:zigzag})
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
@test_opt _encoded_size([typemax(UInt32)], Val{:zigzag})
@test_opt _encoded_size([typemax(UInt64)], Val{:zigzag})
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
@test_opt _encoded_size(Dict(typemax(UInt32) => "V"), Val{Tuple{:zigzag,Nothing}})
@test_opt _encoded_size(Dict(typemax(UInt64) => "V"), Val{Tuple{:zigzag,Nothing}})
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

# allocs
seekstart(io)
let x = typemax(UInt32)
    @test_noalloc vbyte_encode(io, x)
end
@test_noalloc vbyte_decode_and_forget(UInt32, io)

let x = typemax(UInt64)
    @test_noalloc vbyte_encode(io, x)
end
@test_noalloc vbyte_decode_and_forget(UInt64, io)


let x = [UInt8[0xff]]; @test_noalloc _encoded_size(x); nothing end
let x = ["S"]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(UInt32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(UInt64)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x); nothing end
let x = [true]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Int32)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemax(Int64)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemin(UInt32)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
let x = [typemax(UInt64)]; @test_noalloc _encoded_size(x, Val{:zigzag}); nothing end
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
let x = Dict("K" => typemax(UInt32)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict("K" => typemax(UInt64)), V=Val{Tuple{Nothing,:zigzag}}; @test_noalloc _encoded_size(x, V); nothing end
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
let x = Dict(typemax(Int32) => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(Int64) => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(true => "V"); @test_noalloc _encoded_size(x); nothing end
let x = Dict(typemax(Int32) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int64) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemin(UInt32) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemin(UInt64) => "V"), V=Val{Tuple{:zigzag,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(TestEnum.OTHER => "V"); @test_noalloc _encoded_size(x); nothing end

let x = Dict(typemax(UInt32) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(UInt64) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int32) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end
let x = Dict(typemax(Int64) => "V"), V=Val{Tuple{:fixed,Nothing}}; @test_noalloc _encoded_size(x, V); nothing end

let x = typemax(Float32); @test_noalloc _encoded_size(x); nothing end
let x = typemax(Float64); @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Float32)]; @test_noalloc _encoded_size(x); nothing end
let x = [typemax(Float64)]; @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Float32)); @test_noalloc _encoded_size(x); nothing end
let x = Dict("K" => typemax(Float64)); @test_noalloc _encoded_size(x); nothing end
