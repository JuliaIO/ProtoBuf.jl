#!/usr/bin/env bash

if [ -z "$PROTOC" ]
then
    PROTOC=protoc
fi

PROTOC_VER=`${PROTOC} --version | cut -d" " -f2 | cut -d"." -f1`
echo "compiler version $PROTOC_VER"

${PROTOC} --proto_path=. --julia_out=. testsvc.proto
