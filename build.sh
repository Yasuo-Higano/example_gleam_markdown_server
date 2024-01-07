#!/bin/sh

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR

mkdir -p deps 2>/dev/null
cd deps
git clone https://github.com/Yasuo-Higano/kirala_bbmarkdown

cd $SCRIPT_DIR
gleam build