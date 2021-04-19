#!/bin/sh
set -x

if [ ! -f angular8-skeleton/dist/ng8-skeleton/index.html ] || [ ! -f sinatra-rest-skeleton/vendor/bundle/ruby/*/bin/unicorn ]; then
  exit 1
fi

PKG_VER=`grep -i '"version":' angular8-skeleton/package.json | sed 's/.*: "\|",.*//g'`
PKG_ROOT=/tmp/skeleton-server-$PKG_VER
APP_ROOT=$PKG_ROOT/opt/skeleton
APP_PATH=$APP_ROOT/backend

RUBY_LIB_PATH=$PKG_ROOT/usr/lib/ruby/vendor_ruby/gems
RUBY_VER=`ls -1 sinatra-rest-skeleton/vendor/bundle/ruby | head -1`
APP_HOME=/opt/skeleton/backend
RUN_AS=nginx

# Application
mkdir -p $APP_ROOT
mv sinatra-rest-skeleton $APP_PATH
mv angular8-skeleton/dist/ng8-skeleton $APP_ROOT/frontend
rm -rf $APP_PATH/.git* $APP_PATH/.bundle $APP_PATH/coverage $APP_PATH/log/* $APP_PATH/storage/* $APP_PATH/tmp/*/*
sed -i -e 's/# listen "/listen "/' -e 's/listen 3000/# &/' $APP_PATH/unicorn.rb
sed -i 's/ skeleton-db/ localhost/' $APP_PATH/config/database.yml

# Ruby dependencies
mkdir -p $RUBY_LIB_PATH $PKG_ROOT/usr/local/bin
mv $APP_PATH/vendor/bundle/ruby/$RUBY_VER $RUBY_LIB_PATH/ && rm -rf $APP_PATH/vendor/*
chmod +x $RUBY_LIB_PATH/$RUBY_VER/bin/* $RUBY_LIB_PATH/$RUBY_VER/gems/*/bin/*
for f in `ls -A $RUBY_LIB_PATH/$RUBY_VER/bin`; do
  ln -s "../../lib/ruby/vendor_ruby/gems/$RUBY_VER/bin/$f" "$PKG_ROOT/usr/local/bin/$f"
done

# SSL
mkdir -p $PKG_ROOT/etc/ssl/certs $PKG_ROOT/etc/ssl/private
mv $APP_PATH/spec/fixtures/ldap_data/server.crt $PKG_ROOT/etc/ssl/certs/server-lvh.crt
mv $APP_PATH/spec/fixtures/ldap_data/server.key $PKG_ROOT/etc/ssl/private/server-lvh.key
mv $APP_PATH/spec/fixtures/ldap_data/ca.crt $PKG_ROOT/etc/ssl/certs/ca-skeleton.crt
mv $APP_PATH/spec/fixtures/ldap_data/ca.key $PKG_ROOT/etc/ssl/private/ca-skeleton.key
chmod o-r $PKG_ROOT/etc/ssl/private/*

# Website
mkdir -p $PKG_ROOT/etc/nginx/snippets $PKG_ROOT/etc/nginx/conf.d
mv $APP_PATH/spec/fixtures/nginx_data/proxy.conf $PKG_ROOT/etc/nginx/snippets/
mv $APP_PATH/spec/fixtures/nginx_data/site.conf $PKG_ROOT/etc/nginx/conf.d/skeleton.conf
sed -i -e 's/server skeleton-api\|limit_rate/# &/' \
  -e "s,# server unix:/usr/src/app/,server unix:$APP_HOME/," \
  -e 's,/etc/nginx/ssl/server.crt,/etc/ssl/certs/server-lvh.crt,' \
  -e 's,/etc/nginx/ssl/server.key,/etc/ssl/private/server-lvh.key,' \
  -e 's,/etc/nginx/ssl/ca.crt,/etc/ssl/certs/ca-skeleton.crt,' \
  -e 's,/var/www/html,/opt/skeleton/frontend,' \
  -e 's,/etc/nginx/data/,/etc/nginx/snippets/,' $PKG_ROOT/etc/nginx/conf.d/skeleton.conf
rm -rf $APP_PATH/spec/fixtures/ldap_data $APP_PATH/spec/fixtures/nginx_data $APP_PATH/*Dockerfile $APP_PATH/docker-compose*

# Services
chown $RUN_AS -R $APP_ROOT
mkdir -p $PKG_ROOT/etc/init.d
echo '#!/sbin/openrc-run' > $PKG_ROOT/etc/init.d/unicorn-skeleton
echo "
description=\"Unicorn Skeleton service\"
extra_started_commands=\"reload\"
required_files=\"$APP_HOME/unicorn.rb\"

pidfile=$APP_HOME/tmp/pids/unicorn.pid
directory=$APP_HOME
command_user=$RUN_AS

command=/usr/local/bin/unicorn
command_args=\"-c unicorn.rb -E production -D\"
command_background=true
stopsig=QUIT

depend() {
  need net
  after postgresql
}

reload() {
  ebegin \"Reloading \$RC_SVCNAME\"
  start-stop-daemon --signal HUP --pidfile \$pidfile
  eend \$?
}" >> $PKG_ROOT/etc/init.d/unicorn-skeleton

RAKE_ARGS='RACK_ENV=production >> log/cron.stdout.log 2>> log/cron.stderr.log'

# Cronjobs
mkdir -p $PKG_ROOT/etc/crontabs $PKG_ROOT/etc/logrotate.d
echo "* *  * * *  cd $APP_HOME && rake app:delete_expired_uploads $RAKE_ARGS
* *  * * *  cd $APP_HOME && rake app:identify_file_types[30] $RAKE_ARGS
*/2 *  * * *  cd $APP_HOME && rake app:compute_file_checksums[15] $RAKE_ARGS
* *  * * *  cd $APP_HOME && rake app:delete_expired_sessions $RAKE_ARGS" > $PKG_ROOT/etc/crontabs/$RUN_AS

echo "$APP_HOME/log/*.log {
  weekly
  missingok
  rotate 12
  compress
  delaycompress
  notifempty
  copytruncate
}" > $PKG_ROOT/etc/logrotate.d/skeleton-api

PKG_SIZE=`du -s -k $PKG_ROOT | sed 's/[^0-9].*//'`
DB_PWD=`grep -i 'password:' $APP_PATH/config/database.yml | tail -1 | sed 's/^.*: //'`

# APK files
echo "pkgname = skeleton-server
pkgver = $PKG_VER
pkgdesc = An Angular application using Sinatra Restful-API skeleton.
url = https://github.com/nthachus/angular8-skeleton
arch = x86_64
origin = skeleton-server
maintainer = Thach Nguyen (https://github.com/nthachus)
license = MIT
builddate = $(date +%s)
size = $((PKG_SIZE * 1024))
depend = ruby
depend = ruby-bundler
depend = postgresql
depend = nginx
depend = file
depend = uchardet
#depend = p7zip
#depend = graphicsmagick
depend = /bin/sh" > $PKG_ROOT/.PKGINFO

echo '#!/bin/sh' > $PKG_ROOT/.pre-install
echo "set -x

if [ -d /opt ]; then touch /opt/.placeholder; fi
if [ -d /usr/local/bin ]; then touch /usr/local/bin/.placeholder; fi" >> $PKG_ROOT/.pre-install

echo '#!/bin/sh' > $PKG_ROOT/.post-install
echo "set -x

# Database
if [ ! -f /var/lib/postgresql/*/data/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi
su -s /bin/sh -c \"psql -c \\\"CREATE ROLE skeleton WITH LOGIN CREATEDB PASSWORD '$DB_PWD'\\\"\" postgres 2>/dev/null || true
cd $APP_HOME && rake db:drop db:setup RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1

# Website
if [ -e /etc/nginx/conf.d/default.conf ]; then
  mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf-
fi

# Service
rc-update add unicorn-skeleton || true" >> $PKG_ROOT/.post-install

ln -s ./.post-install $PKG_ROOT/.post-upgrade

echo '#!/bin/sh' > $PKG_ROOT/.pre-deinstall
echo "set -x

# Database
if [ ! -f /var/lib/postgresql/*/data/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi
cd $APP_HOME && rake db:drop RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1
su -s /bin/sh -c \"psql -c \\\"DROP ROLE IF EXISTS skeleton\\\"\" postgres

# Website
if [ -e /etc/nginx/conf.d/default.conf- ]; then
  mv -f /etc/nginx/conf.d/default.conf- /etc/nginx/conf.d/default.conf
fi

# Service
if [ -f $APP_HOME/tmp/pids/*.pid ]; then
  rc-service unicorn-skeleton stop || true
fi
rc-update del unicorn-skeleton || true" >> $PKG_ROOT/.pre-deinstall

# Build package
chmod +x $PKG_ROOT/.pre-* $PKG_ROOT/.post-*
tar -czvf "$(dirname "$0")/skeleton-server-${PKG_VER}.alpine.tgz" -C $PKG_ROOT . >/dev/null
rm -rf angular8-skeleton/ sinatra-rest-skeleton/ /tmp/*
