# ProtoBuf.jl

[![Build Status](https://travis-ci.org/tanmaykm/Protobuf.jl.png)](https://travis-ci.org/tanmaykm/Protobuf.jl)

[**Protocol buffers**](https://developers.google.com/protocol-buffers/docs/overview) are a language-neutral, platform-neutral, extensible way of serializing structured data for use in communications protocols, data storage, and more.

**ProtoBuf.jl** is a Julia Protobuf implementation for protocol buffers.

**Features:**

- Can serialize and deserialize simple Julia types automatically, without the need of defining metadata. 
- Provides an easy way to create protocol buffer metadata for Julia types. 
- Includes a `protoc` code generator for `.proto` files.

## Getting Started
TODO

## Generating Code (from .proto files)
TODO



### Julia Type Mapping

.proto Type | Julia Type        | Notes
---         | ---               | ---
double      | Float64           | 
float       | Float64           | 
int32       | Int32             | Uses variable-length encoding. Inefficient for encoding negative numbers – if your field is likely to have negative values, use sint32 instead.
int64       | Int64             | Uses variable-length encoding. Inefficient for encoding negative numbers – if your field is likely to have negative values, use sint64 instead.
uint32      | Uint32            | Uses variable-length encoding.
uint64      | Uint64            | Uses variable-length encoding.
sint32      | Int32             | Uses variable-length encoding. Signed int value. These more efficiently encode negative numbers than regular int32s.
sint64      | Int64             | Uses variable-length encoding. Signed int value. These more efficiently encode negative numbers than regular int64s.
fixed32     | Uint32            | Always four bytes. More efficient than uint32 if values are often greater than 2^28.
fixed64     | Uint64            | Always eight bytes. More efficient than uint64 if values are often greater than 2^56.
sfixed32    | Int32             | Always four bytes.
sfixed64    | Int64             | Always eight bytes.
bool        | Bool              | 
string      | ByteString        | A string must always contain UTF-8 encoded or 7-bit ASCII text.
bytes       | Array{Uint8,1}    | May contain any arbitrary sequence of bytes.


### Code Generation

All message types in `<protoname>.proto` file map on to Julia types and are generated into a `<protoname>_messages.jl` file. Each message type has corresponding `serialize` and `deserialize` methods that implement the wire protocol.

Enumerations in `<protoname>.proto` file map on to modules with `const` enum values and an enum method for validation. All enumerations are generated in a `<protoname>_enums.jl` file which is included and referred to in the generated `messages.jl` file.

RPC methods defined for the message types are generated into a `<protoname>_rpc.jl` file.

Julia code using protobuf RPC on a message type `foo` would roughly look like:

````
using Protobuf                # import the protobuf framework methods

include("foo-messages.jl")    # include the generated message types
include("foo-enums.jl")       # include the generated enumerations (if any)
include("foo-rpc.jl")         # include the generated rpc methods (if any)

# plain protobuf serialize/deserialize
serproto(s, foo1)
foo2 = deserproto(s, foo)

# call a rpc method foofn
foo2 = foofn("hello world", foo1)
````


