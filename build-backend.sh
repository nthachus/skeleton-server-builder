#!/bin/sh
set -x

PRJ_NAME=sinatra-rest-skeleton
PRJ_DIR=$PRJ_NAME-main
DIST_FILE="$(dirname "`realpath "$0"`")/$PRJ_NAME$1.tgz"
RUBY_VER=`gem env | grep -m1 'USER INSTALL' | sed 's,^.*/,,g'`

if [ ! -d $PRJ_NAME ]; then
  if [ ! -d $PRJ_DIR ]; then
    if [ -f $DIST_FILE ]; then
      mkdir $PRJ_DIR
      tar -xzf $DIST_FILE -C $PRJ_DIR/
    else
      wget -O main.zip -nv --no-check-certificate https://github.com/nthachus/$PRJ_NAME/archive/refs/heads/main.zip
      unzip -q main.zip
      rm -rf main.zip ~/.wget* /tmp/*
    fi
  fi
  mv $PRJ_DIR $PRJ_NAME
fi

if [ ! -f $PRJ_NAME/vendor/bundle/ruby/$RUBY_VER/bin/unicorn ]; then
  cd $PRJ_NAME
  if [ "2.3.0" != "$RUBY_VER" ]; then
    for v in json minitest; do
      sed -i "s/^    $v (.*)/    $(gem list $v | grep $v | sed 's,(.* ,(,g')/" Gemfile.lock
    done
  fi

  bundle install --path vendor/bundle --without 'test:development' --frozen --no-cache
  GEM_HOME="$PWD/vendor/bundle/ruby/$RUBY_VER" gem check
  rm -rf $DIST_FILE ~/.bundle ~/.gem /tmp/*

  find vendor/bundle/ruby/$RUBY_VER/extensions \( -iname '*.log' -or -iname '*.out' \) -type f -delete
  if [ ! -e db/seeds/production.rb ]; then
    ln -s ./development.rb db/seeds/production.rb
  fi

  tar -czf $DIST_FILE .
fi
