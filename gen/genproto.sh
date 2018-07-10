#!/usr/bin/env bash

# Note: needs the protobuf3 compiler
if [ -z "$PROTOC" ]
then
    if [ -z "$PROTOC3" ]
    then
        PROTOC=protoc
    else
        PROTOC=$PROTOC3
    fi
fi

PROTOC_VER=`${PROTOC} --version | cut -d" " -f2 | cut -d"." -f1`
echo "compiler version $PROTOC_VER"

if [ "${PROTOC_VER}" -eq "3" ]
then
    SPECS=""
    for SPEC in empty any timestamp duration wrappers descriptor source_context type field_mask api struct
    do
        SPECS="${SPECS} google/protobuf/${SPEC}.proto"
        echo "- google/protobuf/${SPEC}.proto"
    done
    ${PROTOC} --proto_path=. --julia_out=out ${SPECS}

    echo "- google/protobuf/compiler/plugin.proto"
    ${PROTOC} --proto_path=. --julia_out=out google/protobuf/compiler/plugin.proto
else
    echo "compiler version 3 is required"
fi
