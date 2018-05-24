:: Tells program not to dispaly all the commands (@ means do not display the echo off line)
@echo off

set FLAGS=
if [%JULIA_PROTOBUF_MODULE_POSTFIX%]==[1] (set FLAGS=" --module-postfix-enabled")
if [%JULIA_PROTOBUF_MAP_AS_ARRAY%]==[1] (set FLAGS=%FLAGS%" --map-as-array")

julia -e "using ProtoBuf; using ProtoBuf.Gen; gen()" %FLAGS%
