# utility methods

isinitialized(obj::Any) = isfilled(obj)

set_field!(obj::Any, fld::Symbol, val) = (setfield!(obj, fld, val); fillset(obj, fld); nothing)
@deprecate set_field(obj::Any, fld::Symbol, val) set_field!(obj, fld, val)

get_field(obj::Any, fld::Symbol) = isfilled(obj, fld) ? getfield(obj, fld) : error("uninitialized field $fld")

clear = fillunset

has_field(obj::Any, fld::Symbol) = isfilled(obj, fld)

function copy!{T}(to::T, from::T)
    fillunset(to)
    for name in @compat fieldnames(T)
        if isfilled(from, name)
            set_field!(to, name, getfield(from, name))
        end
    end
    nothing
end

function add_field!(obj::Any, fld::Symbol, val)
    typ = typeof(obj)
    attrib = meta(typ).symdict[fld]
    (attrib.occurrence != 2) && error("$(typ).$(fld) is not a repeating field")

    ptyp = attrib.ptyp
    jtyp = WIRETYPES[ptyp][4]
    (ptyp == :obj) && (jtyp = attrib.meta.jtype)

    !isdefined(obj, fld) && setfield!(obj, fld, jtyp[])
    push!(getfield(obj, fld), val)
    nothing
end
@deprecate add_field(obj::Any, fld::Symbol, val) add_field!(obj, fld, val)

protobuild{T}(::Type{T}, nv::Dict{Symbol}=Dict{Symbol,Any}()) = _protobuild(T(), collect(nv))

function _protobuild{T}(obj::T, nv)
    for (n,v) in nv
        fldtyp = fld_type(obj, n)
        set_field!(obj, n, isa(v, fldtyp) ? v : convert(fldtyp, v))
    end
    obj
end

# hash method that considers fill status of types
function protohash(v)
    h = 0
    for f in fieldnames(v)
        isfilled(v, f) && (h += hash(getfield(v, f)))
    end
    hash(h)
end

# equality method that considers fill status of types
function protoeq{T}(v1::T, v2::T)
    for f in fieldnames(v1)
        (isfilled(v1, f) == isfilled(v2, f)) || (return false)
        if isfilled(v1, f)
            (getfield(v1,f) == getfield(v2,f)) || (return false)
        end
    end
    true
end

# isequal method that considers fill status of types
function protoisequal{T}(v1::T, v2::T)
    for f in fieldnames(v1)
        (isfilled(v1, f) == isfilled(v2, f)) || (return false)
        if isfilled(v1, f)
            isequal(getfield(v1,f), getfield(v2,f)) || (return false)
        end
    end
    true
end
