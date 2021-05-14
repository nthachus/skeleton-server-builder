#!/bin/sh
set -xe

PRJ_NAME="$1"
PRJ_BRANCH="${2:-main}"

PRJ_DIR="$PRJ_NAME-$PRJ_BRANCH"
OUT_FILE="$(dirname "$0")/$PRJ_NAME$3.tgz"

if [ -d "$PRJ_NAME" ]; then
  exit 0
fi

if [ ! -d "$PRJ_DIR" ]; then
  if [ -f "$OUT_FILE" ]; then
    mkdir "$PRJ_DIR"
    tar -xzf "$OUT_FILE" -C "$PRJ_DIR/"
  else
    wget -O "$PRJ_DIR.zip" -q --no-check-certificate "https://github.com/nthachus/$PRJ_NAME/archive/refs/heads/$PRJ_BRANCH.zip"
    unzip -q "$PRJ_DIR.zip"
    rm -rf "$PRJ_DIR.zip" ~/.wget* /tmp/*
  fi
fi

mv "$PRJ_DIR" "$PRJ_NAME"
