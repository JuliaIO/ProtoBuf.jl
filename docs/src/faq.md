# Frequently Asked Questions

### How do I work with `.textproto` files?

`.textproto` files are not currently supported by this package. You can, however, use the `protoc` compiler (e.g. via the `protoc_jll` package) to translate between `text` and `binary` formats using the `--encode` and `--decode` commands.

### How do I work with `oneof` fields?

A `oneof` field represents a set of possible fields (*members*) of which only one can be set at a time. Individual members of a `oneof` field cannot be distinguished by their `type` alone, one needs to know the respective member field `name` as well. In this package, we use a `OneOf{T}` type to represent the chosen member, is only has two fields: a `value::T` and a `name::Symbol`. Dereferencing a `OneOf` instance will return the value.

Because Protocol Buffers stress that one needs to handle situations where message definitions evolve and when data transfer can fail, we need to have a *default value* for all fields, `oneof` fields included. Given multiple members, there is no clear default value to choose, so we represent the absence of a `OneOf` instance with `nothing`. This means that, by default, all `oneof` fields are presented as `Union{Nothing,OneOf{...}}` in Julia. These unions can sometimes be tricky to reason about for the Julia compiler so we recommend the following when working with `OneOf` types:

* Try to manually split the `Union`, i.e. instead of

```julia
if !isnothing(my_message.one_of_field)
elseif my_message.one_of_field === :option1
    do_someting(my_message.one_of_field[])
elseif my_message.one_of_field === :option2
    do_someting_else(my_message.one_of_field[])
# ...
end
```

do this:

```julia
one_of_field = my_message.one_of_field
if !isnothing(one_of_field)
elseif one_of_field === :option1
    do_someting(one_of_field[])
elseif one_of_field === :option2
    do_someting_else(one_of_field[])
# ...
end
```
* When you *know* that the `oneof` field is guaranteed to be received when decoding, you can tell the `protojl` not to use a `Union` by providing a `force_requires` keyword argument with `Dict("my_proto_file.proto" => Set("MyMessage.one_of_field"))`.

* You can parametrize your structs on the type of `oneof`s by providing a `parametrize_oneofs=true` keyword argument to `protojl`.

### How complete is this package?

The package should have fairly complete support for both `proto2` and `proto3` syntaxes with the following exceptions:

* Services and RPC are not yet supported
* Extensions are not yet supported
* Text Format is not yet supported (but see [How do I work with `.textproto` files?](@ref))

Future development will focus on Services and RPC with an overall goal of getting a new, native Julia `gRPC` implementation.
