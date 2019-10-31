#!/bin/sh

echo "Shutdown Redis Server*******"
"$1" -p 6380 shutdown
