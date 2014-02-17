using Protobuf

enum(x) = int(x)
sint32(x) = int32(x)
sint64(x) = int64(x)
fixed64(x) = float64(x)
sfixed64(x) = float64(x)
double(x) = float64(x)
fixed32(x) = float32(x)
sfixed32(x) = float32(x)

function test()
    pb = PipeBuffer()

    for typ in [:int32, :int64, :uint32, :uint64, :sint32, :sint64, :bool, :enum]
        println("testing $typ")
        for idx in 1:100
            rint = eval(typ)(rand() * 10^9)
            rfld = int(rand() * 100) + 1
            writeproto(pb, rfld, typ, rint)
            @assert rint == readproto(pb, typ)
        end
    end

    for typ in [:fixed64, :sfixed64, :double, :fixed32, :sfixed32, :float]
        println("testing $typ")
        for idx in 1:100
            rfloat = (typ != :float) ? eval(typ)(rand() * 10^9) : float32(rand() * 10^9)
            rfld = int(rand() * 100) + 1
            writeproto(pb, rfld, typ, rfloat)
            #println("wrote $rfld : $rfloat")
            rfloat1 = readproto(pb, typ)
            #println("read $rfloat1")
            @assert rfloat == rfloat1
        end
    end

    println("testing string")
    for idx in 1:100
        rstr = randstring(50)
        rfld = int(rand() * 100) + 1
        writeproto(pb, rfld, :string, rstr)
        rstr1 = readproto(pb, :string)
        @assert rstr == rstr1
    end

    println("testing bytes")
    for idx in 1:100
        rstr = randstring(50)
        rfld = int(rand() * 100) + 1
        writeproto(pb, rfld, :bytes, rstr.data)
        data1 = readproto(pb, :bytes)
        @assert rstr.data == data1
    end
end

test()

