#!/bin/sh

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

gleam add gleam_erlang
gleam add gleam_elli
gleam add elli
gleam add cowlib
