module Gen

using ProtoBuf

import ProtoBuf.meta, ProtoBuf.logmsg

export gen

include("gen_descriptor_protos.jl")
include("gen_plugin_protos.jl")

const _packages = Dict{String,String}()


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
    function Scope(name::String, parent::Scope)
        s = new()
        s.name = name
        s.syms = String[]
        s.parent = parent
        s.is_module = false
        s
    end
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
    req = CodeGeneratorRequest()
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

function generate(io::IO, errio::IO, enumtype::EnumDescriptorProto, scope::Scope)
    enumname = pfx(enumtype.name, scope)
    sm = splitmodule(enumname)
    (length(sm) > 1) && (enumname = sm[2])
    push!(scope.syms, enumtype.name)

    logmsg("begin enum $(enumname)")
    println(io, "type __enum_$(enumname)")
    values = Int32[]
    for value::EnumValueDescriptorProto in enumtype.value
        println(io, "    $(value.name)::Int32")
        push!(values, value.number)
    end
    println(io, "    __enum_$(enumname)() = new($(join(values,',')))")
    println(io, "end #type __enum_$(enumname)")
    println(io, "const $(enumname) = __enum_$(enumname)()")
    println(io, "")
    logmsg("end enum $(enumname)")
end

function generate(io::IO, errio::IO, dtype::DescriptorProto, scope::Scope)
    dtypename = pfx(dtype.name, scope)
    sm = splitmodule(dtypename)
    modul,dtypename = (length(sm) > 1) ? (sm[1],sm[2]) : ("",dtypename)
    logmsg("begin type $(dtypename)")

    scope = Scope(dtypename, scope)
    # generate enums
    if filled(dtype, :enum_type)
        for enum_type in dtype.enum_type
            generate(io, errio, enum_type, scope)
            (errio.size > 0) && return 
        end
    end

    # generate nested types
    if filled(dtype, :nested_type)
        for nested_type::DescriptorProto in dtype.nested_type
            generate(io, errio, nested_type, scope)
            (errio.size > 0) && return 
        end
    end

    # generate this type
    println(io, "type $(dtypename)")
    reqflds = String[]
    fldnums = Int[]
    defvals = String[]
    for field::FieldDescriptorProto in dtype.field
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

        if filled(field, :default_value) && !isempty(field.default_value)
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

        (LABEL_REPEATED == field.label) && (typ_name = "Array{$typ_name,1}")
        println(io, "    $(field.name)::$typ_name")
    end
    println(io, "    $(dtypename)() = new()")
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
    if filled(protofile, :dependency) && !isempty(protofile.dependency)
        for dependency in protofile.dependency
            println(io, "using $(_packages[dependency])")
        end
    end
    println(io, "")
    println(io, "using ProtoBuf")
    println(io, "import ProtoBuf.meta")
    println(io, "")

    # generate top level enums
    logmsg("generating enums")
    if filled(protofile, :enum_type)
        for enum_type in protofile.enum_type
            generate(io, errio, enum_type, scope)
            (errio.size > 0) && return 
        end
    end

    # generate message types
    logmsg("generating types")
    if filled(protofile, :message_type)
        for message_type in protofile.message_type
            generate(io, errio, message_type, scope)
            (errio.size > 0) && return 
        end
    end

    # generate module end
    if !isempty(scope.name)
        println(io, "end # module $(scope.name)")
    end

    logmsg("generate end for $(protofile.name)")
end

function append_response(resp::CodeGeneratorResponse, protofile::FileDescriptorProto, io::IOBuffer)
    jfile = CodeGenFile()

    jfile.name = join([splitext(protofile.name)[1],"jl"], '.')
    jfile.content = takebuf_string(io)

    !isdefined(resp, :file) && (resp.file = CodeGenFile[])
    push!(resp.file, jfile)
    resp
end

function err_response(errio::IOBuffer)
    resp = CodeGeneratorResponse()
    resp.error = takebuf_string(errio)
    resp
end

function generate(srcio::IO)
    errio = IOBuffer()
    resp = CodeGeneratorResponse()
    logmsg("generate begin")
    while !eof(srcio)
        req = readreq(srcio)

        if !filled(req, :file_to_generate)
            logmsg("no files to generate!!")
            continue
        end

        logmsg("generate request for $(length(req.file_to_generate)) proto files")
        logmsg("$(req.file_to_generate)")

        filled(req, :parameter) && logmsg("parameter $(req.parameter)")

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
function gen(instream, outstream, errstream)
    try
        writeproto(STDOUT, generate(STDIN))
    catch ex
        println(STDERR, "Exception while generating Julia code")
        println(STDERR, ex)
        exit(-1)
    end
end
gen()=gen(STDIN, STDOUT, STDERR)

end # module Gen

