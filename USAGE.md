## Using ProtoBuf

Julia code for protobuf message types can be generated via protoc (see ["Generating Julia Code from .proto Specifications"](PROTOC.md)). Generated Julia code for a protobuf message look something like:

```julia
mutable struct Description <: ProtoType
    # a bunch of internal fields
    ...
    function Description(; kwargs...)
        # code to initialize the internal fields
    end
end # mutable struct Description
const __meta_Description = Ref{ProtoMeta}()
function meta(::Type{Description})
    # code to initialize the metadata
    __meta_Description[]
end
function Base.getproperty(obj::Description, name::Symbol)
    # code to get properties
end
```

Reading and writing data structures using ProtoBuf is similar to serialization and deserialization. Methods `writeproto` and `readproto` can write and read Julia types from IO streams.

```julia
julia> using ProtoBuf                       # include protoc generated package here

julia> mutable struct MyType <: ProtoType   # a Julia composite type generated from protoc that
         ...                                # has intval::Int and strval::String as properties
         function MyType(; kwargs...)
             ...
         end
       end
       ...

julia> iob = PipeBuffer();

julia> writeproto(iob, MyType(; intval=10, strval="hello world"));   # write an instance of it

julia> data = readproto(iob, MyType());  # read it back into another instance

julia> data.intval
10

julia> data.strval
"hello world"
```

Reading message from a file is very similar to reading from a stream. Here's an example that writes a message to file and then reads it back.

```julia
julia> include("test_type.jl")

julia> mktemp() do path, io
           tt1 = TestType(; a="abc", b=true) # construct a message
           writeproto(io, tt1)  # write message to file
           close(io) # close the file handle
           open(path) do io2 # open the file we just wrote in read mode
               tt2 = readproto(io2, TestType()) # read message from the file
               @info("read back from file", tt1.a, tt1.b, tt2.a, tt2.b) # print written and read messages
           end
       end
┌ Info: read back from file
│   tt1.a = "abc"
│   tt1.b = true
│   tt2.a = "abc"
└   tt2.b = true       
```

Contents of the generated code in test_type.jl:

```julia
using ProtoBuf
import ProtoBuf.meta

mutable struct TestType <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function TestType(; kwargs...)
        obj = new(meta(TestType), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
        end
        obj
    end
end #type TestType
const __meta_TestType = Ref{ProtoMeta}()
function meta(::Type{TestType})
    if !isassigned(__meta_TestType)
        __meta_TestType[] = target = ProtoMeta(TestType)
        allflds = Pair{Symbol,Union{Type,String}}[:a => AbstractString, :b => Bool]
        meta(target, TestType, allflds, [:a], ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
    end
    __meta_TestType[]
end
function Base.getproperty(obj::TestType, name::Symbol)
    if name === :a
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :b
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end
```

## Setting and Getting Fields

Types used as protocol buffer structures are regular Julia types and the Julia syntax to set and get fields can be used on them. The generated type constructor makes it easier to set large types with many fields by passing name value pairs during construction: `T(; name=val...)`.

Fields that are marked as optional may not be present in an instance of the struct that is read. Also, you may want to clear a set property from an instance. The following methods are exported to assist doing this:

- `propertynames(obj)` : Returns a list of property names possible
- `setproperty!(obj, fld::Symbol, v)` : Sets `obj.fld`.
- `getproperty(obj, fld::Symbol)` : Gets `obj.fld` if it has been set. Throws an error otherwise.
- `hasproperty(obj, fld::Symbol)` : Checks whether property `fld` has been set in `obj`.
- `clear(obj, fld::Symbol)` : clears property `fld` of `obj`.
- `clear(obj)` : Clears all properties of `obj`.

```julia
julia> using ProtoBuf

julia> mutable struct MyType <: ProtoType  # a Julia composite type
           ... # intval::Int
           ...
       end

julia> mutable struct OptType <: ProtoType # and another one to contain it
           ... #opt::MyType
           ...
       end

julia> iob = PipeBuffer();

julia> writeproto(iob, OptType(opt=MyType(intval=10)));

julia> readval = readproto(iob, OptType());

julia> hasproperty(readval, :opt)
true

julia> writeproto(iob, OptType());

julia> readval = readproto(iob, OptType());

julia> hasproperty(readval, :opt)
false
```

The `isinitialized(obj::Any)` method checks whether all mandatory fields are set. It is useful to check objects using this method before sending them. Method `writeproto` results in an exception if this condition is violated.

```julia
julia> using ProtoBuf

julia> import ProtoBuf.meta

julia> mutable struct TestType <: ProtoType
           ... # val::Any
           ...
       end

julia> mutable struct TestFilled <: ProtoType
           ... # fld1::TestType (mandatory)
           ... # fld2::TestType
           ...
       end

julia> tf = TestFilled();

julia> isinitialized(tf)      # false, since fld1 is not set
false

julia> tf.fld1 = TestType(fld1="");

julia> isinitialized(tf)      # true, even though fld2 is not set yet
true
```

## Equality &amp; Hash Value

It is possible for fields marked as optional to be in an &quot;unset&quot; state. Even bits type fields (`isbitstype(T) == true`) can be in this state though they may have valid contents. Such fields should then not be compared for equality or used for computing hash values. All ProtoBuf compatible types, by virtue of extending abstract `ProtoType` type, override `hash`, `isequal` and `==` methods to handle this. 

## Other Methods

- `copy!{T}(to::T, from::T)` : shallow copy of objects
- `isfilled(obj)` : same as `isinitialized`
- `lookup(en, val::Integer)` : lookup the name (symbol) corresponding to an enum value
- `enumstr(enumname, enumvalue::Int32)`: returns a string with the enum field name matching the value
- `which_oneof(obj, oneof::Symbol)`: returns a symbol indicating the name of the field in the `oneof` group that is filled

## Thread safety

Most of the book-keeping data for a protobuf struct is kept inside the struct instance. So that does not hinder thread safe usage. However struct instances themselves need to be locked if they are being read and written to from different threads, as is expected of any regular Julia struct.

Protobuf metadata for a struct (the information about fields and their properties as mentioned in the protobuf IDL definition) however is best initialized once and reused. It was not possible to generate code in such a way that it could be initialized when code is loaded and pre-compiled. This was because of the need to support nested and recursive struct references that protobuf allows - metadata for a struct could be defined only after the struct and all of its dependencies were defined. Metadata initialization had to be deferred to the first constructor call. But in order to reuse the metadata definition, it gets stored into a `Ref` that is set once. A process wide lock is used to make access to it thread safe. There is a small cost to be borne for that, and it should be negligible for most usages.

If an application wishes to eliminate that cost entirely, then the way to do it would be to call the constructors of all protobuf structs it wishes to use first and then switch the lock off by calling `ProtoBuf.enable_async_safety(false)`. Once all metadata definitiions have been initialized, this would allow them to be used without any further locking overhead. This can also be set to `false` for a single threaded synchronous application where it is known that no parallelism is possible.

