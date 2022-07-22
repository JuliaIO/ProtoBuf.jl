# using SnoopCompileCore
# import ProtocolBuffers as PB
# tinf = @snoopi tmin=0.005 PB.protojl("test_protos/google/protobuf/unittest.proto", ["./test/", "./test/test_protos/"], "dev/tst2")
# tinf = @snoopi tmin=0.005 PB.protojl("datasets/google_message3/benchmark_message3.proto", ["./test/test_protos/benchmarks"], "dev/tst2")
# tinf = @snoopi tmin=0.005 PB.protojl("datasets/google_message4/benchmark_message4.proto", ["./test/test_protos/benchmarks"], "dev/tst2")

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    @assert precompile(Lexers.next_token, (Lexers.Lexer{IOBuffer},))

    @assert precompile(CodeGenerators._protojl, (String, Vector{String}, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (String, String, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (String, Vector{String}, Nothing, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (String, String, Nothing, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (String, Nothing, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (String, Nothing, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, Vector{String}, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, String, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, Vector{String}, Nothing, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, String, Nothing, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, Nothing, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators._protojl, (Vector{String}, Nothing, String, CodeGenerators.Options))
    @assert precompile(CodeGenerators.codegen, (IOStream, Parsers.MessageType, CodeGenerators.Context))
    @assert precompile(CodeGenerators.codegen, (IOStream, Parsers.EnumType, CodeGenerators.Context))
    @assert precompile(CodeGenerators.generate_struct_field, (IOStream, Parsers.OneOfType, CodeGenerators.Context, Dict{String, CodeGenerators.ParamMetadata}))
    @assert precompile(CodeGenerators.generate_struct_field, (IOStream, Parsers.MessageType, CodeGenerators.Context, Dict{String, CodeGenerators.ParamMetadata}))
    @assert precompile(CodeGenerators.jl_typename, (Parsers.ReferencedType, CodeGenerators.Context))
end