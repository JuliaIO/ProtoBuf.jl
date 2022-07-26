# ProtocolBuffers.jl

[![][docs-dev-img]][docs-dev-url]

This is a Julia package that provides a compiler and a codec for Protocol Buffers.

Protocol Buffers are a language-neutral, platform-neutral extensible mechanism for serializing structured data.

## Example

Given a `test.proto` file in your current working directory:
```protobuf
syntax = "proto3";

message MyMessage {
    sint32 a = 1;
    repeated string b = 2;
}
```
You can generate Julia bindings with the `protojl` function:
```julia
using ProtocolBuffers
protojl("test.proto", ".", "output_dir")
```

This will create a Julia file at `output_dir/test_pb.jl` which you can simply `include` and start using it to encode and decode messages:

```julia
include("output_dir/test_pb.jl")
# Main.test_pb

io = IOBuffer();

e = ProtoEncoder(io);

encode(e, test_pb.MyMessage(-1, ["a", "b"]))
# 8

seekstart(io);

d = ProtoDecoder(io);

decode(d, test_pb.MyMessage)
# Main.test_pb.MyMessage(-1, ["a", "b"])
```
## Acknowledgement

We'd like to thank the authors of the following packages, as we took inspiration from their projects:

* We used [Tokenize.jl](https://github.com/JuliaLang/Tokenize.jl) as a reference when implementing the Lexer/Parser.
* We used [ProtoBuf.jl](https://github.com/JuliaIO/ProtoBuf.jl) as a giant shoulder to stand on:).

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://drvi.github.io/ProtocolBuffers.jl/dev/