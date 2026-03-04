abstract type TaggedOneOf end

function field_to_tag end
function unsafe_getproperty end
function active_name end
function active_value end

@noinline throw_not_set(::Type{T}, f) where {T<:TaggedOneOf} = error("Field `$(f)` is not active for type `$(T)`")
@noinline throw_bad_tag(::Type{T}, t) where {T<:TaggedOneOf} = error("Tag `$(f)` is not valid for type `$(T)`")
@inline Base.propertynames(::Type{T}) where {T<:TaggedOneOf} = keys(field_to_tag(T))
@inline Base.getproperty(x::T, sym::Symbol) where {T<:TaggedOneOf} = (field_to_tag(T)[sym])::UInt8 != getfield(x, :tag)::UInt8 ? throw_not_set(T, sym) : unsafe_getproperty(x, Val(sym))
Base.show(io::IO, x::T) where {T<:TaggedOneOf} = println(io, string(T), "(", active_name(x), " = ", repr(active_value(x)), ")")

_name_from_val(::Val{name}) where {name} = name
@inline active_value(x::TaggedOneOf) = active_value(identity, x)
@inline active_name(x::TaggedOneOf) = active_name(_name_from_val, x)
(::Type{T})(; kw...) where {T<:TaggedOneOf} = T(Val(only(kw)[1]), only(kw)[2])
@inline tag(x::T) where {T<:TaggedOneOf} = getfield(x, :tag)::UInt8

function maybe_generate_tagged_oneofs(io, t::MessageType, ctx::Context)
    !(t.has_oneof_field && ctx.options.tagged_oneofs) && return nothing
    for field in t.fields
        field isa OneOfType || continue
        _generate_tagged_oneof(io, t, field::OneOfType, ctx)
        println(io)
    end
    return nothing
end

function _generate_tagged_oneof(io, t::MessageType, f::OneOfType, ctx::Context)
    (; bitstypes, ptrstypes, isbits_flags) = _split_oneof_types(f.fields, ctx)

    typename = string("var\"", t.name, ".", replace(titlecase(f.name), "_"=>""), "\"")
    print(io, "struct ", typename)
    if t.is_self_referential[] # || appears_in_cycle
        print(io, "{T<:", abstract_type_name(t.name), "}")
    end
    println(io, " <: PB.TaggedOneOf")
    println(io, "    tag::UInt8")

    print(io, "    bit::Union{Nothing")
    for (name, type) in bitstypes
        print(io, ", ")
        print(io, type)
    end
    println(io, "}")

    print(io, "    ptr::Union{Nothing")
    for (name, type) in ptrstypes
        print(io, ", ")
        print(io, type)
    end
    println(io, "}")
    println(io, "end")

    for (i, (isbits_flag, f)) in enumerate(zip(isbits_flags, f.fields))
        fieldname = jl_fieldname(f)
        fieldtype = jl_typename(f, ctx)
        print(io, typename, "(::Val{", repr(Symbol(fieldname)), "}, x)")
        print(io, " = ", typename, "(UInt8(", i, "), ")
        if isbits_flag
            println(io, "convert(", fieldtype, ", x), nothing)")
        else
            println(io, "nothing, convert(", fieldtype, ", x))")
        end
    end

    for (isbits_flag, f) in zip(isbits_flags, f.fields)
        fieldname = jl_fieldname(f)
        fieldtype = jl_typename(f, ctx)
        print(io, "PB.unsafe_getproperty(x::", typename, ", ::Val{", repr(Symbol(fieldname)), "})")
        println(io, " = Base.getfield(x, :", isbits_flag ? "bit" : "ptr", ")::", fieldtype)
    end

    print(io, "PB.field_to_tag(::Type{", typename, "}) = (;")
    for (i, f) in enumerate(f.fields)
        fieldname = jl_fieldname(f)
        i > 1 && print(io, ", ")
        print(io, fieldname, " = UInt8(", i,")")
    end
    println(io, ")")

    println(io, "function PB.active_name(f::F, x::", typename, ") where {F}")
    println(io, "    tag = getfield(x, :tag)")
    for (i, f) in enumerate(f.fields)
        print(io, "    ")
        i > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", i, "); return f(Val(", repr(Symbol(jl_fieldname(f))), "))")
    end
    println(io, "    else   PB.throw_bad_tag(", typename,", tag)")
    println(io, "    end")
    println(io, "end")

    println(io, "function PB.active_value(f::F, x::", typename, ") where {F}")
    println(io, "    tag = getfield(x, :tag)")
    for (i, f) in enumerate(f.fields)
        print(io, "    ")
        i > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", i, "); return f(PB.unsafe_getproperty(x, Val(", repr(Symbol(jl_fieldname(f))), ")))")
    end
    println(io, "    else   PB.throw_bad_tag(", typename,", tag)")
    println(io, "    end")
    println(io, "end")
    return nothing
end

function _split_oneof_types(fields, ctx)
    bitstypes = NTuple{2,String}[]
    ptrstypes = NTuple{2,String}[]
    isbits_flags = Bool[]

    for f in fields
        tinfo = query_typeinfo!(f, ctx)
        if tinfo.isbits && tinfo.size <= 16
            push!(bitstypes, (jl_fieldname(f), jl_typename(f, ctx)))
            push!(isbits_flags, true)
        else
            push!(ptrstypes, (jl_fieldname(f), jl_typename(f, ctx)))
            push!(isbits_flags, false)
        end
    end
    return (; bitstypes, ptrstypes, isbits_flags)
end

