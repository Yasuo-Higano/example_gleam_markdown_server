#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

BASEDIR="`basename $SCRIPT_DIR`"

LANG=ja_JP.UTF-8 LC_CTYPE=ja_JP.UTF-8 erl \
    +pc unicode \
    -Application kernel stdlib crypto public_key asn1 ssl \
    -kernel shell_history enabled \
    -pa build/dev/erlang/*/ebin \
    -noshell \
    -s markdown_server main