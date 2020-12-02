#!/bin/sh

echo "*******Launch Redis Server"
"$1" "$2" --loadmodule "$3" &
"$4" config set dir "$5"
