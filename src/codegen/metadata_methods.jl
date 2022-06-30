function maybe_generate_deprecation(io, t::Union{MessageType,EnumType})
    if parse(Bool, get(t.options, "deprecated", "false"))
        name = safename(t)
        println(io, "Base.depwarn(\"`$name` is deprecated.\", ((Base.Core).Typeof($name)).name.mt.name)")
    end
end

function generate_reserved_fields_method(io, t::Union{MessageType})
    println(io, "reserved_fields(::Type{", safename(t), "}) = ", (names=t.reserved_names, numbers=t.reserved_nums))
end
function generate_reserved_fields_method(io, t::Union{EnumType})
    println(io, "reserved_fields(::Type{", safename(t), ".T}) = ", (names=t.reserved_names, numbers=t.reserved_nums))
end

function generate_extendable_field_numbers_method(io, t::Union{MessageType})
    println(io, "extendable_field_numbers(::Type{", safename(t), "}) = ", t.extensions)
end
function generate_extendable_field_numbers_method(io, t::Union{EnumType})
    println(io, "extendable_field_numbers(::Type{", safename(t), ".T}) = ", t.extensions)
end

function generate_oneof_fields_metadata_method(io, t::MessageType)
    println(io, "oneof_fields_metadata(::Type{", safename(t), "}) = nothing # TODO")
end