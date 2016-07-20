#!/usr/bin/env bash

#PROTOC3=protoc
PROTOC3=/home/tan/Work/Tools/Google/protobuf/protobuf-3.0.0-beta-4/install/bin/protoc
${PROTOC3} --proto_path=. --julia_out=out google/protobuf/compiler/plugin.proto
