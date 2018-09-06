#! /usr/bin/env bash

PROTO2_ROOT=/tmp/proto2
mkdir $PROTO2_ROOT

PROTO2_VER=2.6.1
PROTO2_PATH=$PROTO2_ROOT/protobuf-$PROTO2_VER

# compile from source
PROTO2_SRC=https://github.com/protocolbuffers/protobuf/releases/download/v${PROTO2_VER}/protobuf-${PROTO2_VER}.tar.gz
curl -s -L ${PROTO2_SRC} | tar -C ${PROTO2_ROOT} -x -z -f -
cd ${PROTO2_PATH} && mkdir install && ./autogen.sh && ./configure --prefix=${PROTO2_PATH}/install && make install
