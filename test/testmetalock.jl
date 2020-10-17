using ProtoBuf
import ProtoBuf.meta

function testmetalock()
    println("testing metadata generation locking...")
    current_async_safety = ProtoBuf.MetaLock.lck !== nothing
    for async_safety in (true, false)
        ProtoBuf.enable_async_safety(async_safety)
        ProtoBuf.metalock() do 
            "test with lock enabled $async_safety"
        end
    end
    ProtoBuf.enable_async_safety(current_async_safety)
    nothing
end