#!/usr/bin/env bash

mkdir -p out

if [ -z "$PROTOC" ]
then
    PROTOC=protoc
fi

if [ -z "$JULIA" ]
then
    JULIA=julia
fi

PROTOC_VER=`${PROTOC} --version | cut -d" " -f2 | cut -d"." -f1`
echo "compiler version $PROTOC_VER"

JULIA_VER=`${JULIA} -e "versioninfo()" | grep "Julia Version"`
echo $JULIA_VER

ERR=0
SRC="test/proto"
WELL_KNOWN_PROTO_SRC="gen"
GEN="${PROTOC} --proto_path=${SRC} --proto_path=${WELL_KNOWN_PROTO_SRC} --julia_out=out"
CHK="${JULIA} -e"

echo "- t1.proto" && ${GEN} ${SRC}/t1.proto && ${CHK} 'include("out/t1_pb.jl")'
ERR=$(($ERR + $?))
echo "- t2.proto" && ${GEN} ${SRC}/t2.proto && ${CHK} 'include("out/t2_pb.jl")'
ERR=$(($ERR + $?))
echo "- a.proto, b.proto" && ${GEN} ${SRC}/a.proto test/proto/b.proto && JULIA_LOAD_PATH=out ${CHK} 'using A, B'
ERR=$(($ERR + $?))
echo "- module_type_name_collision.proto" && JULIA_PROTOBUF_MODULE_POSTFIX=1 ${GEN} ${SRC}/module_type_name_collision.proto && JULIA_LOAD_PATH=out ${CHK} 'using Foo_pb'
ERR=$(($ERR + $?))
echo "- packed2.proto" && ${GEN} ${SRC}/packed2.proto && ${CHK} 'include("out/packed2_pb.jl")'
ERR=$(($ERR + $?))

if [ ${PROTOC_VER} -eq "3" ]
then
    echo "- map3.proto (as dict)" && ${GEN} ${SRC}/map3.proto && ${CHK} 'include("out/map3_pb.jl"); using Base.Test; @test string(MapTest.types[3].name) == "Dict"'
    ERR=$(($ERR + $?))
    mv out/map3_pb.jl out/map3_dict_pb.jl
    echo "- map3.proto (as array)" && JULIA_PROTOBUF_MAP_AS_ARRAY=1 ${GEN} ${SRC}/map3.proto && ${CHK} 'include("out/map3_pb.jl"); using Base.Test; @test string(MapTest.types[3].name) == "Array"'
    ERR=$(($ERR + $?))
    mv out/map3_pb.jl out/map3_array_pb.jl
    echo "- oneof3.proto" && ${GEN} ${SRC}/oneof3.proto && ${CHK} 'include("out/oneof3_pb.jl")'
    ERR=$(($ERR + $?))
    echo "- packed3.proto" && ${GEN} ${SRC}/packed3.proto && ${CHK} 'include("out/packed3_pb.jl")'
    ERR=$(($ERR + $?))
    echo "- any_test.proto" && ${GEN} ${SRC}/any_test.proto && ${CHK} 'include("out/any_test_pb.jl")'
    ERR=$(($ERR + $?))
fi

exit $ERR
