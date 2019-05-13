#!/bin/sh

lsof -i tcp:6379 | grep  LISTEN | grep IPv4
