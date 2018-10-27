using Test
using Sockets
import Sockets: TCPServer, close

import ProtoBuf: call_method, write_bytes, read_bytes

include("testsvc_pb.jl")

# Our RpcController for the test does nothing as of now
mutable struct TestRpcController <: ProtoRpcController
    debug::Bool
end

debug_log(controller::TestRpcController, msg) = controller.debug && println(msg)
error_log(controller::TestRpcController, msg) = println(stderr, msg)

# RpcChannel implementation for our test protocol
# The protocol is to write and read:
# - messages as delimited bytes
# - header type SvcHeader to identify the method being called
mutable struct TestRpcChannel <: ProtoRpcChannel
    sock::TCPSocket
end
close(channel::TestRpcChannel) = close(channel.sock)

mutable struct SvcHeader <: ProtoType
    method::String
    SvcHeader() = (o=new(); fillunset(o); o)
end

function write_request(channel::TestRpcChannel, controller::TestRpcController, service::ServiceDescriptor, method::MethodDescriptor, request)
    io = channel.sock
    hdr = SvcHeader()
    hdr.method = method.name

    iob = IOBuffer()

    hdr_len = writeproto(iob, hdr)
    hdr_buff = take!(iob)

    data_len = writeproto(iob, request)
    data_buff = take!(iob)

    write_bytes(io, hdr_buff)
    #debug_log(controller, "req hdr  ==> $hdr_len bytes: $hdr_buff")
    write_bytes(io, data_buff)
    #debug_log(controller, "req data ==> $data_len bytes: $data_buff")
    hdr_len + data_len
end

function read_request(channel::TestRpcChannel, controller::TestRpcController, srvr)
    io = channel.sock
    hdr = SvcHeader()
    hdr_buff = read_bytes(io)
    #debug_log(controller, "req hdr  <== $(length(hdr_buff)) bytes: $hdr_buff")
    readproto(IOBuffer(hdr_buff), hdr)
    method = find_method(srvr, hdr.method)

    request_type = get_request_type(srvr, method)
    request = request_type()
    data_buff = read_bytes(io)
    #debug_log(controller, "req data <== $(length(data_buff)) bytes: $data_buff")
    readproto(IOBuffer(data_buff), request)
    method, request
end

function write_response(channel::TestRpcChannel, controller::TestRpcController, response)
    io = channel.sock
    iob = IOBuffer()
    data_len = writeproto(iob, response)
    data_buff = take!(iob)
    write_bytes(io, data_buff)
    #debug_log(controller, "resp ==> $(length(data_buff)) bytes: $data_buff")
    data_len
end

function read_response(channel::TestRpcChannel, controller::TestRpcController, response)
    io = channel.sock
    data_buff = read_bytes(io)
    #debug_log(controller, "resp <== $(length(data_buff)) bytes: $data_buff")
    readproto(IOBuffer(data_buff), response)
    response
end

function call_method(channel::TestRpcChannel, service::ServiceDescriptor, method::MethodDescriptor, controller::TestRpcController, request)
    write_request(channel, controller, service, method, request)
    response_type = get_response_type(method)
    response = response_type()
    read_response(channel, controller, response)
end

# Test server implementation on the RpcChannel
# 
mutable struct TestServer
    srvr::TCPServer
    impl::ProtoService
    run::Bool
    debug::Bool
    TestServer(port::Integer) = new(listen(port), TestMath(Main), true, false)
end

function process(srvr::TestServer, channel::TestRpcChannel)
    controller = TestRpcController(srvr.debug)
    #debug_log(controller, "starting processing from channel")

    try
        while(!eof(channel.sock))
            method, request = read_request(channel, controller, srvr.impl)
            response = call_method(srvr.impl, method, controller, request)
            #debug_log(controller, "response: $response")
            write_response(channel, controller, response)
        end
    catch ex
        debug_log(controller, "channel stopped with exception $ex")
    end
    #debug_log(controller, "stopped processing channel")
end

# implementations of our test services
function Add(req::BinaryOpReq)
    resp = BinaryOpResp()
    resp.result = req.i1 + req.i2
    resp
end

function Mul(req::BinaryOpReq)
    resp = BinaryOpResp()
    resp.result = req.i1 * req.i2
    resp
end

# Utility methods for running the server and client
function run_server(srvr::TestServer)
    controller = TestRpcController(srvr.debug)
    try
        while(srvr.run)
            sock = accept(srvr.srvr)
            channel = TestRpcChannel(sock)
            @async process(srvr, channel)
        end
    catch ex
        debug_log(controller, "server stopped with exception $ex")
    end
    debug_log(controller, "stopped server")
end

global nresults = 0
function chk_results(out::BinaryOpResp, expected, channel=nothing)
    global nresults
    if channel != nothing
        close(channel)
        nresults += 1
    end
    @test out.result == expected
    nothing
end

function run_client(debug::Bool)
    global nresults
    controller = TestRpcController(debug)

    debug_log(controller, "testing services...")
    debug_log(controller, "testing blocking stub...")
    let channel=TestRpcChannel(connect(9999)), stub=TestMathBlockingStub(channel)
        for i in 1:10
            inp = BinaryOpReq()
            inp.i1 = Int64(rand(Int8))
            inp.i2 = Int64(rand(Int8))

            out = Add(stub, controller, inp)
            chk_results(out, inp.i1+inp.i2)

            out = Mul(stub, controller, inp)
            chk_results(out, inp.i1*inp.i2)
        end
        close(channel)
    end

    debug_log(controller, "testing non blocking stub...")
    for i in 1:10
        inp = BinaryOpReq()
        inp.i1 = Int64(rand(Int8))
        inp.i2 = Int64(rand(Int8))
       
        nresults -= 1
        let channel=TestRpcChannel(connect(9999)), stub=TestMathStub(channel), expected=inp.i1+inp.i2
            Add(stub, controller, inp, (out)->chk_results(out, expected, channel))
        end

        nresults -= 1
        let channel=TestRpcChannel(connect(9999)), stub=TestMathStub(channel), expected=inp.i1*inp.i2
            Mul(stub, controller, inp, (out)->chk_results(out, expected, channel))
        end
    end
    while nresults != 0
        debug_log(controller, "waiting for $(abs(nresults)) results")
        yield()
        sleep(1)
    end
end

debug = true
srvr = TestServer(9999)
srvr.debug = debug
@async run_server(srvr)
sleep(1)
run_client(debug)
srvr.run = false
close(srvr.srvr)
