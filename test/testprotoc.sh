mkdir -p out
protoc -I=test/proto --julia_out=out test/proto/t1.proto
protoc -I=test/proto --julia_out=out test/proto/plugin.proto
