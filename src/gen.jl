module Gen

using ..ProtoBuf
using ..ProtoBuf.GoogleProtoBuf
using ..ProtoBuf.GoogleProtoBufCompiler
using Logging

import ProtoBuf: meta, DEF_REQ, DEF_FNUM, DEF_VAL, DEF_PACK

export gen

const JTYPES              = [Float64, Float32, Int64, UInt64, Int32, UInt64,  UInt32,  Bool,  AbstractString, Any,     Any,     Vector{UInt8}, UInt32, Int32, Int32, Int64, Int32, Int64]
const JTYPE_DEFAULTS      = [0,       0,       0,     0,      0,     0,       0,       false, "",             nothing, nothing, UInt8[],       0,      0,     0,     0,     0,     0]

isprimitive(fldtype) = (1 <= fldtype <= 8) || (13 <= fldtype <= 18)

# maps protofile name to package name
const _packages = Dict{String,String}()

# maps protofile name to array of imported protofiles
const protofile_imports = Dict()

# maps resolved names in the "protofile module name" -> "type name" -> ["nested type name",...] form
const name_maps = Dict()

function add_name_map(name, fullname)
    parts = rsplit(fullname, "."; limit=2, keepempty=false)

    if length(parts) == 1
        pkgname = ""
        typname = parts[1]
    else
        pkgname = parts[1]
        typname = parts[2]
    end

    if name == typname
        nested_level = ""
    else
        nested_level = typname[1:end-length(name)-1]
        typname = name
    end

    names_in_module = get!(name_maps, pkgname) do
        Dict{String,Set{String}}()
    end
    nested_type_names = get!(names_in_module, typname) do
        Set{String}()
    end
    push!(nested_type_names, nested_level)
    nothing
end

# Treat Google Proto3 extensions specially as they are built into ProtoBuf.jl (for issue #77)
const GOOGLE_PROTO3_EXTENSIONS = "google.protobuf"


_module_postfix = false
_map_as_array = false

#--------------------------------------------------------------------
# begin keyword handling
#--------------------------------------------------------------------
const _keywords = [
    "if", "else", "elseif", "while", "for", "begin", "end", "quote",
    "try", "catch", "return", "local", "abstract", "function", "macro",
    "ccall", "finally", "typealias", "break", "continue", "type",
    "global", "module", "using", "import", "export", "const", "let",
    "bitstype", "do", "baremodule", "importall", "immutable",
    "Type", "Enum", "Any", "DataType", "Base", "Set"
]

chk_keyword(name) = (name in _keywords) ? string('_', name) : String(name)
#--------------------------------------------------------------------
# end keyword handling
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# begin name resolution utilities
#--------------------------------------------------------------------

mutable struct Scope
    name::String
    syms::Vector{String}
    files::Vector{String}
    is_module::Bool
    children::Vector{Scope}
    parent::Scope

    Scope(name::String; is_module::Bool=false) = new(name, String[], String[], is_module, Scope[])
    function Scope(name::String, parent::Scope; is_module::Bool=false)
        s = new(name, String[], String[], is_module, Scope[], parent)
        push!(parent.children, s)
        s
    end
end

const top_scope = Scope("")

"""
Full Julia name of a scope, that can be resolved from Julia code.
Scope can be a module or a struct within a module.

Modules are separated with `.` and structs with `_`.

When an additional name is passed, it is prefixed with the scope according to the same rules.
"""
function fullname(s::Scope)
    if isempty(s.name) || isempty(s.parent.name)
        return s.name
    end
    string(fullname(s.parent), s.parent.is_module ? "." : "_", s.name)
end
function fullname(scope::Scope, name::String)
    if isempty(scope.name)
        name
    else
        sep = scope.is_module ? "." : "_"
        string(fullname(scope), sep, name)
    end
end

scope_has_file(s::Scope, f::String) = (f in s.files || any(x->scope_has_file(x,f), s.children))

"""
Given the module name, return the corresponding scope object.
Inserts a new scope if required.
"""
function get_module_scope(parent::Scope, module_name::String)
    if _module_postfix
        module_name = module_name * "_pb"
    end
    # return existing scope if possible
    for s in parent.children
        if s.name == module_name
            return s
        end
    end
    # create new scope otherwise
    Scope(module_name, parent; is_module=true)
end

"""
Search for `name` in the scope hierarchy and qualify it with full scope.
"""
function qualify_in_hierarchy(name::String, scope::Scope)
    if startswith(name, "ProtoBuf.google.protobuf.")
        return name
    elseif name in scope.syms
        return fullname(scope, name)
    elseif isdefined(scope, :parent)
        return qualify_in_hierarchy(name, scope.parent)
    else
        error("unresolved name $name at scope $(scope.name)")
    end
end

splitmodule(name::String) = rsplit(name, '.'; limit=2)
function splitmodule_chkkeyword(name::String)
    sm = splitmodule(name)
    if length(sm) > 1
        modul = String(sm[1])
        name = String(sm[2])
    else
        modul = ""
    end
    name = chk_keyword(name)
    modul,name
end

function findmodule(name::String)
    mlen = 0
    mpkg = ""
    for pkg in values(_packages)
        orig = _module_postfix ? join(map(m->m[1:end-3], split(pkg, ".")), ".") : pkg
        if (length(pkg) > mlen) && startswith(name, orig)
            mlen = length(orig)
            mpkg = pkg
        end
    end
    (mpkg, replace((0 == mlen) ? name : name[(mlen+2):end], '.'=>'_'))
end

function field_type_name(full_type_name::String)
    comps = split(full_type_name, '.'; keepempty=false)
    if isempty(comps)
        type_name = full_type_name
    else
        type_name = join(comps, '.')
        for level in (length(comps)-1):-1:1
            package_name = join(comps[1:level], '.')
            if package_name == GOOGLE_PROTO3_EXTENSIONS
                comps[end] = chk_keyword(comps[end])
                type_name = "ProtoBuf.$(join(comps, '.'))"
                break
            elseif package_name in keys(name_maps)
                type_maps = name_maps[package_name]
                if last(comps) in keys(type_maps)
                    nested_level = join(comps[(level+1):(end-1)], '_')
                    if nested_level in type_maps[last(comps)]
                        type_name = isempty(nested_level) ? last(comps) : string(nested_level, "_", last(comps))
                        isempty(package_name) || (type_name = string(package_name, ".", type_name))
                        break
                    end
                end
            end
        end
    end
    @debug("usable type name for $full_type_name is $type_name")
    type_name
end

#--------------------------------------------------------------------
# end name resolution utilities
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# begin deferred writing (correct ordering) of generated entities
#--------------------------------------------------------------------
struct DeferredWrite
    iob::IOBuffer
    depends::Vector{String}
end
const _deferred = Dict{String,DeferredWrite}()
# set of fully-qualified names we've resolved, to handle dependencies in other files
const _all_resolved = Set{String}()

function defer(name::String, iob::IOBuffer, depends::String)
    @debug("defer $name due to $depends")
    if isdeferred(name)
        depsnow = _deferred[name].depends
        !(depends in depsnow) && push!(depsnow, depends)
        return
    end
    _deferred[name] = DeferredWrite(iob, String[depends])
    nothing
end

isdeferred(name::String) = haskey(_deferred, name)
function isresolved(dtypename::String, referenced_name::String, full_referenced_name::String, exports::Vector{String})
    (dtypename == referenced_name) && return true
    for jtype in JTYPES
        (referenced_name == string(jtype)) && return true
    end
    if '.' in referenced_name
        return !isdeferred(referenced_name)
    elseif referenced_name in exports
        return !(isdeferred(referenced_name) || isdeferred(full_referenced_name))
    end
    false
end

function resolve(iob::IOBuffer, name::String)
    fully_resolved = String[]
    for (typ,dw) in _deferred
        idx = something(findfirst(isequal(name), dw.depends), 0)
        (idx == 0) && continue
        splice!(dw.depends, idx)
        isempty(dw.depends) && push!(fully_resolved, typ)
    end

    # write all fully resolved entities
    for typ in fully_resolved
        @debug("fully resolved $typ")
        print(iob, String(take!(_deferred[typ].iob)))
        delete!(_deferred, typ)
        push!(_all_resolved, typ)
    end

    # mark them resolved as well
    for typ in fully_resolved
        resolve(iob, typ)
    end
end
#--------------------------------------------------------------------
# end deferred writing (correct ordering) of generated entities
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# start utility methods
#--------------------------------------------------------------------
function protofile_name_to_module_name(n::String)
    name = splitext(basename(n))[1]
    name = replace(name, '.'=>'_')
    name = string(name, "_pb")
    return name
end

function append_response(resp::CodeGeneratorResponse, protofile::FileDescriptorProto, io::IOBuffer)
    outdir = dirname(protofile.name)
    filename = protofile_name_to_module_name(protofile.name)
    filename = string(filename, ".jl")

    append_response(resp, filename, io)
end

function append_response(resp::CodeGeneratorResponse, filename::String, io::IOBuffer)
    jfile = ProtoBuf.instantiate(CodeGeneratorResponse_File)

    jfile.name = filename
    jfile.content = String(take!(io))
    !hasproperty(resp, :file) && (resp.file = CodeGeneratorResponse_File[])
    push!(resp.file, jfile)
    resp
end

function err_response(errio::IOBuffer)
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    resp.error = String(take!(errio))
    resp
end
#--------------------------------------------------------------------
# end utility methods
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# begin code generation
#--------------------------------------------------------------------
function generate_enum(io::IO, errio::IO, enumtype::EnumDescriptorProto, scope::Scope, exports::Vector{String})
    _modul,enumname = splitmodule_chkkeyword(fullname(scope, enumtype.name))
    push!(scope.syms, enumname)

    @debug("begin enum $(enumname)")
    println(io, "const ", enumname, " = (;[")
    for value::EnumValueDescriptorProto in enumtype.value
        # If we find that the field name is a keyword prepend it with `_`
        fldname = chk_keyword(value.name)
        println(io, "    Symbol(\"", fldname, "\") => Int32(", value.number, "),")
    end
    println(io, "]...)")
    println(io, "")
    push!(exports, enumname)
    @debug("end enum $(enumname)")
    nothing
end

function generate_msgtype(outio::IO, errio::IO, dtype::DescriptorProto, scope::Scope, syntax::String, exports::Vector{String}, depends::Vector{String}, mapentries::Dict{String,Tuple{String,String}}, deferedmode::Bool)
    full_dtypename = fullname(scope, dtype.name)

    io = IOBuffer()
    modul,dtypename = splitmodule_chkkeyword(full_dtypename)
    full_dtypename = (modul=="") ? dtypename : "$(modul).$(dtypename)"
    deferedmode && !isdeferred(full_dtypename) && return
    @debug("begin type $(full_dtypename)")
    add_name_map(dtype.name, full_dtypename)

    scope = Scope(dtype.name, scope)

    # check oneof
    oneof_names = Vector{String}()
    if hasproperty(dtype, :oneof_decl)
        for oneof_decl in dtype.oneof_decl
            if hasproperty(oneof_decl, :name)
                push!(oneof_names,  "Symbol(\"$(oneof_decl.name)\")")
            end
        end
    end

    # generate enums
    if hasproperty(dtype, :enum_type)
        for enum_type in dtype.enum_type
            generate_enum(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return
        end
    end

    # generate nested types
    if hasproperty(dtype, :nested_type)
        for nested_type::DescriptorProto in dtype.nested_type
            generate_msgtype(io, errio, nested_type, scope, syntax, exports, depends, mapentries, deferedmode)
            (errio.size > 0) && return
        end
    end

    # generate this type
    reqflds = String[]
    allflds = String[]
    getpropertylist = Pair[]
    packedflds = String[]
    fldnums = Int[]
    defvals = String[]
    wtypes = String[]
    realfldtypes = String[]
    oneofs = isempty(oneof_names) ? Int[] : zeros(Int, length(dtype.field))
    ismapentry = hasproperty(dtype, :options) && hasproperty(dtype.options, :map_entry) && dtype.options.map_entry
    map_key_type = ""
    map_val_type = ""

    if hasproperty(dtype, :field)
        for fld_idx in 1:length(dtype.field)
            field = dtype.field[fld_idx]
            if hasproperty(field, :oneof_index) && !isempty(oneofs) && !ProtoBuf.isdefaultproperty(field, :oneof_index)
                oneof_idx = field.oneof_index + 1
                oneofs[fld_idx] = oneof_idx
            end

            # If we find that the field name is a keyword prepend it with _type
            fldname = chk_keyword(field.name)
            if field._type == FieldDescriptorProto_Type.TYPE_GROUP
                println(errio, "Groups are not supported")
                return
            end

            full_typ_name = ""
            if (field._type == FieldDescriptorProto_Type.TYPE_MESSAGE) || (field._type == FieldDescriptorProto_Type.TYPE_ENUM)
                typ_name = field.type_name
                if startswith(typ_name, '.')
                    (m,t) = findmodule(typ_name[2:end])
                    t = chk_keyword(t)
                    full_typ_name = m=="" ? t : "$(m).$(t)"
                    typ_name = (m == modul) ? t : full_typ_name
                else
                    full_typ_name = qualify_in_hierarchy(typ_name, scope)
                    typ_name = full_typ_name
                    m,t = splitmodule_chkkeyword(typ_name)
                    (m == modul) && (typ_name = t)
                    full_typ_name = m=="" ? t : "$(m).$(t)"
                end
            elseif field._type == FieldDescriptorProto_Type.TYPE_SINT32
                push!(wtypes, ":$fldname => :sint32")
            elseif field._type == FieldDescriptorProto_Type.TYPE_SINT64
                push!(wtypes, ":$fldname => :sint64")
            elseif field._type == FieldDescriptorProto_Type.TYPE_FIXED32
                push!(wtypes, ":$fldname => :fixed32")
            elseif field._type == FieldDescriptorProto_Type.TYPE_SFIXED32
                push!(wtypes, ":$fldname => :sfixed32")
            elseif field._type == FieldDescriptorProto_Type.TYPE_FIXED64
                push!(wtypes, ":$fldname => :fixed64")
            elseif field._type == FieldDescriptorProto_Type.TYPE_SFIXED64
                push!(wtypes, ":$fldname => :sfixed64")
            end
            enum_typ_name = (field._type == FieldDescriptorProto_Type.TYPE_ENUM) ? typ_name : ""
            (field._type != FieldDescriptorProto_Type.TYPE_MESSAGE) && (typ_name = "$(JTYPES[field._type])")

            push!(fldnums, field.number)
            (FieldDescriptorProto_Label.LABEL_REQUIRED == field.label) && push!(reqflds, ":"*fldname)

            if hasproperty(field, :default_value) && !isempty(field.default_value)
                if field._type == FieldDescriptorProto_Type.TYPE_STRING
                    push!(defvals, ":$fldname => \"$(escape_string(field.default_value))\"")
                elseif field._type == FieldDescriptorProto_Type.TYPE_MESSAGE
                    println(errio, "Default values for message types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                elseif field._type == FieldDescriptorProto_Type.TYPE_BYTES
                    println(errio, "Default values for byte array types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                elseif field._type == FieldDescriptorProto_Type.TYPE_ENUM
                    push!(defvals, ":$fldname => $(field_type_name(enum_typ_name)).$(field.default_value)")
                elseif field._type == FieldDescriptorProto_Type.TYPE_DOUBLE
                    defval = replace(replace(field.default_value, "inf" => "Inf"), "nan" => "NaN")
                    push!(defvals, ":$fldname => $defval")
                elseif field._type == FieldDescriptorProto_Type.TYPE_FLOAT
                    defval = replace(replace(field.default_value, "inf" => "Inf32"), "nan" => "NaN32")
                    push!(defvals, ":$fldname => $defval")
                else
                    push!(defvals, ":$fldname => $(field.default_value)")
                end
            end

            packed = (hasproperty(field, :options) && field.options.packed) ||
                     ((syntax == "proto3") && (FieldDescriptorProto_Label.LABEL_REPEATED == field.label) && isprimitive(field._type))
            packed && push!(packedflds, ":"*fldname)

            gen_typ_name = ""
            if !(isresolved(dtypename, typ_name, full_typ_name, exports) || full_typ_name in _all_resolved)
                if deferedmode
                    gen_typ_name = "Base.Any"
                else
                    defer(full_dtypename, io, full_typ_name)
                end
            end

            typ_name = field_type_name(typ_name)
            is_typ_mapentry = typ_name in keys(mapentries)
            if is_typ_mapentry && !_map_as_array
                k,v = mapentries[typ_name]
                typ_name = "Base.Dict{$k,$v}"
                if deferedmode
                    # because we do not know if Dict key and value types are resolved yet
                    gen_typ_name = "Base.Dict"
                end
            elseif FieldDescriptorProto_Label.LABEL_REPEATED == field.label
                typ_name = "Base.Vector{$typ_name}"
            end

            if isempty(gen_typ_name)
                gen_typ_name = typ_name
                push!(allflds, ":$fldname => $(typ_name)")
                push!(getpropertylist, ":$fldname" => "$(typ_name)")
            else
                push!(realfldtypes, ":$fldname => \"$(typ_name)\"")
                push!(allflds, ":$fldname => \"$(typ_name)\"")
                push!(getpropertylist, ":$fldname" => "Any")
            end

            if ismapentry
                if field.number == 1
                    map_key_type = typ_name
                elseif field.number == 2
                    map_val_type = typ_name
                end
            end
        end
    end

    # generate struct body
    println(io, """
        mutable struct $(dtypename) <: ProtoType
            __protobuf_jl_internal_meta::ProtoMeta
            __protobuf_jl_internal_values::Dict{Symbol,Any}
            __protobuf_jl_internal_defaultset::Set{Symbol}

            function $(dtypename)(; kwargs...)
                obj = new(meta($(dtypename)), Dict{Symbol,Any}(), Set{Symbol}())
                values = obj.__protobuf_jl_internal_values
                symdict = obj.__protobuf_jl_internal_meta.symdict
                for nv in kwargs
                    fldname, fldval = nv
                    fldtype = symdict[fldname].jtyp
                    (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
                    if fldval !== nothing
                        values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
                    end
                end
                obj
            end""")
    println(io, "end # mutable struct $(dtypename)", ismapentry ? " (mapentry)" : "", deferedmode ? " (has cyclic type dependency)" : "")

    # generate the meta for this type
    @debug("generating meta", dtypename)
    _d_fldnums = [1:length(fldnums);]
    println(io, """const __meta_$(dtypename) = Ref{ProtoMeta}()
        function meta(::Type{$dtypename})
            ProtoBuf.metalock() do
                if !isassigned(__meta_$dtypename)
                    __meta_$(dtypename)[] = target = ProtoMeta($dtypename)""")
    !isempty(reqflds) && println(io, "            req = Symbol[$(join(reqflds, ','))]")
    !isempty(defvals) && println(io, "            val = Dict{Symbol,Any}($(join(defvals, ", ")))")
    (fldnums != _d_fldnums) && println(io, "            fnum = Int[$(join(fldnums, ','))]")
    !isempty(packedflds) && println(io, "            pack = Symbol[$(join(packedflds, ','))]")
    !isempty(wtypes) && println(io, "            wtype = Dict($(join(wtypes, ", ")))")
    println(io, "            allflds = Pair{Symbol,Union{Type,String}}[$(join(allflds, ", "))]")
    if !isempty(oneofs)
        println(io, "            oneofs = Int[$(join(oneofs, ','))]")
        println(io, "            oneof_names = Symbol[$(join(oneof_names, ','))]")
    end
    print(io, "            meta(target, $(dtypename), allflds, ")
    print(io, isempty(reqflds) ? "ProtoBuf.DEF_REQ, " : "req, ")
    print(io, (fldnums == _d_fldnums) ? "ProtoBuf.DEF_FNUM, " : "fnum, ")
    print(io, isempty(defvals) ? "ProtoBuf.DEF_VAL, " : "val, ")
    print(io, isempty(packedflds) ? "ProtoBuf.DEF_PACK, " : "pack, ")
    print(io, isempty(wtypes) ? "ProtoBuf.DEF_WTYPES, " : "wtype, ")
    print(io, isempty(oneofs) ? "ProtoBuf.DEF_ONEOFS, " : "oneofs, ")
    print(io, isempty(oneofs) ? "ProtoBuf.DEF_ONEOF_NAMES" : "oneof_names")
    println(io, ")")
    println(io, "        end")
    println(io, "        __meta_$(dtypename)[]")
    println(io, "    end")
    println(io, "end")

    # generate new getproperty method
    if !isempty(getpropertylist)
        @debug("generating getproperty", dtypename)
        println(io, "function Base.getproperty(obj::$(dtypename), name::Symbol)")
        pfx = "if"
        for prop in getpropertylist
            println(io, "    $(pfx) name === $(first(prop))")
            println(io, "        return (obj.__protobuf_jl_internal_values[name])::$(last(prop))")
            if pfx == "if"
                pfx = "elseif"
            end
        end
        println(io, "    else")
        println(io, "        getfield(obj, name)")
        println(io, "    end")
        println(io, "end")
    end

    println(io, "")
    push!(exports, dtypename)
    ismapentry && (mapentries[dtypename] = (map_key_type, map_val_type))

    deferedmode && (full_dtypename in keys(_deferred)) && delete!(_deferred, full_dtypename)

    if !isdeferred(full_dtypename)
        @debug("resolved (!deferred)", full_dtypename)
        print(outio, String(take!(io)))
        deferedmode || resolve(outio, full_dtypename)
        push!(_all_resolved, full_dtypename)
    end

    @debug("end type", full_dtypename)
    nothing
end

function scoped_svc_type_name(scope::Scope, typ_name)
    modul = fullname(scope)

    if isempty(modul)
        return typ_name
    elseif startswith(typ_name, string(modul, "."))
        return typ_name[(length(modul)+2):end]
    elseif startswith(typ_name, '.')
        (m,t) = findmodule(typ_name[2:end])
        t = chk_keyword(t)
        full_typ_name = m=="" ? t : "$(m).$(t)"
        return (m == modul) ? t : full_typ_name
    else
        full_typ_name = qualify_in_hierarchy(typ_name, scope)
        typ_name = full_typ_name
        m,t = splitmodule_chkkeyword(typ_name)
        (m == modul) && (typ_name = t)
        return typ_name
    end
end

function generate_svc(io::IO, errio::IO, stype::ServiceDescriptorProto, scope::Scope, svcidx::Int, exports::Vector{String})
    nmethods = hasproperty(stype, :method) ? length(stype.method) : 0

    # generate method and service descriptors
    println(io, "# service methods for $(stype.name)")
    println(io, "const _$(stype.name)_methods = MethodDescriptor[")
    for idx in 1:nmethods
        method = stype.method[idx]
        in_typ_name = scoped_svc_type_name(scope, field_type_name(method.input_type))
        out_typ_name = scoped_svc_type_name(scope, field_type_name(method.output_type))
        elem_sep = (idx < nmethods) ? "," : ""

        method.client_streaming && (in_typ_name = "Channel{" * in_typ_name * "}")
        method.server_streaming && (out_typ_name = "Channel{" * out_typ_name * "}")

        println(io, "        MethodDescriptor(\"$(method.name)\", $(idx), $(in_typ_name), $(out_typ_name))$(elem_sep)")
    end
    println(io, "    ] # const _$(stype.name)_methods")
    fullservicename = scope.is_module ? fullname(scope, stype.name) : stype.name
    println(io, "const _$(stype.name)_desc = ServiceDescriptor(\"$(fullservicename)\", $(svcidx), _$(stype.name)_methods)")
    println(io, "")

    # generate service
    println(io, "$(stype.name)(impl::Module) = ProtoService(_$(stype.name)_desc, impl)")
    println(io, "")
    push!(exports, stype.name)

    # generate stubs
    stub = "$(stype.name)Stub"
    println(io, "mutable struct $(stub) <: AbstractProtoServiceStub{false}")
    println(io, "    impl::ProtoServiceStub")
    println(io, "    $(stub)(channel::ProtoRpcChannel) = new(ProtoServiceStub(_$(stype.name)_desc, channel))")
    println(io, "end # mutable struct $(stub)")
    println(io, "")
    push!(exports, stub)

    nbstub = "$(stype.name)BlockingStub"
    println(io, "mutable struct $(nbstub) <: AbstractProtoServiceStub{true}")
    println(io, "    impl::ProtoServiceBlockingStub")
    println(io, "    $(nbstub)(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_$(stype.name)_desc, channel))")
    println(io, "end # mutable struct $(nbstub)")
    println(io, "")
    push!(exports, nbstub)

    for idx in 1:nmethods
        method = stype.method[idx]
        in_typ_name = scoped_svc_type_name(scope, field_type_name(method.input_type))
        method.client_streaming && (in_typ_name = "Channel{" * in_typ_name * "}")
        println(io, "$(method.name)(stub::$(stub), controller::ProtoRpcController, inp::$(in_typ_name), done::Function) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp, done)")
        println(io, "$(method.name)(stub::$(nbstub), controller::ProtoRpcController, inp::$(in_typ_name)) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp)")
        println(io, "")
        push!(exports, method.name)
    end
    nothing
end

function generate_file(io::IO, errio::IO, protofile::FileDescriptorProto)
    @debug("generate begin for $(protofile.name), package $(protofile.package)")

    scope = top_scope
    if !isempty(protofile.package)
        for pkgname in split(protofile.package, '.')
            scope = get_module_scope(scope, String(pkgname))
        end
    end

    push!(scope.files, protofile.name)
    @debug("generated scope for $(protofile.name), package $(protofile.package)")

    # generate module begin
    if !isempty(scope.name)
        scope.is_module = true
        _packages[protofile.name] = fullname(scope)
    end

    # generate syntax version
    syntax = (hasproperty(protofile, :syntax) && !isempty(protofile.syntax)) ? protofile.syntax : "proto2"
    println(io, "# syntax: $(syntax)")

    depends = Vector{String}()
    @debug("generating imports")
    # generate imports
    println(io, "using ProtoBuf")
    dep_imports = Vector{String}()
    add_import = (imp) -> begin
        (imp in dep_imports) || push!(dep_imports, imp)
        nothing
    end
    add_import("ProtoBuf.meta")
    if hasproperty(protofile, :dependency)
        protofile_imports[protofile.name] = protofile.dependency
        using_pkgs = Set{String}()
        for dependency in protofile.dependency
            if haskey(_packages, dependency)
                push!(using_pkgs, _packages[dependency])
                push!(depends, _packages[dependency])
            end
        end

        fullscopename = scope.is_module ? fullname(scope) : ""
        parentscope = (isdefined(scope, :parent) && scope.parent.is_module) ? fullname(scope.parent) : ""
        for dependency in using_pkgs
            # current scope is available by default
            (fullscopename == dependency) && continue
            # google extenstions are included with ProtoBuf
            if dependency == GOOGLE_PROTO3_EXTENSIONS
                dependency = "ProtoBuf." * dependency
                add_import(dependency)
            else
                comps = split(dependency, '.'; keepempty=false)
                if startswith(dependency, parentscope*".")
                    comps[1] = ".." * comps[1]
                elseif !isempty(fullscopename)
                    comps[1] = "._ProtoBuf_Top_." * comps[1]
                end
                add_import(comps[1])
                #for idx in 1:length(comps)
                #    add_import(join(comps[1:idx], '.'))
                #end
            end
        end
    end
    for imp in dep_imports
        println(io, "import ", imp)
    end
    println(io, "")

    exports = Vector{String}()
    mapentries = Dict{String, Tuple{String,String}}()

    # generate top level enums
    @debug("generating enums")
    if hasproperty(protofile, :enum_type)
        for enum_type in protofile.enum_type
            generate_enum(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return
        end
    end

    # generate message types
    @debug("generating types")
    if hasproperty(protofile, :message_type)
        for message_type in protofile.message_type
            generate_msgtype(io, errio, message_type, scope, syntax, exports, depends, mapentries, false)
            (errio.size > 0) && return
        end
    end

    # generate service stubs
    @debug("generating services")
    if hasproperty(protofile, :service)
        nservices = length(protofile.service)
        for idx in 1:nservices
            service = protofile.service[idx]
            generate_svc(io, errio, service, scope, idx, exports)
            (errio.size > 0) && return
        end
    end

    # generate deferred message types
    @debug("generating deferred types")
    if hasproperty(protofile, :message_type)
        for message_type in protofile.message_type
            generate_msgtype(io, errio, message_type, scope, syntax, exports, depends, mapentries, true)
            (errio.size > 0) && return
        end
    end

    # check if everything is resolved
    if !isempty(_deferred)
        println(errio, "All types could not be fully resolved:")
        for (k,v) in _deferred
            println(errio, "$k depends on $(join(v.depends, ','))")
        end
        return
    end

    # generate exports
    !isempty(exports) && println(io, "export ", join(exports, ", "))

    # mention mapentries
    !isempty(mapentries) && println(io, "# mapentries: ", join(mapentries, ", "))

    @debug("generate end for $(protofile.name)")
    nothing
end

function print_package(io::IO, s::Scope, indent="")
    s.is_module || return
    println(io, "$(indent)module $(s.name)")
    nested = indent*"  "
    println(io, "$(nested)const _ProtoBuf_Top_ = @static isdefined(parentmodule(@__MODULE__), :_ProtoBuf_Top_) ? (parentmodule(@__MODULE__))._ProtoBuf_Top_ : parentmodule(@__MODULE__)")
    children = Set(s.children)
    for f in s.files
        if haskey(protofile_imports,f)
            deps = protofile_imports[f]
            # if the file we're about to `include` depends on any of our child modules,
            # generate those first.
            for d in deps
                for c in filter(c->scope_has_file(c,d), children)
                    delete!(children, c)
                    print_package(io, c, nested)
                end
            end
        end

        fname = string(protofile_name_to_module_name(f), ".jl")
        println(io, "$(nested)include(\"$fname\")")
    end
    for c in s.children
        # check if already included
        (c in children) || continue
        print_package(io, c, nested)
    end
    println(io, "$(indent)end")
end

function readreq(srcio::IO)
    req = ProtoBuf.instantiate(CodeGeneratorRequest)
    readproto(srcio, req)
    req
end

function codegen(srcio::IO)
    errio = IOBuffer()
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    @debug("generate begin")
    while !eof(srcio)
        req = readreq(srcio)

        if !hasproperty(req, :file_to_generate)
            @debug("no files to generate!!")
            continue
        end

        @debug("generate request for $(length(req.file_to_generate)) proto files")
        @debug("$(req.file_to_generate)")

        #hasproperty(req, :parameter) && @debug("parameter $(req.parameter)")

        for protofile in req.proto_file
            io = IOBuffer()
            generate_file(io, errio, protofile)
            (errio.size > 0) && return err_response(errio)
            append_response(resp, protofile, io)
        end
    end
    if !isempty(top_scope.children)
        for pkg in top_scope.children
            if pkg.is_module
                io = IOBuffer()
                print_package(io, pkg)
                append_response(resp, "$(pkg.name).jl", io)
            end
        end
    end
    @debug("generate end")
    resp
end
#--------------------------------------------------------------------
# end code generation
#--------------------------------------------------------------------


function debug_log_filename(filename=nothing)
    for arg in ARGS
        if startswith(arg, "--debug-gen")
            parts = split(arg, '=')
            filename = (length(parts) == 2) ? strip(last(parts)) : "juliaprotoc.log"
            break
        end
    end
    filename
end

function with_debug(f)
    debug_log_file = debug_log_filename()
    if debug_log_file === nothing
        f()
    else
        open(debug_log_file, "a") do logstream
            with_logger(SimpleLogger(logstream, Logging.Debug)) do
                f()
            end
        end
    end
end

##
# the main read - write method
function gen()
    global _module_postfix = in("--module-postfix-enabled", ARGS)
    global _map_as_array = in("--map-as-array", ARGS)
    with_debug() do
        try
            writeproto(stdout, codegen(stdin))
        catch ex
            println(stderr, "Exception while generating Julia code")
            rethrow()
        end
    end
end

end # module Gen
