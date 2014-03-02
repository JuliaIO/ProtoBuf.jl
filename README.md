# ProtoBuf.jl

[![Build Status](https://travis-ci.org/tanmaykm/ProtoBuf.jl.png)](https://travis-ci.org/tanmaykm/ProtoBuf.jl)

[**Protocol buffers**](https://developers.google.com/protocol-buffers/docs/overview) are a language-neutral, platform-neutral, extensible way of serializing structured data for use in communications protocols, data storage, and more.

**ProtoBuf.jl** is a Julia implementation for protocol buffers.


## Getting Started

Reading and writing data structures using ProtoBuf is similar to serialization and deserialization. Methods `writeproto` and `readproto` can write and read Julia types from IO streams respectively.

````
julia> using ProtoBuf

julia> type MyType                          # here's a Julia composite type
         intval::Int
         strval::ASCIIString
         MyType() = new()
         MyType(i,s) = new(i,s)
       end

julia> iob = PipeBuffer();

julia> writeproto(iob, MyType(10, "hello world"));   # write an instance of it

julia> readproto(iob, MyType())  # read it back into another instance
MyType(10,"hello world")
````

## Protocol Buffer Metadata

ProtoBuf serialization can be customized for a type by defining a `meta` method on it. The `meta` method provides an instance of `ProtoMeta` that allows specification of mandatory fields, field numbers, and default values for fields for a type. Defining a specialized `meta` is done simply as below:

````
import ProtoBuf.meta

meta(t::Type{MyType}) = meta(t,  # the type which this is for
		# required fields
		Symbol[:intval],
		# the field numbers
		Int[8, 10], 
		# default values
		Dict{Symbol,Any}({:strval => "default value"}))
````

Without any specialied `meta` method:

- All fields are marked as optional (or repeating for arrays)
- Numeric fields have zero as default value
- String fields have `""` as default value
- Field numbers are assigned serially starting from 1, in the order of their declaration.

For the things where the default is what you need, just passing empty values would do. E.g., if you just want to specify the field numbers, this would do:

````
meta(t::Type{MyType}) = meta(t, [], [8,10], Dict())
````

## Checking Valid Fields

With fields set as optional, it is quite likely that some field in the instance you just read may not be present. For a freshly constructed object, it may suffice to check if the member is defined (`isdefined(obj, fld)`). But if an object is being reused, the field may have been populated during an earlier read. 

The `filled` method comes handy in such cases. It returns `true` only if the field was populated the last time it was read using `readproto`.

````
julia> using ProtoBuf

julia> type MyType                # here's a Julia composite type
           intval::Int
           MyType() = new()
           MyType(i) = new(i)
       end

julia> 

julia> type OptType               # and another one to contain it
           opt::MyType
           OptType() = new()
           OptType(o) = new(o)
       end

julia> iob = PipeBuffer();

julia> writeproto(iob, OptType(MyType(10)));

julia> readval = readproto(iob, OptType());

julia> filled(readval, :opt)       # valid this time
true

julia> 

julia> writeproto(iob, OptType());

julia> readval = readproto(iob, OptType());

julia> filled(readval, :opt)       # but not valid now
false
````


## Generating Code (from .proto files)
The Julia code generator plugs in to the `protoc` compiler. It is implemented as `ProtoBuf.Gen`, a sub-module of `ProtoBuf`. The callable program (as required by `protoc`)is provided as the script `plugin/protoc-gen-julia`.

To generate Julia code from `.proto` files, add the above mentioned `plugin` folder to the `PATH`, so that `protoc` can find the `protoc-gen-julia` executable. Then invoke `protoc` with the `--julia_out` option. 

E.g. to generate Julia code from `plugin.proto`, run the command below which will  create a corresponding file `jlout/plugin.jl`.

````
protoc -I proto proto/plugin.proto --julia_out jlout
````


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


## Caveats &amp; TODOs

- Extensions are not supported yet.
- Services are not supported yet.
- Gropus are not supported. They are deprecated anyway.
- To be able to use a Julia type in protobuf, it must have an empty constructor. This is to enable the deserializer create an instance of the type on its own. (This restriction should go away soon.)
- Generated code translates package name specified into Julia modules, but uses only one level of module. So a package name of `com.foo.bar` will get translated to a Julia module `com_foo_bar`. This may become better in the future with special `module` directive for Julia.
- Julia does not have `enum` types. In generated code, enums are declared as `Int32` types, but a separate Julia type is generated with fields same as the enum values which can be used for validation.


