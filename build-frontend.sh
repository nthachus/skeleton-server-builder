#!/bin/sh
set -x

PRJ_NAME=angular8-skeleton
PRJ_DIR=$PRJ_NAME-main
DIST_FILE="$(dirname "`realpath "$0"`")/$PRJ_NAME$1.tgz"

if [ ! -d $PRJ_NAME ]; then
  if [ ! -d $PRJ_DIR ]; then
    if [ -f $DIST_FILE ]; then
      mkdir $PRJ_DIR
      tar -xzvf $DIST_FILE -C $PRJ_DIR/ >/dev/null
    else
      wget -O main.zip -nv --no-check-certificate https://github.com/nthachus/$PRJ_NAME/archive/refs/heads/main.zip
      unzip main.zip >/dev/null
      rm -rf main.zip ~/.wget* /tmp/*
    fi
  fi
  mv $PRJ_DIR $PRJ_NAME
fi

if [ ! -f $PRJ_NAME/dist/ng8-skeleton/index.html ]; then
  cd $PRJ_NAME
  yarn
  yarn cache clean
  yarn build
  rm -rf $DIST_FILE node_modules/ ~/.yarn /tmp/*

  tar -czvf $DIST_FILE . >/dev/null
fi
