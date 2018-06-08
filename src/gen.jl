module Gen

using ProtoBuf.GoogleProtoBuf
using ProtoBuf.GoogleProtoBufCompiler

using ProtoBuf
using Compat

import ProtoBuf: meta, @logmsg, DEF_REQ, DEF_FNUM, DEF_VAL, DEF_PACK

export gen

const JTYPES              = [Float64, Float32, Int64, UInt64, Int32, UInt64,  UInt32,  Bool, AbstractString, Any, Any, Vector{UInt8}, UInt32, Int32, Int32, Int64, Int32, Int64]
const JTYPE_DEFAULTS      = [0,       0,       0,     0,      0,     0,       0,       false, "",    nothing, nothing, UInt8[], 0,     0,     0,       0,       0,     0;]

isprimitive(fldtype) = (1 <= fldtype <= 8) || (13 <= fldtype <= 18)

# maps protofile name to package name
const _packages = Dict{AbstractString,AbstractString}()

# maps protofile name to array of imported protofiles
const protofile_imports = Dict()

# Treat Google Proto3 extensions specially as they are built into ProtoBuf.jl (for issue #77)
const GOOGLE_PROTO3_EXTENSIONS = "google.protobuf"

const _keywords = [
    "if", "else", "elseif", "while", "for", "begin", "end", "quote", 
    "try", "catch", "return", "local", "abstract", "function", "macro",
    "ccall", "finally", "typealias", "break", "continue", "type", 
    "global", "module", "using", "import", "export", "const", "let", 
    "bitstype", "do", "baremodule", "importall", "immutable",
    "Type", "Enum", "Any", "DataType", "Base"
]

_module_postfix = false
_map_as_array = false

mutable struct Scope
    name::AbstractString
    syms::Vector{AbstractString}
    files::Vector{AbstractString}
    is_module::Bool
    children::Vector{Scope}
    parent::Scope

    Scope(name::AbstractString) = new(name, AbstractString[], AbstractString[], false, Scope[])
    function Scope(name::AbstractString, parent::Scope)
        s = new(name, AbstractString[], AbstractString[], false, Scope[], parent)
        push!(parent.children, s)
        s
    end
end

function fullname(s::Scope)
    if isempty(s.name) || isempty(s.parent.name)
        return s.name
    end
    string(fullname(s.parent), s.parent.is_module ? "." : "_", s.name)
end

const top_scope = Scope("")
top_scope.is_module = false

function get_module_scope(parent::Scope, newname::AbstractString)
    newname = _module_postfix ? newname * "_pb" : newname
    for s in parent.children
        if s.name == newname
            return s
        end
    end
    s = Scope(newname, parent)
    s.is_module = true
    s
end

function qualify(name::AbstractString, scope::Scope)
    if name in scope.syms
        return pfx(name, scope) 
    elseif isdefined(scope, :parent)
        return qualify(name, scope.parent) 
    else
        error("unresolved name $name at scope $(scope.name)")
    end
end

function readreq(srcio::IO)
    req = ProtoBuf.instantiate(CodeGeneratorRequest)
    readproto(srcio, req)
    req
end

pfx(name::AbstractString, scope::Scope) = isempty(scope.name) ? name : (fullname(scope) * (scope.is_module ? "." : "_") * name)
splitmodule(name::AbstractString) = rsplit(name, '.'; limit=2)
function findmodule(name::AbstractString)
    mlen = 0
    mpkg = ""
    for pkg in values(_packages)
        orig = _module_postfix ? join(map(m->m[1:end-3], split(pkg, ".")), ".") : pkg
        if (length(pkg) > mlen) && startswith(name, orig)
            mlen = length(orig)
            mpkg = pkg
        end
    end
    (mpkg, replace((0 == mlen) ? name : name[(mlen+2):end], '.', '_'))
end


mutable struct DeferredWrite
    iob::IOBuffer
    depends::Vector{AbstractString}
end
const _deferred = Dict{AbstractString,DeferredWrite}()
# set of fully-qualified names we've resolved, to handle dependencies in other files
const _all_resolved = Set{AbstractString}()

function defer(name::AbstractString, iob::IOBuffer, depends::AbstractString)
    @logmsg("defer $name due to $depends")
    if isdeferred(name)
        depsnow = _deferred[name].depends
        !(depends in depsnow) && push!(depsnow, depends)
        return
    end
    _deferred[name] = DeferredWrite(iob, AbstractString[depends])
    nothing
end

isdeferred(name::AbstractString) = haskey(_deferred, name)
function isresolved(dtypename::AbstractString, referenced_name::AbstractString, full_referenced_name::AbstractString, exports::Vector{AbstractString})
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

function resolve(iob::IOBuffer, name::AbstractString)
    fully_resolved = AbstractString[]
    for (typ,dw) in _deferred
        idx = findfirst(dw.depends, name)
        (idx == 0) && continue
        splice!(dw.depends, idx)
        isempty(dw.depends) && push!(fully_resolved, typ)
    end

    # write all fully resolved entities
    for typ in fully_resolved
        @logmsg("resolved $typ")
        print(iob, String(take!(_deferred[typ].iob)))
        delete!(_deferred, typ)
        push!(_all_resolved, typ)
    end

    # mark them resolved as well
    for typ in fully_resolved
        resolve(iob, typ)
    end
end

chk_keyword(name) = (name in _keywords) ? string('_', name) : name

function generate(io::IO, errio::IO, enumtype::EnumDescriptorProto, scope::Scope, exports::Vector{AbstractString})
    enumname = pfx(enumtype.name, scope)
    sm = splitmodule(enumname)
    (length(sm) > 1) && (enumname = sm[2])
    enumname = chk_keyword(enumname)
    push!(scope.syms, enumname)

    @logmsg("begin enum $(enumname)")
    println(io, "struct __enum_$(enumname) <: ProtoEnum")
    values = Int32[]
    for value::EnumValueDescriptorProto in enumtype.value
        # If we find that the field name is a keyword prepend it with `_`
        fldname = chk_keyword(value.name)
        println(io, "    $(fldname)::Int32")
        push!(values, value.number)
    end
    println(io, "    __enum_$(enumname)() = new($(join(values,',')))")
    println(io, "end #struct __enum_$(enumname)")
    println(io, "const $(enumname) = __enum_$(enumname)()")
    println(io, "")
    push!(exports, enumname)
    @logmsg("end enum $(enumname)")
    nothing
end

function field_type_name(full_type_name::AbstractString, depends::Vector{AbstractString})
    comps = split(full_type_name, '.')
    if isempty(comps)
        type_name = full_type_name
    else
        package_name = join(comps[1:(end - 1)], '.')
        if package_name == GOOGLE_PROTO3_EXTENSIONS
            type_name = "ProtoBuf.$full_type_name"
        else
            type_name = full_type_name
        end
    end
    @logmsg("check $full_type_name against $depends || found $type_name")
    return type_name
end

function generate(outio::IO, errio::IO, dtype::DescriptorProto, scope::Scope, syntax::AbstractString, exports::Vector{AbstractString}, depends::Vector{AbstractString}, mapentries::Dict, deferedmode::Bool)
    full_dtypename = dtypename = pfx(dtype.name, scope)
    deferedmode && !isdeferred(full_dtypename) && return
    io = IOBuffer()
    sm = splitmodule(dtypename)
    modul,dtypename = (length(sm) > 1) ? (sm[1],sm[2]) : ("",dtypename)
    dtypename = chk_keyword(dtypename)
    full_dtypename = (modul=="") ? dtypename : "$(modul).$(dtypename)"
    @logmsg("begin type $(full_dtypename)")

    scope = Scope(dtype.name, scope)

    # check oneof
    oneof_names = String[]
    if isfilled(dtype, :oneof_decl)
        for oneof_decl in dtype.oneof_decl
            if isfilled(oneof_decl, :name)
                push!(oneof_names,  "Symbol(\"$(oneof_decl.name)\")")
            end
        end
    end

    # generate enums
    if isfilled(dtype, :enum_type)
        for enum_type in dtype.enum_type
            generate(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return
        end
    end

    # generate nested types
    if isfilled(dtype, :nested_type)
        for nested_type::DescriptorProto in dtype.nested_type
            generate(io, errio, nested_type, scope, syntax, exports, depends, mapentries, deferedmode)
            (errio.size > 0) && return
        end
    end

    # generate this type
    println(io, "mutable struct $(dtypename) <: ProtoType")
    reqflds = String[]
    packedflds = String[]
    fldnums = Int[]
    defvals = String[]
    wtypes = String[]
    realfldtypes = String[]
    oneofs = isempty(oneof_names) ? Int[] : zeros(Int, length(dtype.field))
    ismapentry = isfilled(dtype, :options) && isfilled(dtype.options, :map_entry) && dtype.options.map_entry
    map_key_type = ""
    map_val_type = ""

    if isfilled(dtype, :field)
        for fld_idx in 1:length(dtype.field)
            field = dtype.field[fld_idx]
            if isfilled(field, :oneof_index) && !isfilled_default(field, :oneof_index)
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
                    full_typ_name = qualify(typ_name, scope)
                    typ_name = full_typ_name
                    m,t = splitmodule(typ_name)
                    t = chk_keyword(t)
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

            if isfilled(field, :default_value) && !isempty(field.default_value)
                if field._type == FieldDescriptorProto_Type.TYPE_STRING
                    push!(defvals, ":$fldname => \"$(escape_string(field.default_value))\"")
                elseif field._type == FieldDescriptorProto_Type.TYPE_MESSAGE
                    println(errio, "Default values for message types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                elseif field._type == FieldDescriptorProto_Type.TYPE_BYTES
                    println(errio, "Default values for byte array types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                else
                    defval = (field._type == FieldDescriptorProto_Type.TYPE_ENUM) ? "$(field_type_name(enum_typ_name, depends)).$(field.default_value)" : "$(field.default_value)"
                    push!(defvals, ":$fldname => $defval")
                end
            end

            packed = (isfilled(field, :options) && field.options.packed) || 
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

            typ_name = field_type_name(typ_name, depends)
            is_typ_mapentry = typ_name in keys(mapentries)
            if is_typ_mapentry && !_map_as_array
                k,v = mapentries[typ_name]
                typ_name = "Base.Dict{$k,$v}"
            elseif FieldDescriptorProto_Label.LABEL_REPEATED == field.label
                typ_name = "Base.Vector{$typ_name}"
            end

            if isempty(gen_typ_name)
                gen_typ_name = typ_name
            else
                push!(realfldtypes, ":$fldname => \"$(typ_name)\"")
            end

            println(io, "    $(fldname)::$gen_typ_name", is_typ_mapentry ? " # map entry" : "")

            if ismapentry
                if field.number == 1
                    map_key_type = typ_name
                elseif field.number == 2
                    map_val_type = typ_name
                end
            end
        end
    end
    println(io, "    $(dtypename)(; kwargs...) = (o=new(); fillunset(o); isempty(kwargs) || ProtoBuf._protobuild(o, kwargs); o)")
    println(io, "end #mutable struct $(dtypename)", ismapentry ? " (mapentry)" : "")

    # generate the meta for this type if required
    _d_fldnums = [1:length(fldnums);]
    !isempty(reqflds) && println(io, "const __req_$(dtypename) = Symbol[$(join(reqflds, ','))]")
    !isempty(defvals) && println(io, "const __val_$(dtypename) = Dict($(join(defvals, ", ")))")
    (fldnums != _d_fldnums) && println(io, "const __fnum_$(dtypename) = Int[$(join(fldnums, ','))]")
    !isempty(packedflds) && println(io, "const __pack_$(dtypename) = Symbol[$(join(packedflds, ','))]")
    !isempty(wtypes) && println(io, "const __wtype_$(dtypename) = Dict($(join(wtypes, ", ")))")
    !isempty(realfldtypes) && println(io, "const __ftype_$(dtypename) = Dict($(join(realfldtypes, ", ")))")
    if !isempty(oneofs)
        println(io, "const __oneofs_$(dtypename) = Int[$(join(oneofs, ','))]")
        println(io, "const __oneof_names_$(dtypename) = [$(join(oneof_names, ','))]")
    end
    if !isempty(reqflds) || !isempty(defvals) || (fldnums != [1:length(fldnums);]) || !isempty(packedflds) || !isempty(wtypes) || !isempty(oneofs) || !isempty(realfldtypes)
        @logmsg("generating meta for type $(dtypename)")
        print(io, "meta(t::Type{$dtypename}) = meta(t, ")
        print(io, isempty(reqflds) ? "ProtoBuf.DEF_REQ, " : "__req_$(dtypename), ")
        print(io, (fldnums == _d_fldnums) ? "ProtoBuf.DEF_FNUM, " : "__fnum_$(dtypename), ")
        print(io, isempty(defvals) ? "ProtoBuf.DEF_VAL, " : "__val_$(dtypename), ")
        print(io, "true, ")
        print(io, isempty(packedflds) ? "ProtoBuf.DEF_PACK, " : "__pack_$(dtypename), ")
        print(io, isempty(wtypes) ? "ProtoBuf.DEF_WTYPES, " : "__wtype_$(dtypename), ")
        print(io, isempty(oneofs) ? "ProtoBuf.DEF_ONEOFS, " : "__oneofs_$(dtypename), ")
        print(io, isempty(oneofs) ? "ProtoBuf.DEF_ONEOF_NAMES, " : "__oneof_names_$(dtypename), ")
        print(io, isempty(realfldtypes) ? "ProtoBuf.DEF_FIELD_TYPES" : "__ftype_$(dtypename)")
        println(io, ")")
    end
    # generate hash, equality and isequal methods
    println(io, "hash(v::$(dtypename)) = ProtoBuf.protohash(v)")
    println(io, "isequal(v1::$(dtypename), v2::$(dtypename)) = ProtoBuf.protoisequal(v1, v2)")
    println(io, "==(v1::$(dtypename), v2::$(dtypename)) = ProtoBuf.protoeq(v1, v2)")

    println(io, "")
    push!(exports, dtypename)
    ismapentry && (mapentries[dtypename] = (map_key_type, map_val_type))

    deferedmode && (full_dtypename in keys(_deferred)) && delete!(_deferred, full_dtypename)

    if !isdeferred(full_dtypename)
        @logmsg("resolved $full_dtypename")
        print(outio, String(take!(io)))
        resolve(outio, full_dtypename)
        push!(_all_resolved, full_dtypename)
    end
    
    @logmsg("end type $(full_dtypename)")
    nothing
end

function protofile_name_to_module_name(n::AbstractString)
    name = splitext(basename(n))[1]
    name = replace(name, '.', '_')
    name = string(name, "_pb")
    return name
end

function has_gen_services(opt::FileOptions)
    isfilled(opt, :cc_generic_services) && opt.cc_generic_services && return true
    isfilled(opt, :py_generic_services) && opt.py_generic_services && return true
    isfilled(opt, :java_generic_services) && opt.java_generic_services && return true
    return false
end

function generate(io::IO, errio::IO, stype::ServiceDescriptorProto, scope::Scope, svcidx::Int, exports::Vector{AbstractString})
    nmethods = isfilled(stype, :method) ? length(stype.method) : 0

    # generate method and service descriptors
    println(io, "# service methods for $(stype.name)")
    println(io, "const _$(stype.name)_methods = MethodDescriptor[")
    for idx in 1:nmethods
        method = stype.method[idx]
        sm = splitmodule(method.input_type)
        _modul,in_typ_name = (length(sm) > 1) ? (sm[1],sm[2]) : ("",method.input_type)
        sm = splitmodule(method.output_type)
        _modul,out_typ_name = (length(sm) > 1) ? (sm[1],sm[2]) : ("",method.output_type)
        elem_sep = (idx < nmethods) ? "," : ""

        method.client_streaming && (in_typ_name = "Channel{" * in_typ_name * "}")
        method.server_streaming && (out_typ_name = "Channel{" * out_typ_name * "}")

        println(io, "        MethodDescriptor(\"$(method.name)\", $(idx), $(in_typ_name), $(out_typ_name))$(elem_sep)")
    end
    println(io, "    ] # const _$(stype.name)_methods")
    fullservicename = scope.is_module ? pfx(stype.name, scope) : stype.name
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
        sm = splitmodule(method.input_type)
        _modul,in_typ_name = (length(sm) > 1) ? (sm[1],sm[2]) : ("",method.input_type)
        method.client_streaming && (in_typ_name = "Channel{" * in_typ_name * "}")
        println(io, "$(method.name)(stub::$(stub), controller::ProtoRpcController, inp::$(in_typ_name), done::Function) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp, done)")
        println(io, "$(method.name)(stub::$(nbstub), controller::ProtoRpcController, inp::$(in_typ_name)) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp)")
        println(io, "")
        push!(exports, method.name)
    end
    nothing
end

function generate(io::IO, errio::IO, protofile::FileDescriptorProto)
    @logmsg("generate begin for $(protofile.name), package $(protofile.package)")

    svcs = isfilled(protofile, :options) ? has_gen_services(protofile.options) : false
    @logmsg("generate services: $svcs")

    scope = top_scope
    if !isempty(protofile.package)
        for pkgname in split(protofile.package, '.')
            scope = get_module_scope(scope, pkgname)
        end
    end

    push!(scope.files, protofile.name)
    @logmsg("generated scope for $(protofile.name), package $(protofile.package)")

    # generate module begin
    if !isempty(scope.name)
        scope.is_module = true
        _packages[protofile.name] = fullname(scope)
    end

    # generate syntax version
    syntax = (isfilled(protofile, :syntax) && !isempty(protofile.syntax)) ? protofile.syntax : "proto2"
    println(io, "# syntax: $(syntax)")

    depends = AbstractString[]
    @logmsg("generating imports")
    # generate imports
    println(io, "using Compat")
    println(io, "using ProtoBuf")
    println(io, "import ProtoBuf.meta")
    println(io, "import Base: hash, isequal, ==")
    if isfilled(protofile, :dependency)
        protofile_imports[protofile.name] = protofile.dependency
        using_pkgs = Set{AbstractString}()
        for dependency in protofile.dependency
            if haskey(_packages, dependency)
                push!(using_pkgs, _packages[dependency])
                push!(depends, _packages[dependency])
            end
        end
    
        fullscopename = scope.is_module ? fullname(scope) : ""
        parentscope = (isdefined(scope, :parent) && scope.parent.is_module) ? fullname(scope.parent) : ""
        for dependency in using_pkgs
            (fullscopename == dependency) && continue
            !isempty(parentscope) && startswith(dependency, parentscope) && (dependency = ".$(dependency[length(parentscope)+1:end])")
            if dependency == GOOGLE_PROTO3_EXTENSIONS
                dependency = "ProtoBuf"
            else
                comps = split(dependency, '.')
                if !isempty(comps)
                    dependency = comps[1]
                end
            end
            println(io, "import $dependency")
        end
    end
    println(io, "")

    exports = AbstractString[]
    mapentries = Dict{AbstractString, Tuple{AbstractString,AbstractString}}()

    # generate top level enums
    @logmsg("generating enums")
    if isfilled(protofile, :enum_type)
        for enum_type in protofile.enum_type
            generate(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return 
        end
    end

    # generate message types
    @logmsg("generating types")
    if isfilled(protofile, :message_type)
        for message_type in protofile.message_type
            generate(io, errio, message_type, scope, syntax, exports, depends, mapentries, false)
            (errio.size > 0) && return
        end
    end

    # generate service stubs
    @logmsg("generating services")
    if svcs && isfilled(protofile, :service)
        nservices = length(protofile.service)
        for idx in 1:nservices
            service = protofile.service[idx]
            generate(io, errio, service, scope, idx, exports)
            (errio.size > 0) && return
        end
    end

    # generate deferred message types
    @logmsg("generating deferred types")
    if isfilled(protofile, :message_type)
        for message_type in protofile.message_type
            generate(io, errio, message_type, scope, syntax, exports, depends, mapentries, true)
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

    @logmsg("generate end for $(protofile.name)")
    nothing
end

function append_response(resp::CodeGeneratorResponse, protofile::FileDescriptorProto, io::IOBuffer)
    outdir = dirname(protofile.name)
    filename = protofile_name_to_module_name(protofile.name)
    filename = string(filename, ".jl")

    append_response(resp, filename, io)
end

function append_response(resp::CodeGeneratorResponse, filename::AbstractString, io::IOBuffer)
    jfile = ProtoBuf.instantiate(CodeGeneratorResponse_File)

    jfile.name = filename
    jfile.content = String(take!(io))

    !isdefined(resp, :file) && (resp.file = CodeGeneratorResponse_File[])
    push!(resp.file, jfile)
    resp
end

function err_response(errio::IOBuffer)
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    resp.error = String(take!(errio))
    resp
end

scope_has_file(s::Scope, f::AbstractString) = (f in s.files || any(x->scope_has_file(x,f), s.children))

function print_package(io::IO, s::Scope, indent="")
    s.is_module || return
    println(io, "$(indent)module $(s.name)")
    nested = indent*"  "
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

function codegen(srcio::IO)
    errio = IOBuffer()
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    @logmsg("generate begin")
    while !eof(srcio)
        req = readreq(srcio)

        if !isfilled(req, :file_to_generate)
            @logmsg("no files to generate!!")
            continue
        end

        @logmsg("generate request for $(length(req.file_to_generate)) proto files")
        @logmsg("$(req.file_to_generate)")

        #isfilled(req, :parameter) && @logmsg("parameter $(req.parameter)")

        for protofile in req.proto_file
            io = IOBuffer()
            generate(io, errio, protofile)
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
    @logmsg("generate end")
    resp
end


##
# the main read - write method
function gen()
    try
        global _module_postfix = in("--module-postfix-enabled", ARGS)
        global _map_as_array = in("--map-as-array", ARGS)
        writeproto(STDOUT, codegen(STDIN))
    catch ex
        println(STDERR, "Exception while generating Julia code")
        rethrow()
    end
end

end # module Gen
