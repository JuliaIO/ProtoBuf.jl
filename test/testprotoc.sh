#!/usr/bin/env bash

mkdir -p out

if [ -z "$PROTOC" ]
then
    PROTOC=protoc
fi

PROTOC_VER=`${PROTOC} --version | cut -d" " -f2 | cut -d"." -f1`
ERR=0

echo "compiler version $PROTOC_VER"

echo "- t1.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/t1.proto && julia -e 'include("out/t1_pb.jl")'
ERR=$(($ERR + $?))
echo "- t2.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/t2.proto && julia -e 'include("out/t2_pb.jl")'
ERR=$(($ERR + $?))
echo "- a.proto, b.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/a.proto test/proto/b.proto && JULIA_LOAD_PATH=out julia -e 'using A, B'
ERR=$(($ERR + $?))
echo "- module_type_name_collision.proto" && JULIA_PROTOBUF_MODULE_POSTFIX=1 ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/module_type_name_collision.proto && JULIA_LOAD_PATH=out julia -e 'using Foo_pb'
ERR=$(($ERR + $?))
echo "- packed2.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/packed2.proto && JULIA_LOAD_PATH=out julia -e 'include("out/packed2_pb.jl")'
ERR=$(($ERR + $?))

if [ ${PROTOC_VER} -eq "3" ]
then
    echo "- map3.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/map3.proto && JULIA_LOAD_PATH=out julia -e 'include("out/map3_pb.jl")'
    ERR=$(($ERR + $?))
    echo "- oneof3.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/oneof3.proto && JULIA_LOAD_PATH=out julia -e 'include("out/oneof3_pb.jl")'
    ERR=$(($ERR + $?))
    echo "- packed3.proto" && ${PROTOC} --proto_path=test/proto --julia_out=out test/proto/packed3.proto && JULIA_LOAD_PATH=out julia -e 'include("out/packed3_pb.jl")'
    ERR=$(($ERR + $?))
fi

exit $ERR
