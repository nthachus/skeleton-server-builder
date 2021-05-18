#!/bin/sh
set -xe

SC_DIR="$(dirname "$0")"
PKG_NAME=skeleton-server

apt-get update -qq
[ "$(getconf LONG_BIT)" = 64 ] && ARCH=64 || ARCH=86
( set +x && while [ ! -f "$SC_DIR"/${PKG_NAME}_*$ARCH.deb ]; do sleep 1; done )

apt-get install -y "$SC_DIR"/${PKG_NAME}_*$ARCH.deb

# FIXME: Restart systemd
systemctl start unicorn-skeleton.service
systemctl reload nginx.service

# TODO: verifying with cURL

#apt-get remove -y $PKG_NAME

rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*
