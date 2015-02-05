module Gen

using ProtoBuf
using Compat

import ProtoBuf: meta, logmsg, DEF_REQ, DEF_FNUM, DEF_VAL, DEF_PACK

export gen

if isless(Base.VERSION, v"0.4.0-")
typealias AbstractString String
end

include("gen_descriptor_protos.jl")
include("gen_plugin_protos.jl")

# maps protofile name to package name
const _packages = Dict{AbstractString,AbstractString}()

# maps protofile name to array of imported protofiles
const protofile_imports = Dict()

const _keywords = [
    "if", "else", "elseif", "while", "for", "begin", "end", "quote", 
    "try", "catch", "return", "local", "abstract", "function", "macro",
    "ccall", "finally", "typealias", "break", "continue", "type", 
    "global", "module", "using", "import", "export", "const", "let", 
    "bitstype", "do", "baremodule", "importall", "immutable"
]

type DeferredWrite
    iob::IOBuffer
    depends::Array{AbstractString,1}
end
const _deferred = Dict{AbstractString,DeferredWrite}()
# set of fully-qualified names we've resolved, to handle dependencies in other files
const _all_resolved = Set{AbstractString}()

function defer(name::AbstractString, iob::IOBuffer, depends::AbstractString)
    if isdeferred(name)
        depsnow = _deferred[name].depends
        !(depends in depsnow) && push!(depsnow, depends)
        return
    end
    _deferred[name] = DeferredWrite(iob, AbstractString[depends])
    nothing
end

isdeferred(name::AbstractString) = haskey(_deferred, name)
function isresolved(dtypename::AbstractString, referenced_name::AbstractString, exports::Array{AbstractString,1})
    (dtypename == referenced_name) && return true
    for jtype in JTYPES
        (referenced_name == string(jtype)) && return true
    end
    (('.' in referenced_name) || (referenced_name in exports)) && !haskey(_deferred, referenced_name)
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
        #logmsg("resolved $typ")
        print(iob, takebuf_string(_deferred[typ].iob))
        delete!(_deferred, typ)
    end

    # mark them resolved as well
    for typ in fully_resolved
        resolve(iob, typ)
    end
end

chk_keyword(name::AbstractString) = (name in _keywords) ? string('_', name) : name

type Scope
    name::AbstractString
    syms::Array{AbstractString,1}
    files::Array{AbstractString,1}
    is_module::Bool
    children::Array{Scope,1}
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
        if (length(pkg) > mlen) && startswith(name, pkg)
            mlen = length(pkg)
            mpkg = pkg
        end
    end
    (mpkg, replace((0 == mlen) ? name : name[(mlen+2):end], '.', '_'))
end

function generate(io::IO, errio::IO, enumtype::EnumDescriptorProto, scope::Scope, exports::Array{AbstractString,1})
    enumname = pfx(enumtype.name, scope)
    sm = splitmodule(enumname)
    (length(sm) > 1) && (enumname = sm[2])
    push!(scope.syms, enumtype.name)

    #logmsg("begin enum $(enumname)")
    println(io, "type __enum_$(enumname) <: ProtoEnum")
    values = Int32[]
    for value::EnumValueDescriptorProto in enumtype.value
        # If we find that the field name is a keyword prepend it with _type
        fldname = chk_keyword(value.name)
        println(io, "    $(fldname)::Int32")
        push!(values, value.number)
    end
    println(io, "    __enum_$(enumname)() = new($(join(values,',')))")
    println(io, "end #type __enum_$(enumname)")
    println(io, "const $(enumname) = __enum_$(enumname)()")
    println(io, "")
    push!(exports, enumname)
    #logmsg("end enum $(enumname)")
end

function short_type_name(full_type_name::AbstractString, depends::Array{AbstractString,1})
    comps = split(full_type_name, '.')
    type_name = pop!(comps)
    while !isempty(comps) && !(join(comps, '.') in depends)
        type_name = (pop!(comps) * "." * type_name)
    end
    #logmsg("check $full_type_name against $depends || found $type_name")
    return type_name
end

function generate(outio::IO, errio::IO, dtype::DescriptorProto, scope::Scope, exports::Array{AbstractString,1}, depends::Array{AbstractString,1})
    io = IOBuffer()
    full_dtypename = dtypename = pfx(dtype.name, scope)
    sm = splitmodule(dtypename)
    modul,dtypename = (length(sm) > 1) ? (sm[1],sm[2]) : ("",dtypename)
    #logmsg("begin type $(dtypename)")

    scope = Scope(dtype.name, scope)
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
            generate(io, errio, nested_type, scope, exports, depends)
            (errio.size > 0) && return
        end
    end

    # generate this type
    println(io, "type $(dtypename)")
    reqflds = AbstractString[]
    packedflds = AbstractString[]
    fldnums = Int[]
    defvals = AbstractString[]
    wtypes = AbstractString[]

    if isfilled(dtype, :field)
        for field::FieldDescriptorProto in dtype.field
            # If we find that the field name is a keyword prepend it with _type
            fldname = chk_keyword(field.name)
            if field.typ == TYPE_GROUP
                println(errio, "Groups are not supported")
                return
            end

            full_typ_name = ""
            if (field.typ == TYPE_MESSAGE) || (field.typ == TYPE_ENUM)
                typ_name = field.typ_name
                if startswith(typ_name, '.')
                    (m,t) = findmodule(typ_name[2:end])
                    full_typ_name = m=="" ? t : "$(m).$(t)"
                    typ_name = (m == modul) ? t : full_typ_name
                else
                    full_typ_name = qualify(typ_name, scope)
                    typ_name = full_typ_name
                    m,t = splitmodule(typ_name)
                    (m == modul) && (typ_name = t)
                end
            elseif field.typ == TYPE_SINT32
                push!(wtypes, ":$fldname => :sint32")
            elseif field.typ == TYPE_SINT64
                push!(wtypes, ":$fldname => :sint64")
            end
            enum_typ_name = (field.typ == TYPE_ENUM) ? typ_name : ""
            (field.typ != TYPE_MESSAGE) && (typ_name = "$(JTYPES[field.typ])")

            push!(fldnums, field.number)
            (LABEL_REQUIRED == field.label) && push!(reqflds, ":"*fldname)

            if isfilled(field, :default_value) && !isempty(field.default_value)
                if field.typ == TYPE_STRING
                    push!(defvals, ":$fldname => \"$(escape_string(field.default_value))\"")
                elseif field.typ == TYPE_MESSAGE
                    println(errio, "Default values for message types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                elseif field.typ == TYPE_BYTES
                    println(errio, "Default values for byte array types are not supported. Field: $(dtypename).$(fldname) has default value [$(field.default_value)]")
                    return
                else
                    defval = (field.typ == TYPE_ENUM) ? "$(enum_typ_name).$(field.default_value)" : "$(field.default_value)"
                    push!(defvals, ":$fldname => $defval")
                end
            end

            isfilled(field, :options) && field.options.packed && push!(packedflds, ":"*fldname)

            if !(isresolved(dtypename, typ_name, exports) || full_typ_name in _all_resolved)
                defer(dtypename, io, typ_name)
            end

            typ_name = short_type_name(typ_name, depends)
            (LABEL_REPEATED == field.label) && (typ_name = "Array{$typ_name,1}")
            println(io, "    $(fldname)::$typ_name")
        end
    end
    println(io, "    $(dtypename)() = (o=new(); fillunset(o); o)")
    println(io, "end #type $(dtypename)")

    # generate the meta for this type if required
    _d_fldnums = [1:length(fldnums)]
    !isempty(reqflds) && println(io, "const __req_$(dtypename) = Symbol[$(join(reqflds, ','))]")
    !isempty(defvals) && println(io, "const __val_$(dtypename) = @compat Dict($(join(defvals, ", ")))")
    (fldnums != _d_fldnums) && println(io, "const __fnum_$(dtypename) = Int[$(join(fldnums, ','))]")
    !isempty(packedflds) && println(io, "const __pack_$(dtypename) = Symbol[$(join(packedflds, ','))]")
    !isempty(wtypes) && println(io, "const __wtype_$(dtypename) = @compat Dict($(join(wtypes, ", ")))")
    if !isempty(reqflds) || !isempty(defvals) || (fldnums != [1:length(fldnums)]) || !isempty(packedflds) || !isempty(wtypes)
        #logmsg("generating meta for type $(dtypename)")
        print(io, "meta(t::Type{$dtypename}) = meta(t, ")
        print(io, isempty(reqflds) ? "ProtoBuf.DEF_REQ, " : "__req_$(dtypename), ")
        print(io, (fldnums == _d_fldnums) ? "ProtoBuf.DEF_FNUM, " : "__fnum_$(dtypename), ")
        print(io, isempty(defvals) ? "ProtoBuf.DEF_VAL, " : "__val_$(dtypename), ")
        print(io, "true, ")
        print(io, isempty(packedflds) ? "ProtoBuf.DEF_PACK, " : "__pack_$(dtypename), ")
        print(io, isempty(wtypes) ? "ProtoBuf.DEF_WTYPES" : "__wtype_$(dtypename)")
        println(io, ")")
    end

    println(io, "")
    push!(exports, dtypename)

    if !isdeferred(dtypename)
        #logmsg("resolved $dtypename")
        print(outio, takebuf_string(io))
        resolve(outio, dtypename)
        push!(_all_resolved, full_dtypename)
    end
    
    #logmsg("end type $(dtypename)")
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

function generate(io::IO, errio::IO, stype::ServiceDescriptorProto, svcidx::Int, exports::Array{AbstractString,1})
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
        println(io, "        MethodDescriptor(\"$(method.name)\", $(idx), $(in_typ_name), $(out_typ_name))$(elem_sep)")
    end
    println(io, "    ] # const _$(stype.name)_methods")
    println(io, "const _$(stype.name)_desc = ServiceDescriptor(\"$(stype.name)\", $(svcidx), _$(stype.name)_methods)")
    println(io, "")

    # generate service
    println(io, "$(stype.name)(impl::Module) = ProtoService(_$(stype.name)_desc, impl)")
    println(io, "")
    push!(exports, stype.name)

    # generate stubs
    stub = "$(stype.name)Stub"
    println(io, "type $(stub) <: AbstractProtoServiceStub{false}")
    println(io, "    impl::ProtoServiceStub")
    println(io, "    $(stub)(channel::ProtoRpcChannel) = new(ProtoServiceStub(_$(stype.name)_desc, channel))")
    println(io, "end # type $(stub)")
    println(io, "")
    push!(exports, stub)

    nbstub = "$(stype.name)BlockingStub"
    println(io, "type $(nbstub) <: AbstractProtoServiceStub{true}")
    println(io, "    impl::ProtoServiceBlockingStub")
    println(io, "    $(nbstub)(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_$(stype.name)_desc, channel))")
    println(io, "end # type $(nbstub)")
    println(io, "")
    push!(exports, nbstub)

    for idx in 1:nmethods
        method = stype.method[idx]
        sm = splitmodule(method.input_type)
        _modul,in_typ_name = (length(sm) > 1) ? (sm[1],sm[2]) : ("",method.input_type)
        println(io, "$(method.name)(stub::$(stub), controller::ProtoRpcController, inp::$(in_typ_name), done::Function) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp, done)")
        println(io, "$(method.name)(stub::$(nbstub), controller::ProtoRpcController, inp::$(in_typ_name)) = call_method(stub.impl, _$(stype.name)_methods[$(idx)], controller, inp)")
        println(io, "")
        push!(exports, method.name)
    end
end

function generate(io::IO, errio::IO, protofile::FileDescriptorProto)
    #logmsg("generate begin for $(protofile.name), package $(protofile.package)")

    svcs = isfilled(protofile, :options) ? has_gen_services(protofile.options) : false
    #logmsg("generate services: $svcs")

    scope = top_scope
    if !isempty(protofile.package)
        for pkgname in split(protofile.package, '.')
            scope = get_module_scope(scope, pkgname)
        end
    end

    push!(scope.files, protofile.name)
    #logmsg("generated scope for $(protofile.name), package $(protofile.package)")

    # generate module begin
    if !isempty(scope.name)
        scope.is_module = true
        _packages[protofile.name] = fullname(scope)
    end

    depends = AbstractString[]
    #logmsg("generating imports")
    # generate imports
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
            println(io, "using $dependency")
        end
    end
    println(io, "using Compat")
    println(io, "using ProtoBuf")
    println(io, "import ProtoBuf.meta")
    println(io, "")

    exports = AbstractString[]

    # generate top level enums
    #logmsg("generating enums")
    if isfilled(protofile, :enum_type)
        for enum_type in protofile.enum_type
            generate(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return 
        end
    end

    # generate message types
    #logmsg("generating types")
    if isfilled(protofile, :message_type)
        for message_type in protofile.message_type
            generate(io, errio, message_type, scope, exports, depends)
            (errio.size > 0) && return 
        end
    end

    # generate service stubs
    #logmsg("generating services")
    if svcs && isfilled(protofile, :service)
        nservices = length(protofile.service)
        for idx in 1:nservices
            service = protofile.service[idx]
            generate(io, errio, service, idx, exports)
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
    !isempty(exports) && println(io, "export " * join(exports, ", "))

    #logmsg("generate end for $(protofile.name)")
end

function append_response(resp::CodeGeneratorResponse, protofile::FileDescriptorProto, io::IOBuffer)
    outdir = dirname(protofile.name)
    filename = protofile_name_to_module_name(protofile.name)
    filename = string(filename, ".jl")

    append_response(resp, filename, io)
end

function append_response(resp::CodeGeneratorResponse, filename::AbstractString, io::IOBuffer)
    jfile = ProtoBuf.instantiate(CodeGenFile)

    jfile.name = filename
    jfile.content = takebuf_string(io)

    !isdefined(resp, :file) && (resp.file = CodeGenFile[])
    push!(resp.file, jfile)
    resp
end

function err_response(errio::IOBuffer)
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    resp.error = takebuf_string(errio)
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

function generate(srcio::IO)
    errio = IOBuffer()
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    #logmsg("generate begin")
    while !eof(srcio)
        req = readreq(srcio)

        if !isfilled(req, :file_to_generate)
            #logmsg("no files to generate!!")
            continue
        end

        #logmsg("generate request for $(length(req.file_to_generate)) proto files")
        #logmsg("$(req.file_to_generate)")

        #isfilled(req, :parameter) && logmsg("parameter $(req.parameter)")

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
    #logmsg("generate end")
    resp
end


##
# the main read - write method
function gen()
    try
        writeproto(STDOUT, generate(STDIN))
    catch ex
        println(STDERR, "Exception while generating Julia code")
        rethrow()
    end
end

end # module Gen
