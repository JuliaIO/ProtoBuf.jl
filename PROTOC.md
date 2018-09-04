## Generating Code (from .proto files)

The Julia code generator plugs in to the `protoc` compiler. It is implemented as `ProtoBuf.Gen`, a sub-module of `ProtoBuf`. The callable program (as required by `protoc`) is provided as the script `ProtoBuf/plugin/protoc-gen-julia`.

Both version 2 and 3 of the protobuf specification language are supported. You just need to use the correct `protoc` compiler version during code generation.

To generate Julia code from `.proto` files, add the above mentioned `plugin` folder to the system `PATH` environment variable, so that `protoc` can find the `protoc-gen-julia` executable. Then invoke `protoc` with the `--julia_out` option.

E.g. to generate Julia code from `proto/plugin.proto`, run the command below which will create a corresponding file `jlout/plugin.jl`.

`protoc -I=proto --julia_out=jlout proto/plugin.proto`

Each `.proto` file results in a corresponding `.jl` file, including one each for other included `.proto` files. Separate `.jl` files are generated with modules corresponding to each top level package.

If a field name in a message or enum matches a Julia keyword, it is prepended with an `_` character during code generation.

If a package contains a message which has the same name as the package itself, optionally set the `JULIA_PROTOBUF_MODULE_POSTFIX=1` environment variable when running `protoc`, this will append `_pb` to the module names.

ProtoBuf `map` types are generated as Julia `Dict` types by default. They can also be generated as `Array` of `key-value`s by setting the `JULIA_PROTOBUF_MAP_AS_ARRAY=1` environment variable when running `protoc`.

### From within Julia
For convenience, ProtoBuf.jl exports a `protoc(args)` command that will setup the `PATH` correctly to make sure `protoc` can find the
plugin as well as making sure that that the plugin can find the correct julia installation. To make use of this feature for the example
above, simply run  (from a Julia REPL):

```
julia> using ProtoBuf

julia> run(ProtoBuf.protoc(`-I=proto --julia_out=jlout proto/plugin.proto`))
```

### Windows Specifics of Code Generation

On Windows, the procedure of compiling the .jl from .proto files is similar:

Using the following cmd (without spaces around the equality sign)

`protoc -I=<Folder with .proto-Files> --plugin=protoc-gen-julia=<Absolute PATH to protoc-gen-julia-File>\protoc-gen-julia_win.bat --julia_out=<Existing Folder where generated .jl files will be stored>   <Path of proto-Files which you want to compile>`

Example for .proto-files located in fhe folder `test\proto`:
`cd C:\Users\<Username>\.julia\v0.6\ProtoBuf\test`

`protoc -I=proto    --plugin=protoc-gen-julia=C:\Users\UELIWECH\.julia\v0.6\ProtoBuf\plugin\protoc-gen-julia_win.bat --julia_out=jlout proto/PROTOFILENAME.proto`


If you want to set the system parameter (as mentioned above) use the following commands (it is important have not whitespaces around the equality sign):

`set JULIA_PROTOBUF_MODULE_POSTFIX=1`
`set JULIA_PROTOBUF_MAP_AS_ARRAY=1`

You can test if it is set correctly by using the echo call.
`echo %Variable_Name%`





### Julia Type Mapping

.proto Type | Julia Type        | Notes
---         | ---               | ---
double      | Float64           |
float       | Float32           |
int32       | Int32             | Uses variable-length encoding. Inefficient for encoding negative numbers – if your field is likely to have negative values, use sint32 instead.
int64       | Int64             | Uses variable-length encoding. Inefficient for encoding negative numbers – if your field is likely to have negative values, use sint64 instead.
uint32      | UInt32            | Uses variable-length encoding.
uint64      | UInt64            | Uses variable-length encoding.
sint32      | Int32             | Uses variable-length encoding. Signed int value. These more efficiently encode negative numbers than regular int32s.
sint64      | Int64             | Uses variable-length encoding. Signed int value. These more efficiently encode negative numbers than regular int64s.
fixed32     | UInt32            | Always four bytes. More efficient than uint32 if values are often greater than 2^28.
fixed64     | UInt64            | Always eight bytes. More efficient than uint64 if values are often greater than 2^56.
sfixed32    | Int32             | Always four bytes.
sfixed64    | Int64             | Always eight bytes.
bool        | Bool              |
string      | ByteString        | A string must always contain UTF-8 encoded or 7-bit ASCII text.
bytes       | Array{UInt8,1}    | May contain any arbitrary sequence of bytes.
map         | Dict              | Can be generated as `Array` of `key-value` by setting environment variable `JULIA_PROTOBUF_MAP_AS_ARRAY=1`

### Well-Known Types

The protocol buffers [well known types](https://developers.google.com/protocol-buffers/docs/reference/google.protobuf) are pre-generated and included in the package as a sub-module `ProtoBuf.google.protobuf`.
The version of the code included with this package have additional changes to make them compatible with Julia.

You can refer to them in your code after including the following statements:
````julia
using ProtoBuf
using ProtoBuf.google.protobuf
````

While generating code for your `.proto` files that use well-known types, add `ProtoBuf/gen` to the list of includes, e.g.:
````julia
protoc -I=proto -I=ProtoBuf/gen --julia_out=jlout proto/msg.proto
````

Though this would generate code for the well-known types along with your messages, you just need to use the files generated for your messages.

### Generic Services
The Julia code generator generates code for generic services if they are switched on for either C++ `(cc_generic_services)`, Python `(py_generic_services)` or Java `(java_generic_services)`.

To use generic services, users provide implementations of the RPC controller, RPC channel, and service methods.

The RPC Controller must be an implementation of `ProtoRpcController`. It is not currently used by the generated code except for passing it on to the RPC channel.

The RPC channel must implement `call_method(channel, method_descriptor, controller, request)` and return the response.

RPC method inputs or outputs that are defined as `stream` type, are generated as `Channel` of the corresponding type.

Service stubs are Julia types. Stubs can be constructed by passing an RPC channel to the constructor. For each service, two stubs are generated:
- <servicename>Stub: The asynchronous stub that takes a callback to invoke with the result on completion
- <servicename>BlockingStub: The blocking stub that returns the result on completion

## Note:

- Extensions are not supported yet.
- Groups are not supported. They are deprecated anyway.
- Enums are declared as `Int32` types in the generated code, but a separate Julia type is generated with fields same as the enum values which can be used for validation. The types representing enums extend from the abstract type `ProtoEnum` and the `lookup` method can be used to verify valid values.
