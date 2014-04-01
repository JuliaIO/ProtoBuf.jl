module Gen

using ProtoBuf

import ProtoBuf.meta, ProtoBuf.logmsg

export gen

include("gen_descriptor_protos.jl")
include("gen_plugin_protos.jl")

const _packages = Dict{String,String}()

type DeferredWrite
    iob::IOBuffer
    depends::Array{String,1}
end
const _deferred = Dict{String,DeferredWrite}()

function defer(name::String, iob::IOBuffer, depends::String)
    if isdeferred(name)
        depsnow = _deferred[name].depends
        !(depends in depsnow) && push!(depsnow, depends)
        return
    end
    _deferred[name] = DeferredWrite(iob, String[depends])
    nothing
end

isdeferred(name::String) = haskey(_deferred, name)
function isresolved(dtypename::String, referenced_name::String, exports::Array{String,1})
    (dtypename == referenced_name) && return true
    for jtype in JTYPES
        (referenced_name == string(jtype)) && return true
    end
    ('.' in referenced_name) || (referenced_name in exports)
end

function resolve(iob::IOBuffer, name::String)
    fully_resolved = String[]
    for (typ,dw) in _deferred
        idx = findfirst(dw.depends, name)
        (idx == 0) && continue
        splice!(dw.depends, idx)
        isempty(dw.depends) && push!(fully_resolved, typ)
    end

    # write all fully resolved entities
    for typ in fully_resolved
        logmsg("resolved $typ")
        print(iob, takebuf_string(_deferred[typ].iob))
        delete!(_deferred, typ)
    end

    # mark them resolved as well
    for typ in fully_resolved
        resolve(iob, typ)
    end
end

type Scope
    name::String
    syms::Array{String,1}
    parent::Scope
    is_module::Bool

    function Scope(name::String)
        s = new()
        s.name = name
        s.syms = String[]
        s.is_module = false
        s
    end
    Scope(name::String, parent::Scope) = new(name, String[], parent, false)
end

function qualify(name::String, scope::Scope) 
    if name in scope.syms
        return pfx(name, scope) 
    elseif isdefined(scope, parent) 
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

pfx(name::String, scope::Scope) = isempty(scope.name) ? name : (scope.name * (scope.is_module ? "." : "_") * name)
splitmodule(name::String) = split(name, '.')
function findmodule(name::String)
    name = replace(name[2:end], '.', '_')
    mlen = 0
    mpkg = ""
    for pkg in values(_packages)
        if (length(pkg) > mlen) && beginswith(name, pkg)
            mlen = length(pkg)
            mpkg = pkg
        end
    end
    (mpkg, (0 == mlen) ? name : name[(mlen+2):end])
end

function generate(io::IO, errio::IO, enumtype::EnumDescriptorProto, scope::Scope, exports::Array{String,1})
    enumname = pfx(enumtype.name, scope)
    sm = splitmodule(enumname)
    (length(sm) > 1) && (enumname = sm[2])
    push!(scope.syms, enumtype.name)

    logmsg("begin enum $(enumname)")
    println(io, "type __enum_$(enumname) <: ProtoEnum")
    values = Int32[]
    for value::EnumValueDescriptorProto in enumtype.value
        println(io, "    $(value.name)::Int32")
        push!(values, value.number)
    end
    println(io, "    __enum_$(enumname)() = new($(join(values,',')))")
    println(io, "end #type __enum_$(enumname)")
    println(io, "const $(enumname) = __enum_$(enumname)()")
    println(io, "")
    push!(exports, enumname)
    logmsg("end enum $(enumname)")
end

function generate(outio::IO, errio::IO, dtype::DescriptorProto, scope::Scope, exports::Array{String,1})
    io = IOBuffer()
    dtypename = pfx(dtype.name, scope)
    sm = splitmodule(dtypename)
    modul,dtypename = (length(sm) > 1) ? (sm[1],sm[2]) : ("",dtypename)
    logmsg("begin type $(dtypename)")

    scope = Scope(dtypename, scope)
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
            generate(io, errio, nested_type, scope, exports)
            (errio.size > 0) && return 
        end
    end

    # generate this type
    println(io, "type $(dtypename)")
    reqflds = String[]
    fldnums = Int[]
    defvals = String[]

    if isfilled(dtype, :field)
        for field::FieldDescriptorProto in dtype.field
            # If we find that the field name is type change it to _type, this could
            # probably be done for other field names that are also keywords in
            # Julia.
            if field.name == "type"
                field.name = "_type"
            end
            fldname = field.name
            if field.typ == TYPE_GROUP
                println(errio, "Groups are not supported")
                return
            end

            if (field.typ == TYPE_MESSAGE) || (field.typ == TYPE_ENUM)
                typ_name = field.typ_name
                if beginswith(typ_name, '.')
                    (m,t) = findmodule(typ_name)
                    typ_name = (m == modul) ? t : "$(m).$(t)"
                else
                    typ_name = qualify(typ_name, scope)
                    m,t = splitmodule(typ_name)
                    (m == modul) && (typ_name = t)
                end
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

            !isresolved(dtypename, typ_name, exports) && defer(dtypename, io, typ_name)

            (LABEL_REPEATED == field.label) && (typ_name = "Array{$typ_name,1}")
            println(io, "    $(field.name)::$typ_name")
        end
    end
    println(io, "    $(dtypename)() = (o=new(); fillunset(o); o)")
    println(io, "end #type $(dtypename)")

    # generate the meta for this type if required
    if !isempty(reqflds) || !isempty(defvals) || (fldnums != [1:length(fldnums)])
        logmsg("generating meta for type $(dtypename)")
        print(io, "meta(t::Type{$dtypename}) = meta(t, Symbol[")
        !isempty(reqflds) && print(io, join(reqflds, ','))
        print(io, "], Int[")
        (fldnums != [1:length(fldnums)]) && print(io, join(fldnums, ','))
        print(io, "], ")
        if !isempty(defvals)
            print(io, "[" * join(defvals, ',') * "]")
        else
            print(io, "Dict{Symbol,Any}()")
        end
        println(io, ")")
    end

    println(io, "")
    push!(exports, dtypename)

    if !isdeferred(dtypename)
        logmsg("resolved $dtypename")
        print(outio, takebuf_string(io))
        resolve(outio, dtypename)
    end
    
    logmsg("end type $(dtypename)")
end

function generate(io::IO, errio::IO, protofile::FileDescriptorProto)
    logmsg("generate begin for $(protofile.name), package $(protofile.package)")

    scope = Scope("")
    for pkgpart in split(protofile.package, '.')
        scope = Scope(isempty(scope.name) ? pkgpart : "$(scope.name)_$(pkgpart)", scope)
    end
    logmsg("generated scope for $(protofile.name), package $(protofile.package)")

    # generate module begin
    if !isempty(scope.name)
        scope.is_module = true
        println(io, "module $(scope.name)")
        println(io, "")
        _packages[protofile.name] = scope.name
    end

    logmsg("generating imports")
    # generate imports
    if isfilled(protofile, :dependency) && !isempty(protofile.dependency)
        for dependency in protofile.dependency
            println(io, "using $(_packages[dependency])")
        end
    end
    println(io, "")
    println(io, "using ProtoBuf")
    println(io, "import ProtoBuf.meta")
    println(io, "")

    exports = String[]

    # generate top level enums
    logmsg("generating enums")
    if isfilled(protofile, :enum_type)
        for enum_type in protofile.enum_type
            generate(io, errio, enum_type, scope, exports)
            (errio.size > 0) && return 
        end
    end

    # generate message types
    logmsg("generating types")
    if isfilled(protofile, :message_type)
        for message_type in protofile.message_type
            generate(io, errio, message_type, scope, exports)
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
    println(io, "export meta")

    # generate module end
    if !isempty(scope.name)
        println(io, "end # module $(scope.name)")
    end

    logmsg("generate end for $(protofile.name)")
end

function append_response(resp::CodeGeneratorResponse, protofile::FileDescriptorProto, io::IOBuffer)
    jfile = ProtoBuf.instantiate(CodeGenFile)

    outdir = dirname(protofile.name)
    filename = splitext(basename(protofile.name))[1]
    filename = replace(filename, '.', '_')
    filename = join([filename, "jl"], '.')
    jfile.name = joinpath(outdir, filename)
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

function generate(srcio::IO)
    errio = IOBuffer()
    resp = ProtoBuf.instantiate(CodeGeneratorResponse)
    logmsg("generate begin")
    while !eof(srcio)
        req = readreq(srcio)

        if !isfilled(req, :file_to_generate)
            logmsg("no files to generate!!")
            continue
        end

        logmsg("generate request for $(length(req.file_to_generate)) proto files")
        logmsg("$(req.file_to_generate)")

        isfilled(req, :parameter) && logmsg("parameter $(req.parameter)")

        for protofile in req.proto_file
            io = IOBuffer()
            generate(io, errio, protofile)
            (errio.size > 0) && return err_response(errio)
            append_response(resp, protofile, io)
        end
    end
    logmsg("generate end")
    resp
end


##
# the main read - write method
function gen()
    try
        writeproto(STDOUT, generate(STDIN))
    catch ex
        println(STDERR, "Exception while generating Julia code")
        println(STDERR, ex)
        exit(-1)
    end
end

end # module Gen

