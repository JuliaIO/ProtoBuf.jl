# utility methods

isinitialized(obj::Any) = isfilled(obj)

set_field!(obj::Any, fld::Symbol, val) = (setfield!(obj, fld, val); fillset(obj, fld); nothing)
@deprecate set_field(obj::Any, fld::Symbol, val) set_field!(obj, fld, val)

get_field(obj::Any, fld::Symbol) = isfilled(obj, fld) ? getfield(obj, fld) : error("uninitialized field $fld")

clear = fillunset

has_field(obj::Any, fld::Symbol) = isfilled(obj, fld)

function copy!{T}(to::T, from::T)
    fillunset(to)
    fill = filled(from)
    fnames = fld_names(T)
    for idx in 1:length(fnames)
        if fill[1, idx]
            name = fnames[idx]
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
    fill = filled(v)
    fnames = fld_names(typeof(v))
    for idx in 1:length(fnames)
        fill[1, idx] && (h += hash(getfield(v, fnames[idx])))
    end
    hash(h)
end

# equality method that considers fill status of types
function protoeq{T}(v1::T, v2::T)
    fillv1 = filled(v1)
    fillv2 = filled(v2)
    fnames = fld_names(T)
    for idx in 1:length(fnames)
        (fillv1[1,idx] == fillv2[1,idx]) || (return false)
        if fillv1[1,idx]
            f = fnames[idx]
            (getfield(v1,f) == getfield(v2,f)) || (return false)
        end
    end
    true
end

# isequal method that considers fill status of types
function protoisequal{T}(v1::T, v2::T)
    fillv1 = filled(v1)
    fillv2 = filled(v2)
    fnames = fld_names(T)
    for idx in 1:length(fnames)
        (fillv1[1,idx] == fillv2[1,idx]) || (return false)
        if fillv1[1,idx]
            f = fnames[idx]
            isequal(getfield(v1,f), getfield(v2,f)) || (return false)
        end
    end
    true
end

function enumstr(enumname, t::Int32)
    for name in fld_names(typeof(enumname))
        (getfield(enumname, name) == t) && (return string(name))
    end
    error(string("Invalid enum value ", t, " for ", typeof(enumname)))
end
