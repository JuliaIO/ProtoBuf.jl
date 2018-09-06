#!/usr/bin/env bash

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

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
JULIA_VER=`${JULIA} -e "(VERSION > v\"0.7-\") && (import Pkg; Pkg.activate(joinpath(ENV[\"SCRIPT_DIR\"], \"..\"))); using InteractiveUtils; versioninfo()" | grep "Julia Version"`
echo $JULIA_VER

ERR=0
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SRC="${DIR}/proto"
OUT="${DIR}/out"
WELL_KNOWN_PROTO_SRC="${DIR}/../gen"
GEN="${PROTOC} --proto_path=${SRC} --proto_path=${WELL_KNOWN_PROTO_SRC} --julia_out=${OUT}"
CHK="${JULIA} -e '(VERSION > v\"0.7-\") && (import Pkg; Pkg.activate(joinpath(ENV[\"SCRIPT_DIR\"], \"..\")));' -e"
mkdir -p ${OUT}

cd ${DIR}
echo "- t1.proto" && ${GEN} ${SRC}/t1.proto && eval " ${CHK} 'include(\"out/t1_pb.jl\")'"
ERR=$(($ERR + $?))
echo "- t2.proto" && ${GEN} ${SRC}/t2.proto && eval " ${CHK} 'include(\"out/t2_pb.jl\")'"
ERR=$(($ERR + $?))
echo "- recursive.proto" && ${GEN} ${SRC}/recursive.proto && eval " ${CHK} 'include(\"out/recursive_pb.jl\")'"
ERR=$(($ERR + $?))
echo "- a.proto, b.proto" && ${GEN} ${SRC}/a.proto ${SRC}/b.proto && eval " ${CHK} 'include(\"out/AB.jl\"); using .AB; using .AB.A, .AB.B'"
ERR=$(($ERR + $?))
echo "- p1proto.proto, p2proto.proto" && ${GEN} ${SRC}/p1proto.proto ${SRC}/p2proto.proto && eval " ${CHK} 'include(\"out/P1.jl\"); include(\"out/P2.jl\"); using .P1; using .P2'"
ERR=$(($ERR + $?))
echo "- module_type_name_collision.proto" && JULIA_PROTOBUF_MODULE_POSTFIX=1 ${GEN} ${SRC}/module_type_name_collision.proto && eval " ${CHK} 'include(\"out/Foo_pb.jl\"); using .Foo_pb'"
ERR=$(($ERR + $?))
echo "- packed2.proto" && ${GEN} ${SRC}/packed2.proto && eval " ${CHK} 'include(\"out/packed2_pb.jl\")'"
ERR=$(($ERR + $?))

if [ ${PROTOC_VER} -eq "3" ]
then
    echo "- map3.proto (as dict)" && ${GEN} ${SRC}/map3.proto && eval " ${CHK} 'include(\"out/map3_pb.jl\"); using Test; @test string(MapTest.types[3].name) == \"Dict\"'"
    ERR=$(($ERR + $?))
    mv out/map3_pb.jl out/map3_dict_pb.jl
    echo "- map3.proto (as array)" && JULIA_PROTOBUF_MAP_AS_ARRAY=1 ${GEN} ${SRC}/map3.proto && eval " ${CHK} 'include(\"out/map3_pb.jl\"); using Test; @test string(MapTest.types[3].name) == \"Array\"'"
    ERR=$(($ERR + $?))
    mv out/map3_pb.jl out/map3_array_pb.jl
    echo "- oneof3.proto" && ${GEN} ${SRC}/oneof3.proto && eval " ${CHK} 'include(\"out/oneof3_pb.jl\")'"
    ERR=$(($ERR + $?))
    echo "- packed3.proto" && ${GEN} ${SRC}/packed3.proto && eval " ${CHK} 'include(\"out/packed3_pb.jl\")'"
    ERR=$(($ERR + $?))
    echo "- any_test.proto" && ${GEN} ${SRC}/any_test.proto && eval " ${CHK} 'include(\"out/any_test_pb.jl\")'"
    ERR=$(($ERR + $?))
    echo "- svc3.proto" && ${GEN} ${SRC}/svc3.proto && eval " ${CHK} 'include(\"out/svc3_pb.jl\")'"
    ERR=$(($ERR + $?))
fi

exit $ERR
