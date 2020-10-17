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

````
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
````

## Setting and Getting Fields

Types used as protocol buffer structures are regular Julia types and the Julia syntax to set and get fields can be used on them. The generated type constructor makes it easier to set large types with many fields by passing name value pairs during construction: `T(; name=val...)`.

Fields that are marked as optional may not be present in an instance of the struct that is read. Also, you may want to clear a set property from an instance. The following methods are exported to assist doing this:

- `propertynames(obj)` : Returns a list of property names possible
- `setproperty!(obj, fld::Symbol, v)` : Sets `obj.fld`.
- `getproperty(obj, fld::Symbol)` : Gets `obj.fld` if it has been set. Throws an error otherwise.
- `hasproperty(obj, fld::Symbol)` : Checks whether property `fld` has been set in `obj`.
- `clear(obj, fld::Symbol)` : clears property `fld` of `obj`.
- `clear(obj)` : Clears all properties of `obj`.

````
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
````

The `isinitialized(obj::Any)` method checks whether all mandatory fields are set. It is useful to check objects using this method before sending them. Method `writeproto` results in an exception if this condition is violated.

````
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
````

## Equality &amp; Hash Value
It is possible for fields marked as optional to be in an &quot;unset&quot; state. Even bits type fields (`isbitstype(T) == true`) can be in this state though they may have valid contents. Such fields should then not be compared for equality or used for computing hash values. All ProtoBuf compatible types, by virtue of extending abstract `ProtoType` type, override `hash`, `isequal` and `==` methods to handle this. 

## Other Methods
- `copy!{T}(to::T, from::T)` : shallow copy of objects
- `isfilled(obj)` : same as `isinitialized`
- `lookup(en, val::Integer)` : lookup the name (symbol) corresponding to an enum value
- `enumstr(enumname, enumvalue::Int32)`: returns a string with the enum field name matching the value
- `which_oneof(obj, oneof::Symbol)`: returns a symbol indicating the name of the field in the `oneof` group that is filled

