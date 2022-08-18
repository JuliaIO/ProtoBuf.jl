function _should_force_required(qualified_name, ctx::Context)
    isnothing(ctx.options.force_required) && return false
    force_required = get(ctx.options.force_required, ctx.proto_file_path, Set{String}())
    return qualified_name in force_required
end

function generate_struct_field(io, @nospecialize(field), ctx::Context, type_params)
    println(io, "    ", jl_fieldname(field)::String, "::", jl_typename(field, ctx)::String)
end

function generate_struct_field(io, field::FieldType{ReferencedType}, ctx::Context, type_params)
    field_name = jl_fieldname(field)
    type_name = jl_typename(field, ctx)
    struct_name = ctx._toplevel_name[]
    # When a field type is self-referential, we'll use Nothing to signal
    # the bottom of the recursion. Note that we don't have to do this
    # for repeated (`Vector{...}`) types; at this point `type_name`
    # is already a vector if the field was repeated.
    type_param = get(type_params, field.name, nothing)
    if struct_name == type_name
        type_name = string("Union{Nothing,", type_name,"}")
    elseif !isnothing(type_param)
        type_name = _is_repeated_field(field) ? string("Vector{", type_param.param, '}') : type_param.param
    elseif field.label == Parsers.OPTIONAL || field.label == Parsers.DEFAULT
        should_force_required = _should_force_required(string(struct_name, ".", field.name), ctx)
        if !should_force_required && _is_message(field.type, ctx)
            type_name = string("Union{Nothing,", type_name,"}")
        end
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::GroupType, ctx::Context, type_params)
    field_name = jl_fieldname(field)
    type_name = jl_typename(field, ctx)
    struct_name = ctx._toplevel_name[]
    # When a field type is self-referential, we'll use Nothing to signal
    # the bottom of the recursion. Note that we don't have to do this
    # for repeated (`Vector{...}`) types; at this point `type_name`
    # is already a vector if the field was repeated.
    type_param = get(type_params, field.name, nothing)
    if struct_name == type_name
        type_name = string("Union{Nothing,", type_name,"}")
    elseif !isnothing(type_param)
        type_name = type_param.param
    elseif field.label == Parsers.OPTIONAL || field.label == Parsers.DEFAULT
        should_force_required = _should_force_required(string(struct_name, ".", field.name), ctx)
        if !should_force_required
            type_name = string("Union{Nothing,", type_name,"}")
        end
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::FieldType{MapType}, ctx::Context, type_params)
    field_name = jl_fieldname(field)
    type_name = jl_typename(field, ctx)
    struct_name = ctx._toplevel_name[]

    if field.type.valuetype isa ReferencedType
        valuetype_name = field.type.valuetype.name
        type_param = get(type_params, field.name, nothing)
        if !isnothing(type_param) && valuetype_name != struct_name
            type_name = string("Dict{", jl_typename(field.type.keytype, ctx), ',', type_param.param, '}')
        end
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct_field(io, field::OneOfType, ctx::Context, type_params)
    field_name = jl_fieldname(field)
    type_param = get(type_params, field.name, nothing)
    if !isnothing(type_param)
        type_name = type_param.param
    else
        type_name = _get_type_bound(field, ctx)
    end
    println(io, "    ", field_name, "::", type_name)
end

function generate_struct(io, t::MessageType, ctx::Context)
    struct_name = safename(t)
    # After we're done with this struct, all the subsequent definitions can use it
    # so we pop it from the list of cyclic definitions.
    abstract_base_name = pop!(ctx._curr_cyclic_defs, t.name, "")
    type_params = get_type_params(t, ctx)
    params_string = get_type_param_string(type_params)

    print(io, "struct ", struct_name, length(t.fields) > 0 ? params_string : ' ', _maybe_subtype(abstract_base_name))
    length(t.fields) > 0 && println(io)
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
    Parsers.check_name_collisions(p, file_map)
    println(io, "# Autogenerated using ProtoBuf.jl v$(PACKAGE_VERSION) on $(Dates.now())")
    println(io, "# original file: ", p.filepath," (proto", p.preamble.isproto3 ? '3' : '2', " syntax)")
    println(io)

    # TODO: cleanup here, we probably don't need a reference to rp.transitive_imports in ctx?
    ctx = Context(p, rp.import_path, file_map, copy(p.cyclic_definitions), Ref{String}(), rp.transitive_imports, options)
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
    println(io, "using ProtoBuf: OneOf")
    println(io, "using EnumX: @enumx")
    if (is_namespaced(p) || options.always_use_modules) && !isempty(p.definitions)
        println(io)
        n = length(p.sorted_definitions)
        print(io, "export ")
        for (i, def) in enumerate(p.sorted_definitions)
            print(io, _safename(def))
            i < n && print(io, ", ")
        end
    end
    !isempty(p.cyclic_definitions) && println(io, "\n# Abstract types to help resolve mutually recursive definitions")
    for name in p.cyclic_definitions
        println(io, "abstract type ", abstract_type_name(name), " end")
    end
    println(io)
    for def_name in p.sorted_definitions
        println(io)
        ctx._toplevel_name[] = def_name
        codegen(io, p.definitions[def_name], ctx)
    end
    options.always_use_modules && !is_namespaced(p) && println(io, "end # module")
end