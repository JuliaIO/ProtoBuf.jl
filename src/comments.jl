# This file is adapted from https://github.com/pseudomuto/protokit/blob/7037620/comments.go

# A Comment describes the leading, trailing, and detached comments for a proto object. See
# `SourceCodeInfo_Location` in descriptor.proto for details on what those terms mean
struct Comment
	leading::String
	trailing::String
	detached::Vector{String}
end

function Comment(loc::SourceCodeInfo_Location)
    detached = if isfilled(loc, :leading_detached_comments)
        String[scrub(c) for c in loc.leading_detached_comments]
    else
        String[]
    end

    return Comment(
        isfilled(loc, :leading_comments) ? scrub(loc.leading_comments) : "",
        isfilled(loc, :trailing_comments) ? scrub(loc.trailing_comments) : "",
        detached,
    )
end
scrub(str) = strip(replace(str, "\n "=>"\n"))

const CommentMap_t = Dict{Tuple{Vararg{Int}}, Comment}

get_field_or_default(p, symbol) = isfilled(p, symbol) ? get_field(p, symbol) : fieldtype(typeof(p), symbol)()

# ParseComments parses all comments within a proto file. The locations are encoded into the
# map by joining the paths with a "." character. E.g. `4.2.3.0`.
#
# Leading/trailing spaces are trimmed for each comment type (leading, trailing, detached)
function parsecomments(fd::FileDescriptorProto)
    comments = CommentMap_t()

    if isfilled(fd, :source_code_info)
        source_code_info = fd.source_code_info
        for loc in get_field_or_default(source_code_info, :location)
            if !isfilled(loc, :leading_comments) &&
                !isfilled(loc, :trailing_comments) &&
                isempty(get_field_or_default(loc, :leading_detached_comments))
                continue
            end

            path = get_field_or_default(loc, :path)
            key = Tuple(path)
            comments[key] = Comment(loc)
        end
    end

    return comments
end


# Tag numbers from descriptor.proto  (These are guaranteed to be forward compatible.)
begin
	# tag numbers in FileDescriptorProto
	const c_packageCommentPath   = 2
	const c_messageCommentPath   = 4
	const c_enumCommentPath      = 5
	const c_serviceCommentPath   = 6
	const c_extensionCommentPath = 7
	const c_syntaxCommentPath    = 12

	# tag numbers in DescriptorProto
	const c_messageFieldCommentPath     = 2 # field
	const c_messageMessageCommentPath   = 3 # nested_type
	const c_messageEnumCommentPath      = 4 # enum_type
	const c_messageExtensionCommentPath = 6 # extension

	# tag numbers in EnumDescriptorProto
	const c_enumValueCommentPath = 2 # value

	# tag numbers in ServiceDescriptorProto
	const c_serviceMethodCommentPath = 2
end

# Note that the indexes are off-by-one due to julia 1-based indexing vs proto 0-based index
commentpath_enum(idx)                         = (c_enumCommentPath, idx-1)
commentpath_subenum(messagepath, idx)         = (messagepath..., c_messageEnumCommentPath, idx-1)
commentpath_enumvalue(enumpath, idx)          = (enumpath..., c_enumValueCommentPath, idx-1)
commentpath_message(idx)                      = (c_messageCommentPath, idx-1)
commentpath_submessage(parentpath, idx)       = (parentpath..., c_messageMessageCommentPath, idx-1)
commentpath_messagefield(messagepath, idx)    = (messagepath..., c_messageFieldCommentPath, idx-1)
commentpath_service(idx)                      = (c_serviceCommentPath, idx-1)
commentpath_service_message(servicepath, idx) = (servicepath..., c_serviceMethodCommentPath, idx-1)

getcomments(commentmap::CommentMap_t, path) = get(commentmap, path, Comment("", "", []))

pref(indent) = "$indent# "
function gen_comments_leading(io::IO, c::Comment; indent="")
    printed = false
    detached_str = gen_jlcomment(c.detached, indent=indent)
    if !isempty(detached_str)
        # Put a blank line on either side of detached comments
        println(io)
        println(io, pref(indent) * detached_str)
        println(io)
        printed = true
    end
    leading_str = gen_jlcomment(c.leading, indent=indent)
    if !isempty(leading_str)
        println(io, pref(indent) * leading_str)
        printed = true
    end
    return printed
end
function gen_comments_trailing(io::IO, c::Comment; indent="")
    trailing_str = gen_jlcomment(c.trailing, indent=indent)
    if !isempty(trailing_str)
        println(io, pref(indent) * trailing_str)
        return true
    else
        return false
    end
end

gen_jlcomment(cs::Vector{String}; indent="") = join((gen_jlcomment(s, indent=indent) for s in cs), "\n\n" * pref(indent))
function gen_jlcomment(s::String; indent="")
    join(split(s, "\n"), "\n" * pref(indent))
end
## TEST
#c = Comment("leading\ncomment","trailing\ncomment", ["this is a long\ncomment block", "so is this\nyeah man\nwhats\nup"])
#gen_comments_leading(stdout, c, indent="    ")
#print("    f::Int")
#gen_comments_trailing(stdout, c, indent="    ")
