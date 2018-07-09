PROTO3_ROOT=/proto3
mkdir $PROTO3_ROOT

PROTO3_VER=3.6.0
PROTO3_PATH=$PROTO3_ROOT/protobuf-$PROTO3_VER
PROTO3_SRC=https://github.com/google/protobuf/releases/download/v${PROTO3_VER}/protobuf-cpp-${PROTO3_VER}.tar.gz

curl -s -L ${PROTO3_SRC} | tar -C ${PROTO3_ROOT} -x -z -f -
cd ${PROTO3_PATH} && mkdir install && ./autogen.sh && ./configure --prefix=${PROTO3_PATH}/install && make install
