#!/bin/sh

echo "*******Launch Redis Server"
"$1" "$2" --loadmodule "$3"
