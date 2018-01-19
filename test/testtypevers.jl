using ProtoBuf

print_hdr(tname) = println("testing $tname...")

mutable struct V1
    f1::Int32
    f2::Bool
    V1() = (a=new(); clear(a); a)
    V1(f1,f2) = new(f1,f2)
end

mutable struct V2
    f1::Int64
    f2::Bool
    f3::Int64
    V2() = (a=new(); clear(a); a)
    V2(f1,f2,f3) = new(f1,f2,f3)
end

function check_samestruct()
    iob = PipeBuffer();
    writeval = V1(1, true);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    @assert ProtoBuf.protoeq(readval, writeval)

    iob = PipeBuffer();
    writeval = V2(1, true, 20);
    writeproto(iob, writeval);
    readval = readproto(iob, V2());
    @assert ProtoBuf.protoeq(readval, writeval)
end

# write V1, read V2
# write V2, read V1
function check_V1_v2()
    iob = PipeBuffer();
    writeval = V1(1, true);
    writeproto(iob, writeval);
    readval = readproto(iob, V2());
    checkval = V2(1,true,0)
    @assert ProtoBuf.protoeq(readval, checkval)

    iob = PipeBuffer();
    writeval = V2(1, true, 20);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    checkval = V1(1,true)
    @assert ProtoBuf.protoeq(readval, checkval)

    iob = PipeBuffer();
    writeval = V2(typemax(Int64), true, 20);
    writeproto(iob, writeval);
    readval = readproto(iob, V1());
    checkval = V1(-1,true)  # overflow can't be detected as negative int32 is sign extended for serialization
    @assert ProtoBuf.protoeq(readval, checkval)
end

print_hdr("serialization across type versions")
check_samestruct()
check_V1_v2()
