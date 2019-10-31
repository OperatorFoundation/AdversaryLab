#!/bin/sh

lsof -i tcp:6380 | grep  LISTEN | grep IPv4
