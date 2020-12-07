# utility methods

isinitialized(obj::Any) = isfilled(obj)

function copy!(to::T, from::T) where T <: ProtoType
    clear(to)
    for name in propertynames(from)
        hasproperty(from, name) && setproperty!(to, name, getproperty(from, name))
    end
    nothing
end

function deepcopy(from::T) where T <: ProtoType
    to = T()
    for name in propertynames(from)
        hasproperty(from, name) && setproperty!(to, name, deepcopy(getproperty(from, name)))
    end
    to
end

# hash method that considers fill status of types
function hash(v::T) where {T<:ProtoType}
    h = 0
    for name in propertynames(v)
        hasproperty(v, name) && (h += hash(getproperty(v, name)))
    end
    hash(h)
end

# equality method that considers fill status of types
function ==(v1::T, v2::T) where {T<:ProtoType}
    for name in propertynames(v1)
        (hasproperty(v1, name) === hasproperty(v2, name)) || (return false)
        if hasproperty(v1, name)
            (getproperty(v1, name) == getproperty(v2, name)) || (return false)
        end
    end
    true
end

# isequal method that considers fill status of types
function isequal(v1::T, v2::T) where {T<:ProtoType}
    for name in propertynames(v1)
        (hasproperty(v1, name) === hasproperty(v2, name)) || (return false)
        if hasproperty(v1, name)
            isequal(getproperty(v1, name), getproperty(v2, name)) || (return false)
        end
    end
    true
end

function enumstr(enumname::T, t::Int32) where {T <: NamedTuple}
    for name in propertynames(enumname)
        (getproperty(enumname, name) == t) && (return string(name))
    end
    error(string("Invalid enum value ", t))
end

import protoc_jll
function protoc(args=``)
    plugin_dir = abspath(joinpath(dirname(pathof(ProtoBuf)), "..", "plugin"))
    plugin = joinpath(plugin_dir, Sys.iswindows() ? "protoc-gen-julia_win.bat" : "protoc-gen-julia")

    protoc_jll.protoc() do protoc_path
        ENV′ = copy(ENV)
        ENV′["PATH"] = string(plugin_dir, Sys.iswindows() ? ";" : ":", ENV′["PATH"])
        ENV′["JULIA"] = joinpath(Sys.BINDIR, Base.julia_exename())
        run(setenv(`$protoc_path --plugin=protoc-gen-julia=$plugin $args`, ENV′))
    end
end
