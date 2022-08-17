```@contents
Pages = ["reference.md"]
Depth = 3
```

```@meta
CurrentModule = ProtoBuf
```

# API Reference

### Code Generation

```@docs
protojl
```

### Encoding and Decoding

```@docs
encode(::AbstractProtoEncoder, ::T) where {T}
decode(::AbstractProtoDecoder, ::Type{T}) where {T}
```

### Metadata

```@docs
reserved_fields
extendable_field_numbers
oneof_field_types
field_numbers
default_values
```
