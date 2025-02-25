function maybe_generate_deprecation(io, t::Union{MessageType, EnumType, ServiceType})
    if parse(Bool, get(t.options, "deprecated", "false"))
        name = safename(t)
        println(io, "Base.depwarn(\"`$(escape_string(name))` is deprecated.\", ((Base.Core).Typeof($name)).name.mt.name)")
    end
end

function maybe_generate_reserved_fields_method(io, t::MessageType)
    isempty(t.reserved_names) && isempty(t.reserved_nums) && return
    println(io, "PB.reserved_fields(::Type{", safename(t), "}) = (names = ", string(t.reserved_names), ", numbers = Union{Int,UnitRange{Int}}[", join(t.reserved_nums, ", "), "])")
end

function maybe_generate_reserved_fields_method(io, t::EnumType)
    isempty(t.reserved_names) && isempty(t.reserved_nums) && return
    println(io, "PB.reserved_fields(::Type{", safename(t), ".T}) = (names = ", string(t.reserved_names), ", numbers = Union{Int,UnitRange{Int}}[", join(t.reserved_nums, ", "), "])")
end

function maybe_generate_extendable_field_numbers_method(io, t::MessageType)
    n = length(t.extensions)
    n == 0 && return
    print(io, "PB.extendable_field_numbers(::Type{", safename(t), "}) = Union{Int,UnitRange{Int}}[")
    print(io, string(t.extensions[1]))
    n == 1 && (println(io, "]"); return)
    for i in 2:n
        print(io, ", ")
        print(io, string(t.extensions[i]))
    end
    println(io, ']')
end

_get_fields(t::AbstractProtoType) = [t]
_get_fields(t::Union{OneOfType,MessageType}) = Iterators.flatten(Iterators.map(_get_fields, t.fields))

function maybe_generate_oneof_field_types_method(io, t::MessageType, ctx)
    oneofs = filter(x->isa(x, OneOfType), t.fields)
    n = length(oneofs)
    n == 0 && return
    print(io, "PB.oneof_field_types(::Type{", safename(t), "}) = (;")
    for oneof in oneofs
        n = length(oneof.fields)
        print(io, "\n    ", jl_fieldname(oneof), " = (;")
        for (i, field) in enumerate(oneof.fields)
            print(io, jl_fieldname(field), "=", jl_typename(field, ctx))
            i < n && print(io, ", ")
        end
        print(io, "),")
    end
    println(io, "\n)")
end

function _field_numbers_per_field(io, f::Union{FieldType,GroupType})
    print(io, jl_fieldname(f), " = ", string(f.number))
end
function _field_numbers_per_field(io, f::OneOfType)
    n = length(f.fields)
    for (i, field) in enumerate(f.fields)
        _field_numbers_per_field(io, field)
        i < n && print(io, ", ")
    end
end
function maybe_generate_field_numbers_method(io, t::MessageType)
    n = length(t.fields)
    n == 0 && return nothing
    print(io, "PB.field_numbers(::Type{", safename(t), "}) = (;")
    for (i, field) in enumerate(t.fields)
        _field_numbers_per_field(io, field)
        i < n && print(io, ", ")
    end
    println(io,  ')')
end

function _default_values_per_leaf_field(io, f::Union{FieldType,GroupType}, ctx::Context)
    @nospecialize
    val = jl_default_value(f, ctx)
    print(io, jl_fieldname(f), !isnothing(val) ? string(" = ", val) : "")
end
function _default_values_per_leaf_field(io, f::OneOfType, ctx::Context)
    n = length(f.fields)
    for (i, field) in enumerate(f.fields)
        _default_values_per_leaf_field(io, field, ctx)
        i < n && print(io, ", ")
    end
end
function maybe_generate_default_values_method(io, t::MessageType, ctx::Context)
    n = length(t.fields)
    n == 0 && return nothing
    print(io, "PB.default_values(::Type{", safename(t), "}) = (;")
    for (i, field) in enumerate(t.fields)
        _default_values_per_leaf_field(io, field, ctx)
        i < n && print(io, ", ")
    end
    println(io,  ')')
end

function maybe_generate_kwarg_constructor_method(io, t::MessageType, ctx::Context)
    n = length(t.fields)
    (!ctx.options.add_kwarg_constructors || n == 0) && return
    type_name = safename(t)
    print(io, "$(type_name)(;")
    for (i, field) in enumerate(t.fields)
        val = jl_default_value(field, ctx)
        print(io, jl_fieldname(field), !isnothing(val) ? string(" = ", val) : "")
        i < n && print(io, ", ")
    end
    print(io, ") = ")
    _maybe_parametrize_constructor_to_handle_oneofs(io, t, ctx)
    print(io, "(")
    for (i, field) in enumerate(t.fields)
        print(io, jl_fieldname(field))
        i < n && print(io, ", ")
    end
    println(io, ')')
end

function maybe_generate_regular_constructor_for_type_alias(io, t::MessageType, ctx::Context)
    !(ctx.options.parametrize_oneofs && t.has_oneof_field) && return
    n = length(t.fields)
    type_name = safename(t)
    print(io, "$(type_name)(")
    for (i, field) in enumerate(t.fields)
        print(io, jl_fieldname(field))
        i < n && print(io, ", ")
    end
    print(io, ") = ")
    _maybe_parametrize_constructor_to_handle_oneofs(io, t, ctx)
    print(io, "(")

    for (i, field) in enumerate(t.fields)
        print(io, jl_fieldname(field))
        i < n && print(io, ", ")
    end
    println(io, ')')
end
