function maybe_generate_deprecation(io, t::Union{MessageType,EnumType})
    if parse(Bool, get(t.options, "deprecated", "false"))
        name = safename(t)
        println(io, "Base.depwarn(\"`$name` is deprecated.\", ((Base.Core).Typeof($name)).name.mt.name)")
    end
end

function maybe_generate_reserved_fields_method(io, t::MessageType)
    isempty(t.reserved_names) && isempty(t.reserved_nums) && return
    println(io, "PB.reserved_fields(::Type{", safename(t), "}) = ", (names=t.reserved_names, numbers=t.reserved_nums))
end

function maybe_generate_extendable_field_numbers_method(io, t::MessageType)
    isempty(t.extensions) && return
    println(io, "PB.extendable_field_numbers(::Type{", safename(t), "}) = ", t.extensions)
end

_get_fields(t::AbstractProtoType) = [t]
_get_fields(t::Union{OneOfType,MessageType}) = Iterators.flatten(Iterators.map(_get_fields, t.fields))

function maybe_generate_oneof_field_types_method(io, t::MessageType, ctx)
    types = join(
        (
            string(jl_fieldname(f), " = (;", join((string(jl_fieldname(o), "=", jl_typename(o, ctx)) for o in f.fields), ", "), ")")
            for f
            in t.fields
            if isa(f, OneOfType)
        ),
        ",\n    "
    )
    if isempty(types)
        return
    else
        types = "(;\n    $(types)\n)"
    end
    println(io, "PB.oneof_field_types(::Type{", safename(t), "}) = $(types)")
end

function maybe_generate_field_numbers_method(io, t::MessageType)
    isempty(t.fields) && return
    field_numbers = join((string(jl_fieldname(f), " = ",  f.number) for f in _get_fields(t)), ", ")
    println(io, "PB.field_numbers(::Type{", safename(t), "}) = (;$(field_numbers))", )
end

function maybe_generate_default_values_method(io, t::MessageType, ctx)
    isempty(t.fields) && return
    default_values = join((string(jl_fieldname(f), " = ",  @something(jl_default_value(f, ctx), f)) for f in _get_fields(t)), ", ")
    println(io, "PB.default_values(::Type{", safename(t), "}) = (;$(default_values))", )
end

function maybe_generate_kwarg_constructor_method(io, t::MessageType, ctx)
    (!ctx.options.add_kwarg_constructors || isempty(t.fields)) && return
    type_name = safename(t)
    default_values = join(
        Iterators.map(t.fields) do f
            default_value = jl_default_value(f, ctx)
            if isnothing(default_value)
                jl_fieldname(f)
            else
                string(jl_fieldname(f), " = ", jl_default_value(f, ctx))
            end
        end,
        ", "
    )
    println(io, "$(type_name)(;$(default_values)) = $(type_name)($(join(Iterators.map(jl_fieldname, t.fields), ", ")))")
end