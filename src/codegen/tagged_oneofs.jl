abstract type TaggedOneOf end

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
    println(io, " <: TaggedOneOf")
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
        print(io, typename, "(::Val{", repr(Symbol(jl_fieldname(f))), "}, x)")
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
        print(io, "PB.unsafe_getproperty(x::", typename, ", ::Val{", repr(Symbol(jl_fieldname(f))), "})")
        println(io, " = Base.getfield(x, :", isbits_flag ? "bit" : "ptr", ")::", fieldtype)
    end

    println(io, "function PB.active_name(f::F, x::", typename, ") where {F}")
    println(io, "    tag = x.tag")
    for (i, f) in enumerate(f.fields)
        print(io, "    ")
        i > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", i, "); return f(Val(", repr(Symbol(jl_fieldname(f))), "))")
    end
    println(io, "    else   # unreachable")
    println(io, "    end")
    println(io, "end")

    println(io, "function PB.active_value(f::F, x::", typename, ") where {F}")
    println(io, "    tag = x.tag")
    for (i, f) in enumerate(f.fields)
        print(io, "    ")
        i > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", i, "); return f(PB.unsafe_getproperty(x, Val(", repr(Symbol(jl_fieldname(f))), ")))")
    end
    println(io, "    else   # unreachable")
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

function unsafe_getproperty end
function active_name end
function active_value end

active_value(x::TaggedOneOf) = active_value(identity, x)
active_name(x::TaggedOneOf) = active_name(identity, x)
(x::TaggedOneOf)(; kw...) = x(Val(only(kw)[1]), Val(only(kw)[2]))