function _should_force_required(qualified_name, ctx::Context)
    isnothing(ctx.options.force_required) && return false
    force_required = get(ctx.options.force_required, ctx.proto_file_path, nothing)
    isnothing(force_required) && return false
    return qualified_name in force_required::Set{String}
end

function generate_struct_field(io, @nospecialize(field), ctx::Context, type_params)
    println(io, "    ", jl_fieldname(field)::String, "::", jl_typename(field, ctx)::String)
end

function generate_struct_field(io, field::FieldType{ReferencedType}, ctx::Context, type_params::TypeParams)
    field_name = jl_fieldname(field)
    type_name = _ref_type_or_concrete_stub_or_param(field.type, ctx, type_params)
    type_name = _maybe_union_or_vector_a_type_name(type_name, field, ctx)
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::GroupType, ctx::Context, type_params::TypeParams)
    field_name = jl_fieldname(field)
    type_name = _ref_type_or_concrete_stub_or_param(field.type, ctx, type_params)
    type_name = _maybe_union_or_vector_a_type_name(type_name, field, ctx)
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::FieldType{MapType}, ctx::Context, type_params)
    field_name = jl_fieldname(field)

    if field.type.valuetype isa ReferencedType
        value_type_name = _ref_type_or_concrete_stub_or_param(field.type.valuetype, ctx, type_params)
        _maybe_subtype = _needs_subtyping_in_containers(field.type.valuetype, ctx) ? "<:" : ""
        type_name = string("Dict{", jl_typename(field.type.keytype, ctx), ",", _maybe_subtype, value_type_name, "}")
    else
        type_name = jl_typename(field, ctx)
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::OneOfType, ctx::Context, type_params)
    field_name = jl_fieldname(field)
    type_param = get(type_params.oneofs, field.name, nothing)

    if !isnothing(type_param)
        type_name = type_param.param
    else
        type_name = _get_oneof_type_bound(field, ctx, type_params)
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct(io, t::MessageType, ctx::Context)
    struct_name = safename(t)
    if t.has_oneof_field && ctx.options.parametrize_oneofs
        type_params = get_type_params_for_non_cyclic(t, ctx)
        params_string = get_type_param_string(type_params)
        maybe_subtype = t.is_self_referential[] ?
            string(" <: ", abstract_type_name(t.name)) :
            ctx.options.common_abstract_type ?
                " <: AbstractProtoBufMessage" :
                ""
    else
        type_params = EMPTY_TYPE_PARAMS
        params_string = ""
        maybe_subtype = ctx.options.common_abstract_type ?
            " <: AbstractProtoBufMessage" :
            ""
    end
    print(io, "struct ", struct_name, params_string, maybe_subtype)
    # new line if there are fields, otherwise ensure that we have space before `end`
    length(t.fields) > 0 ? println(io) : print(io, ' ')
    for field in t.fields
        generate_struct_field(io, field, ctx, type_params)
    end
    println(io, "end")
end

codegen(t::AbstractProtoType, ctx::Context) = codegen(stdout, t, ctx::Context)

function codegen(io, t::MessageType, ctx::Context)
    generate_struct(io, t, ctx)
    maybe_generate_kwarg_constructor_method(io, t, ctx)
    maybe_generate_deprecation(io, t)
    maybe_generate_reserved_fields_method(io, t )
    maybe_generate_extendable_field_numbers_method(io, t)
    maybe_generate_oneof_field_types_method(io, t, ctx)
    maybe_generate_default_values_method(io, t, ctx)
    maybe_generate_field_numbers_method(io, t)
    println(io)
    generate_decode_method(io, t, ctx)
    println(io)
    generate_encode_method(io, t, ctx)
    generate__encoded_size_method(io, t, ctx)
end
# If a MessageType is not topologically sort-able, we forward-declare a "stub" version of it.
# This stub is a struct that has a type param for each of its type dependencies, that were also
# not topologically sort-able. Each non-topologically sort-able type also has a custom abstract
# type defined for it, which is used as a type bound for the type param of the stub struct.
# Each stub can refer to itself and all previous stubs, which allows us to break the dependency
# cycles. After we're done with defining all the stubs, we generate type aliases that point to the
# concretized stub definitions (i.e. definitions where all the type params are provided using the
# the stubs). E.g.:
#=
```proto
message A { B b = 1; }
message B { A a = 1; }
```
would generate the following types and aliases:
```julia
abstract type var"##Abstract#A" end
abstract type var"##Abstract#B" end

struct var"##Stub#A"{T1<:var"##Abstract#B"} <: var"##Abstract#A"
    b::T1
end
struct var"##Stub#B" <: var"##Abstract#B"
    a::var"##Stub#A"{var"##Stub#B"}
end
const A = var"##Stub#A"{var"##Stub#B"} # <- This is fully concrete type
const B = var"##Stub#B"                # <- This is fully concrete type
```
=#
function codegen_cylic_stub(io, t::MessageType, ctx::Context)
    @assert t.name in keys(ctx._types_and_oneofs_requiring_type_params)
    # After we're done with this struct, all the subsequent definitions can use it
    # so we pop it from the list of cyclic definitions.
    abstract_base_name = pop!(ctx._remaining_cyclic_defs, t.name, "")
    type_params = get_type_params_for_cyclic(t, ctx)
    params_string = get_type_param_string(type_params)

    print(io, "struct ", stub_type_name(t.name), length(t.fields) > 0 ? params_string : " ", _maybe_subtype(abstract_base_name, ctx.options))
    # new line if there are fields, otherwise ensure that we have space before `end`
    length(t.fields) > 0 ? println(io) : print(io, ' ')
    for field in t.fields
        generate_struct_field(io, field, ctx, type_params)
    end
    println(io, "end")
end
# After all the stubs are defined (see above), we generate a type alias to the concretized version
# of the corresponding stub and then we proceed defining all the metadata and codec methods
# as we do for non-cyclic types.
function codegen_cylic_rest(io, t::MessageType, ctx::Context)
    _generate_struct_alias(io, t, ctx)
    # We must define the constructor after the const is set, otherwise we get an error
    maybe_generate_constructor_for_type_alias(io, t, ctx)
    maybe_generate_kwarg_constructor_method(io, t, ctx)
    maybe_generate_deprecation(io, t)
    maybe_generate_reserved_fields_method(io, t )
    maybe_generate_extendable_field_numbers_method(io, t)
    maybe_generate_oneof_field_types_method(io, t, ctx)
    maybe_generate_default_values_method(io, t, ctx)
    maybe_generate_field_numbers_method(io, t)
    println(io)
    generate_decode_method(io, t, ctx)
    println(io)
    generate_encode_method(io, t, ctx)
    generate__encoded_size_method(io, t, ctx)
end

function codegen(io, t::EnumType, ::Context)
    name = safename(t)
    print(io, "@enumx ", name)
    for (k, n) in zip(t.element_names, t.element_values)
        print(io, " $k=$n")
    end
    println(io)
    maybe_generate_deprecation(io, t)
    maybe_generate_reserved_fields_method(io, t)
end

function codegen(io, t::ServiceType, ::Context)
    println(io, "# TODO: SERVICE")
    println(io, "#    ", safename(t))
end

function translate(path::String, rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile}, options)
    open(path, "w") do io
        translate(io, rp, file_map, options)
    end
end

function Parsers.check_name_collisions(p::ProtoFile, file_map::Dict)
    for import_path in import_paths(p)
        i = file_map[import_path].proto_file
        Parsers.check_name_collisions(
            namespace(i), p.definitions, i.filepath, p.filepath
        )
    end
end

translate(rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile}, options) = translate(stdout, rp, file_map, options)
function translate(io, rp::ResolvedProtoFile, file_map::Dict{String,ResolvedProtoFile}, options)
    p = rp.proto_file
    ncyclic = length(p.cyclic_definitions)
    Parsers.check_name_collisions(p, file_map)
    println(io, "# Autogenerated using ProtoBuf.jl v$(PACKAGE_VERSION) on $(Dates.now())")
    println(io, "# original file: ", p.filepath," (proto", p.preamble.isproto3 ? '3' : '2', " syntax)")
    println(io)

    # TODO: cleanup here, we probably don't need a reference to rp.transitive_imports in ctx?
    ctx = Context(
        p,
        rp.import_path,
        file_map,
        types_needing_params(@view(p.sorted_definitions[end-ncyclic+1:end]), p, options),
        copy(p.cyclic_definitions),
        Ref{String}(),
        rp.transitive_imports,
        options,
    )

    if !is_namespaced(p)
        options.always_use_modules && println(io, "module $(replace(proto_script_name(p), ".jl" => ""))")
        options.always_use_modules && println(io)
        # if current file is not namespaced, it will not live in a module
        # and will need to import its dependencies directly.
        for path in import_paths(p)
            dependency = file_map[path]
            if !is_namespaced(dependency)
                # if the dependency is also not namespaced, we can just include it
                println(io, "include(", repr(proto_script_name(dependency)), ")")
                options.always_use_modules && println(io, "import $(replace(proto_script_name(dependency), ".jl" => ""))")
            else
                # otherwise we need to import it trough a module
                import_pkg_name = namespaced_top_import(dependency)
                println(io, "include(", repr(namespaced_top_include(dependency)), ")")
                println(io, "import $(import_pkg_name)")
            end
        end
    end # Otherwise all includes will happen in the enclosing module
    println(io, "import ProtoBuf as PB")
    options.common_abstract_type && println(io, "using ProtoBuf: AbstractProtoBufMessage")
    println(io, "using ProtoBuf: OneOf")
    println(io, "using ProtoBuf.EnumX: @enumx")
    if (is_namespaced(p) || options.always_use_modules) && !isempty(p.definitions)
        len = 93
        for name in Iterators.map(_safename, p.sorted_definitions)
            if len + length(name) + 2 >= 92
                print(io, "\nexport ")
                len = 7
            else
                print(io, ", ")
                len += 2
            end
            print(io, name)
            len += length(name)
        end
    end

    println(io)

    if options.parametrize_oneofs
        for name in @view(p.sorted_definitions[1:end-ncyclic])
            def = p.definitions[name]
            if def isa MessageType && def.has_oneof_field && def.is_self_referential[]
                println(io, "abstract type ", abstract_type_name(name), options.common_abstract_type ? " <: AbstractProtoBufMessage" : "", " end")
            end
        end
    end
    for name in p.cyclic_definitions
        println(io, "abstract type ", abstract_type_name(name), options.common_abstract_type ? " <: AbstractProtoBufMessage" : "", " end")
    end

    println(io)

    for def_name in @view(p.sorted_definitions[1:end-ncyclic])
        println(io)
        ctx._toplevel_raw_name[] = def_name
        codegen(io, p.definitions[def_name], ctx)
    end

    ncyclic > 0 && print(io, "\n# Stub definitions for cyclic types")
    for def_name in @view(p.sorted_definitions[end-ncyclic+1:end])
        println(io)
        ctx._toplevel_raw_name[] = def_name
        codegen_cylic_stub(io, p.definitions[def_name], ctx)
    end

    for def_name in @view(p.sorted_definitions[end-ncyclic+1:end])
        println(io)
        ctx._toplevel_raw_name[] = def_name
        codegen_cylic_rest(io, p.definitions[def_name], ctx)
    end

    options.always_use_modules && !is_namespaced(p) && println(io, "end # module")
end
