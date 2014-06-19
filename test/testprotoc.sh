mkdir -p out
protoc --proto_path=test/proto --julia_out=out test/proto/t1.proto
protoc --proto_path=test/proto --julia_out=out test/proto/plugin.proto
protoc --proto_path=test/proto --julia_out=out test/proto/a.proto test/proto/b.proto
