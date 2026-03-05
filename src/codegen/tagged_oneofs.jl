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

_tagged_getfield(info, ident) = string("Base.getfield(", ident,", :", info.inline ? "bit" : "ptr", ")::", info.type)

function _generate_tagged_oneof(io, t::MessageType, f::OneOfType, ctx::Context)
    field_infos = _tagged_oneof_field_infos(f.fields, ctx)
    typename = string("var\"", t.name, ".", replace(titlecase(f.name), "_"=>""), "\"")
    seen = Set{String}()

    print(io, "struct ", typename)
    if t.is_self_referential[] # || appears_in_cycle
        print(io, "{T<:", abstract_type_name(t.name), "}")
    end
    println(io, " <: PB.TaggedOneOf")
    println(io, "    tag::UInt8")

    print(io, "    bit::Union{Nothing")
    for info in field_infos
        info.inline || continue
        get!(seen.dict, info.type) do
            print(io, ",")
            print(io, info.type)
            nothing
        end
    end
    println(io, "}")

    empty!(seen)
    print(io, "    ptr::Union{Nothing")
    for info in field_infos
        info.inline && continue
        get!(seen.dict, info.type) do
            print(io, ",")
            print(io, info.type)
            nothing
        end
    end
    println(io, "}")
    println(io, "end")

    for info in field_infos
        print(io, typename, "(::Val{:", info.name, "}, x)")
        print(io, " = ", typename, "(UInt8(", info.idx, "), ")
        if info.inline
            println(io, "convert(", info.type, ", x), nothing)")
        else
            println(io, "nothing, convert(", info.type, ", x))")
        end
    end

    for info in field_infos
        print(io, "PB.unsafe_getproperty(x::", typename, ", ::Val{:", info.name, "})")
        println(io, " = ", _tagged_getfield(info, "x"))
    end

    print(io, "PB.field_to_tag(::Type{", typename, "}) = (;")
    for info in field_infos
        info.idx > 1 && print(io, ", ")
        print(io, info.name, " = UInt8(", info.idx,")")
    end
    println(io, ")")

    println(io, "function PB.active_name(f::F, x::", typename, ") where {F}")
    println(io, "    tag = getfield(x, :tag)")
    for info in field_infos
        print(io, "    ")
        info.idx > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", info.idx, "); return f(Val(:", info.name, "))")
    end
    println(io, "    else   PB.throw_bad_tag(", typename,", tag)")
    println(io, "    end")
    println(io, "end")

    println(io, "function PB.active_value(f::F, x::", typename, ") where {F}")
    println(io, "    tag = getfield(x, :tag)")
    for info in field_infos
        print(io, "    ")
        info.idx > 1 ? print(io, "elseif") : print(io, "if    ")
        println(io, " tag == UInt8(", info.idx, "); return f(", _tagged_getfield(info, "x"), ")")
    end
    println(io, "    else   PB.throw_bad_tag(", typename,", tag)")
    println(io, "    end")
    println(io, "end")
    return nothing
end

function _tagged_oneof_field_infos(fields, ctx)
    field_infos = @NamedTuple{idx::Int, name::String, type::String, inline::Bool}[]
    idx = 1
    for f in fields
        tinfo = query_typeinfo!(f, ctx)
        push!(field_infos, (; idx, name=jl_fieldname(f), type=jl_typename(f, ctx), inline=tinfo.isbits && tinfo.size <= 16))
        idx += 1
    end
    return field_infos
end

