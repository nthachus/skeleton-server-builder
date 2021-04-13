#!/bin/sh
set -x

PRJ_NAME=sinatra-rest-skeleton
PRJ_DIR=$PRJ_NAME-main
DIST_FILE="$(dirname "`realpath "$0"`")/$PRJ_NAME.tgz"

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

if [ ! -f $PRJ_NAME/vendor/bundle/ruby/*/bin/unicorn ]; then
  cd $PRJ_NAME
  bundle install --path vendor/bundle --without 'test:development' --frozen --no-cache
  GEM_HOME=`ls -d $PWD/vendor/bundle/ruby/* | head -1` gem check
  rm -rf $DIST_FILE ~/.bundle ~/.gem /tmp/*

  find vendor/bundle/ruby/*/extensions \( -iname '*.log' -or -iname '*.out' \) -type f -delete
  if [ ! -e db/seeds/production.rb ]; then
    ln -s ./development.rb db/seeds/production.rb
  fi

  tar -czvf $DIST_FILE . >/dev/null
fi
