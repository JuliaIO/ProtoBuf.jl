#! /usr/bin/env bash

PROTO3_ROOT=/proto3
mkdir $PROTO3_ROOT

PROTO3_VER=3.6.1
PROTO3_PATH=$PROTO3_ROOT/protobuf-$PROTO3_VER

if [[ "$OSTYPE" == "linux-gnu" ]]; then
    PROTO3_BIN=https://github.com/google/protobuf/releases/download/v${PROTO3_VER}/protoc-${PROTO3_VER}-linux-x86_64.zip
    curl -OL $PROTO3_BIN
    mkdir -p ${PROTO3_PATH}/install/bin
    unzip protoc-${PROTO3_VER}-linux-x86_64.zip -d ${PROTO3_PATH}/install
    rm protoc-${PROTO3_VER}-linux-x86_64.zip
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PROTO3_BIN=https://github.com/google/protobuf/releases/download/v${PROTO3_VER}/protoc-${PROTO3_VER}-osx-x86_64.zip
    curl -OL $PROTO3_BIN
    mkdir -p ${PROTO3_PATH}/install/bin
    unzip protoc-${PROTO3_VER}-osx-x86_64.zip -d ${PROTO3_PATH}/install
    rm protoc-${PROTO3_VER}-osx-x86_64.zip
else
    # compile from source
    PROTO3_SRC=https://github.com/google/protobuf/releases/download/v${PROTO3_VER}/protobuf-cpp-${PROTO3_VER}.tar.gz
    curl -s -L ${PROTO3_SRC} | tar -C ${PROTO3_ROOT} -x -z -f -
    cd ${PROTO3_PATH} && mkdir install && ./autogen.sh && ./configure --prefix=${PROTO3_PATH}/install && make install
fi
