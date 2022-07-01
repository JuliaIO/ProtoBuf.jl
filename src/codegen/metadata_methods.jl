function maybe_generate_deprecation(io, t::Union{MessageType,EnumType})
    if parse(Bool, get(t.options, "deprecated", "false"))
        name = safename(t)
        println(io, "Base.depwarn(\"`$name` is deprecated.\", ((Base.Core).Typeof($name)).name.mt.name)")
    end
end

function generate_reserved_fields_method(io, t::Union{MessageType})
    println(io, "PB.reserved_fields(::Type{", safename(t), "}) = ", (names=t.reserved_names, numbers=t.reserved_nums))
end

function generate_extendable_field_numbers_method(io, t::Union{MessageType})
    println(io, "PB.extendable_field_numbers(::Type{", safename(t), "}) = ", t.extensions)
end

_get_fields(t::AbstractProtoType) = [t]
_get_fields(::EnumType) = []
_get_fields(t::Union{OneOfType,MessageType}) = Iterators.flatten(Iterators.map(_get_fields, t.fields))

function generate_oneof_fields_metadata_method(io, t::MessageType, ctx)
    types = join(
        (
            (string(jl_fieldname(f), " = NamedTuple{(:", join((jl_fieldname(o) for o in f.fields), ",:"), "), Tuple{", join((jl_typename(o, ctx) for o in f.fields), ","),"}}"))
            for f
            in t.fields
            if isa(f, OneOfType)
        ),
        ",\n    "
    )
    if isempty(types)
        types = "(;)"
    else
        types = "(;\n    $(types)\n)"
    end
    println(io, "PB.oneof_fields_metadata(::Type{", safename(t), "}) = $(types)")
end

function generate_field_numbers_method(io, t::Union{MessageType})
    field_numbers = join((string(jl_fieldname(f), " = ",  f.number) for f in _get_fields(t)), ", ")
    println(io, "PB.field_numbers(::Type{", safename(t), "}) = (;$(field_numbers))", )
end

function generate_default_values_method(io, t::Union{MessageType}, ctx)
    default_values = join((string(jl_fieldname(f), " = ",  jl_default_value(f, ctx)) for f in _get_fields(t)), ", ")
    println(io, "PB.default_values(::Type{", safename(t), "}) = (;$(default_values))", )
end