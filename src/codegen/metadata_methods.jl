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

function generate_oneof_fields_metadata_method(io, t::MessageType, ctx)
    oneofs = join(
        ((string(safename(f), " = (;", join(
            ("$(safename(o)) = $(jl_default_value(o, ctx))" for o in f.fields),
            ", ",
        ), ')'))
        for f in t.fields
        if isa(f, OneOfType)),
        ",\n    ",
    )
    if isempty(oneofs)
        oneofs = "(;)"
    else
        oneofs = "(;\n    $(oneofs)\n)"
    end
    println(io, "PB.oneof_fields_metadata(::Type{", safename(t), "}) = $(oneofs)")
end