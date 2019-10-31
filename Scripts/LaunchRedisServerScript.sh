#!/bin/sh

echo "*******Launch Redis Server"
echo "$1 $2 --loadmodule $3 &"
"$1" "$2" --loadmodule "$3" &
