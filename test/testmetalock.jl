using ProtoBuf
using Test
import ProtoBuf.meta

function testmetalock()
    current_async_safety = ProtoBuf.MetaLock.lck !== nothing
    for async_safety in (true, false)
        ProtoBuf.enable_async_safety(async_safety)
        str = ProtoBuf.metalock() do
            "test with lock enabled $async_safety"
        end
        @test endswith(str, string(async_safety))
    end
    ProtoBuf.enable_async_safety(current_async_safety)
end

@testset "Metadata locking" begin
    testmetalock()
end