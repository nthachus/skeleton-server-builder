#!/bin/sh
set -xe

if [ ! -f angular8-skeleton/dist/ng8-skeleton/index.html ] || [ ! -e sinatra-rest-skeleton/vendor/bundle/ruby/*/bin/unicorn ]; then
  exit 1
fi

PKG_NAME=skeleton-server
PKG_VER="$(grep '^ *"version":' angular8-skeleton/package.json | sed 's/^.*": *"\(.*\)".*/\1/')"
[ -d sinatra-rest-skeleton/vendor/bundle/ruby/*/extensions/*64* ] && ARCH=x86_64 || ARCH=x86

OUT_FILE="$(dirname "$0")/$PKG_NAME-$PKG_VER.$ARCH.apk"
if [ -f "$OUT_FILE" ]; then
  exit 0
fi

APP_HOME="/opt/$PKG_NAME/backend"
RUN_AS=www-data
SVC_NAME=unicorn-skeleton

PKG_ROOT="/tmp/$PKG_NAME-$PKG_VER"
APP_PATH="$PKG_ROOT$APP_HOME"
APP_ROOT="${APP_PATH%/*}"

# Application
mkdir -p "$APP_ROOT"
mv sinatra-rest-skeleton "$APP_PATH"
mv angular8-skeleton/dist/ng8-skeleton "$APP_ROOT/frontend" && rm -rf angular8-skeleton/
# disable 'preload_app' to apply HUP reload signal
sed -i -e 's/# \(listen "\)/\1/' -e 's/listen 3000/# &/' "$APP_PATH/unicorn.rb"
sed -i 's/ skeleton-db/ localhost/' "$APP_PATH/config/database.yml"

# SSL
mkdir -p "$PKG_ROOT/etc/ssl/certs" "$PKG_ROOT/etc/ssl/private"
mv "$APP_PATH/spec/fixtures/ldap_data/server.crt" "$PKG_ROOT/etc/ssl/certs/server-lvh.crt"
mv "$APP_PATH/spec/fixtures/ldap_data/server.key" "$PKG_ROOT/etc/ssl/private/server-lvh.key"
mv "$APP_PATH/spec/fixtures/ldap_data/ca.crt" "$PKG_ROOT/etc/ssl/certs/ca-skeleton.crt"
mv "$APP_PATH/spec/fixtures/ldap_data/ca.key" "$PKG_ROOT/etc/ssl/private/ca-skeleton.key"
chmod o-r "$PKG_ROOT/etc/ssl/private"/*

# Website
mkdir -p "$PKG_ROOT/etc/nginx/snippets" "$PKG_ROOT/etc/nginx/conf.d"
mv "$APP_PATH/spec/fixtures/nginx_data/proxy.conf" "$PKG_ROOT/etc/nginx/snippets/"
mv "$APP_PATH/spec/fixtures/nginx_data/site.conf" "$PKG_ROOT/etc/nginx/conf.d/skeleton.conf"
sed -i -e 's/server skeleton-api\|limit_rate/# &/' \
  -e "s,# server unix:/usr/src/app/,server unix:$APP_HOME/," \
  -e 's,/etc/nginx/ssl/server.crt,/etc/ssl/certs/server-lvh.crt,' \
  -e 's,/etc/nginx/ssl/server.key,/etc/ssl/private/server-lvh.key,' \
  -e 's,/etc/nginx/ssl/ca.crt,/etc/ssl/certs/ca-skeleton.crt,' \
  -e "s,/var/www/html,${APP_HOME%/*}/frontend," \
  -e 's,/etc/nginx/data/,/etc/nginx/snippets/,' "$PKG_ROOT/etc/nginx/conf.d/skeleton.conf"

( cd "$APP_PATH" && rm -rf spec/fixtures/*_data *Dockerfile docker-compose* )
chown -Rh $RUN_AS: "$APP_ROOT"

# Services
mkdir -p "$PKG_ROOT/etc/init.d"
echo '#!/sbin/openrc-run' > "$PKG_ROOT/etc/init.d/$SVC_NAME"
echo "
description=\"Unicorn Skeleton service\"
extra_started_commands=\"reload\"
required_files=\"$APP_HOME/unicorn.rb\"

pidfile=\"$APP_HOME/tmp/pids/unicorn.pid\"
directory=\"$APP_HOME\"
command_user=$RUN_AS
command=/usr/bin/bundle
command_args=\"exec unicorn -c unicorn.rb -E production -D\"
stopsig=QUIT

depend() {
  need net
  after postgresql
}

reload() {
  ebegin \"Reloading \$RC_SVCNAME\"
  start-stop-daemon --signal HUP --pidfile \$pidfile
  eend \$?
}" >> "$PKG_ROOT/etc/init.d/$SVC_NAME"

chmod +x "$PKG_ROOT/etc/init.d"/*

# Cronjobs
RAKE_CMD='/usr/bin/bundle exec rake'
RAKE_ARGS='RACK_ENV=production >> log/cron.stdout.log 2>> log/cron.stderr.log'

mkdir -p "$PKG_ROOT/etc/crontabs" "$PKG_ROOT/etc/logrotate.d"
echo "# m h  dom mon dow  command
* *  * * *  cd '$APP_HOME' && $RAKE_CMD app:delete_expired_uploads $RAKE_ARGS
* *  * * *  cd '$APP_HOME' && $RAKE_CMD app:identify_file_types[30] $RAKE_ARGS
*/2 * * * * cd '$APP_HOME' && $RAKE_CMD app:compute_file_checksums[15] $RAKE_ARGS
* *  * * *  cd '$APP_HOME' && $RAKE_CMD app:delete_expired_sessions $RAKE_ARGS" > "$PKG_ROOT/etc/crontabs/$RUN_AS"

echo "$APP_HOME/log/*.log {
  weekly
  missingok
  rotate 12
  compress
  delaycompress
  notifempty
  copytruncate
}" > "$PKG_ROOT/etc/logrotate.d/skeleton-api"


# APK files
PKG_SIZE=`du -sk "$PKG_ROOT" | sed 's/[^0-9].*//'`
DB_PWD="$(grep '^ *password:' "$APP_PATH/config/database.yml" | tail -1 | sed 's/^ *password: *//')"
RUBY_VER="$(ls -1p "$APP_PATH/vendor/bundle/ruby" | grep -m1 '\..*/$' | sed 's,\.[^\.]*/$,,')"

echo "pkgname = $PKG_NAME
pkgver = $PKG_VER
pkgdesc = An Angular application using Sinatra Restful-API skeleton.
url = https://github.com/nthachus/angular8-skeleton
arch = $ARCH
origin = $PKG_NAME
maintainer = Thach Nguyen (https://github.com/nthachus)
license = MIT
builddate = $(date +%s)
size = $((PKG_SIZE * 1024))
depend = ruby>$RUBY_VER
depend = ruby<${RUBY_VER%.*}.$((${RUBY_VER##*.}+1))
depend = ruby-bundler
depend = openrc
depend = postgresql
depend = nginx
depend = file
depend = uchardet>=0.0.6
#depend = p7zip
#depend = graphicsmagick
#depend = logrotate
depend = /bin/sh" > "$PKG_ROOT/.PKGINFO"

echo '#!/bin/sh' > "$PKG_ROOT/.pre-install"
echo "set -xe

adduser -S -u 82 -D -H -h /var/www -g www-data -G www-data www-data 2>/dev/null || true" >> "$PKG_ROOT/.pre-install"

echo '#!/bin/sh' > "$PKG_ROOT/.post-install"
echo "set -xe

if [ ! -e /var/lib/postgresql/*/data/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi

# Database
su -s /bin/sh -c \"psql -c \\\"CREATE ROLE skeleton WITH LOGIN CREATEDB PASSWORD '$DB_PWD'\\\"\" postgres 2>/dev/null || true
( cd '$APP_HOME' && $RAKE_CMD db:drop db:setup RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 ) || true

# Website
if [ -e /etc/nginx/conf.d/default.conf ]; then
  mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf-
fi

# Service
rc-update add '$SVC_NAME' || true

echo '*** System restart required ***'" >> "$PKG_ROOT/.post-install"

ln -s .post-install "$PKG_ROOT/.post-upgrade"

echo '#!/bin/sh' > "$PKG_ROOT/.pre-deinstall"
echo "set -xe

if [ ! -e /var/lib/postgresql/*/data/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi

# Service
if [ -e '$APP_HOME/tmp/pids'/*.pid ]; then
  rc-service '$SVC_NAME' stop || true
fi
rc-update del '$SVC_NAME' || true

# Database
pkill -u $RUN_AS -f '${RAKE_CMD##*/} app:' 2>/dev/null || true
( cd '$APP_HOME' && $RAKE_CMD db:drop RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 ) || true" >> "$PKG_ROOT/.pre-deinstall"

echo '#!/bin/sh' > "$PKG_ROOT/.post-deinstall"
echo "set -xe

# Database
if [ -e /var/lib/postgresql/*/data/*.pid ]; then
  su -s /bin/sh -c \"psql -c \\\"DROP ROLE IF EXISTS skeleton\\\"\" postgres || true
fi

# Website
if [ -e /etc/nginx/conf.d/default.conf- ]; then
  mv -f /etc/nginx/conf.d/default.conf- /etc/nginx/conf.d/default.conf
fi" >> "$PKG_ROOT/.post-deinstall"

( cd "$PKG_ROOT" && chmod +x .pre-* .post-* )


# Build package
RSA_FILE="${OUT_FILE%/*}/abuild-rsa.tgz"

if [ -f "$RSA_FILE" ]; then
  tar -xzf "$RSA_FILE" -C ~/
else
  echo "$HOME/.abuild/nthachus.github.com-4a6a0840.rsa" | abuild-keygen -a
  tar -czf "$RSA_FILE" -C ~/ .abuild/
fi

( cd "$PKG_ROOT" && tar --xattrs -cf- * ) | abuild-tar --hash | gzip -9 > /tmp/data.tar.gz
sha256sum /tmp/data.tar.gz | sed -e 's/[[:blank:]].*//' -e 's/^/datahash = /' >> "$PKG_ROOT/.PKGINFO"
( cd "$PKG_ROOT" && tar -cf- .???* ) | abuild-tar --cut | gzip -9 > /tmp/control.tar.gz

abuild-sign -q /tmp/control.tar.gz
cat /tmp/control.tar.gz /tmp/data.tar.gz > "$OUT_FILE"
tar -tzvf "$OUT_FILE" | sort -k6 > "${OUT_FILE%.*}.txt"

rm -rf /tmp/*
