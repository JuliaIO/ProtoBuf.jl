mkdir -p out
protoc -I test/proto test/proto/t1.proto --julia_out out
protoc -I test/proto test/proto/plugin.proto --julia_out out
