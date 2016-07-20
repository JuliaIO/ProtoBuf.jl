mkdir -p out
PROTOC=protoc
${PROTOC} --proto_path=test/proto --julia_out=out test/proto/t1.proto
${PROTOC} --proto_path=test/proto --julia_out=out test/proto/t2.proto
${PROTOC} --proto_path=test/proto --julia_out=out test/proto/plugin.proto
${PROTOC} --proto_path=test/proto --julia_out=out test/proto/a.proto test/proto/b.proto && JULIA_LOAD_PATH=out julia -e 'using A, B'
JULIA_PROTOBUF_MODULE_POSTFIX=1 ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/module_type_name_collision.proto && JULIA_LOAD_PATH=out julia -e 'using Foo_pb'
