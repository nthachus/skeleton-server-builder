#!/bin/sh
set -xe

if [ ! -f angular8-skeleton/dist/ng8-skeleton/index.html ] || [ ! -e sinatra-rest-skeleton/vendor/bundle/ruby/*/bin/unicorn ]; then
  exit 1
fi

PKG_NAME=skeleton-server
PKG_VER="$(grep '^ *"version":' angular8-skeleton/package.json | sed 's/^.*": *"\(.*\)".*/\1/')"
PKG_ROOT="/tmp/$PKG_NAME-$PKG_VER"

APP_HOME="/opt/$PKG_NAME/backend"
APP_PATH="$PKG_ROOT$APP_HOME"
APP_ROOT="${APP_PATH%/*}"

RUN_AS=www-data
SVC_NAME=unicorn-skeleton

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
mkdir -p "$PKG_ROOT/etc/nginx/snippets" "$PKG_ROOT/etc/nginx/sites-available"
mv "$APP_PATH/spec/fixtures/nginx_data/proxy.conf" "$PKG_ROOT/etc/nginx/snippets/"
mv "$APP_PATH/spec/fixtures/nginx_data/site.conf" "$PKG_ROOT/etc/nginx/sites-available/skeleton.conf"
sed -i -e 's/server skeleton-api\|limit_rate/# &/' \
  -e "s,# server unix:/usr/src/app/,server unix:$APP_HOME/," \
  -e 's,/etc/nginx/ssl/server.crt,/etc/ssl/certs/server-lvh.crt,' \
  -e 's,/etc/nginx/ssl/server.key,/etc/ssl/private/server-lvh.key,' \
  -e 's,/etc/nginx/ssl/ca.crt,/etc/ssl/certs/ca-skeleton.crt,' \
  -e "s,/var/www/html,${APP_HOME%/*}/frontend," \
  -e 's,/etc/nginx/data/,/etc/nginx/snippets/,' "$PKG_ROOT/etc/nginx/sites-available/skeleton.conf"

( cd "$APP_PATH" && rm -rf spec/fixtures/*_data *Dockerfile docker-compose* )
chown -Rh $RUN_AS: "$APP_ROOT"

# Services
mkdir -p "$PKG_ROOT/lib/systemd/system"
echo "[Unit]
Description=Unicorn Skeleton service
Requires=network.target
After=postgresql.service
ConditionPathExists=$APP_HOME/unicorn.rb

[Service]
Type=forking
WorkingDirectory=$APP_HOME
User=$RUN_AS
PIDFile=$APP_HOME/tmp/pids/unicorn.pid
ExecStart=/usr/bin/bundle exec unicorn -c unicorn.rb -E production -D
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
KillSignal=SIGQUIT
Restart=on-failure
SyslogIdentifier=$SVC_NAME

[Install]
WantedBy=multi-user.target" > "$PKG_ROOT/lib/systemd/system/$SVC_NAME.service"

# Cronjobs
RAKE_CMD='/usr/bin/bundle exec rake'
RAKE_ARGS='RACK_ENV=production >> log/cron.stdout.log 2>> log/cron.stderr.log'

mkdir -p "$PKG_ROOT/etc/cron.d" "$PKG_ROOT/etc/logrotate.d"
echo "# m h  dom mon dow  user  command
* *  * * *  $RUN_AS  cd '$APP_HOME' && $RAKE_CMD app:delete_expired_uploads $RAKE_ARGS
* *  * * *  $RUN_AS  cd '$APP_HOME' && $RAKE_CMD app:identify_file_types[30] $RAKE_ARGS
*/2 * * * * $RUN_AS  cd '$APP_HOME' && $RAKE_CMD app:compute_file_checksums[15] $RAKE_ARGS
* *  * * *  $RUN_AS  cd '$APP_HOME' && $RAKE_CMD app:delete_expired_sessions $RAKE_ARGS" > "$PKG_ROOT/etc/cron.d/$PKG_NAME"

echo "$APP_HOME/log/*.log {
  weekly
  missingok
  rotate 12
  compress
  delaycompress
  notifempty
  copytruncate
}" > "$PKG_ROOT/etc/logrotate.d/skeleton-api"


# DEBIAN files
PKG_SIZE=`du -sk "$PKG_ROOT" | sed 's/[^0-9].*//'`
DB_PWD="$(grep '^ *password:' "$APP_PATH/config/database.yml" | tail -1 | sed 's/^ *password: *//')"

[ -d "$APP_PATH/vendor/bundle/ruby"/*/extensions/*64* ] && ARCH=amd64 || ARCH=i386
RUBY_VER="$(ls -1p "$APP_PATH/vendor/bundle/ruby" | grep -m1 '\.0/$')"

mkdir -p "$PKG_ROOT/DEBIAN"
( find "$PKG_ROOT/etc" -type f ! -path "$PKG_ROOT/etc/ssl/*" ; ls -1 "$APP_PATH/config"/*.yml ) | sort | sed "s,^$PKG_ROOT,," > "$PKG_ROOT/DEBIAN/conffiles"
( find "$PKG_ROOT" ! -type d ! -path "$PKG_ROOT/etc/*" ! -path "$PKG_ROOT/DEBIAN/*" ! -regex "$APP_PATH/config/[^/]*\.yml" -exec md5sum "{}" + \
  ; find "$PKG_ROOT/etc/ssl" -type f -exec md5sum "{}" + ) | sort -k2 | sed "s, \+\*\?$PKG_ROOT/,  ," > "$PKG_ROOT/DEBIAN/md5sums"

echo "Package: $PKG_NAME
Version: $PKG_VER
Section: web
Priority: optional
Architecture: $ARCH
Maintainer: Thach Nguyen (https://github.com/nthachus)
Homepage: https://github.com/nthachus/angular8-skeleton
Description: An Angular application using Sinatra Restful-API skeleton.
Depends: ruby${RUBY_VER%.*}, ruby-bundler, systemd, cron, postgresql, nginx, file
Recommends: uchardet (>= 0.0.6), p7zip-rar, graphicsmagick
Suggests: logrotate, bitdefender-scanner, libreoffice-writer, libreoffice-calc, libreoffice-impress
Installed-Size: $PKG_SIZE" > "$PKG_ROOT/DEBIAN/control"

echo '#!/bin/sh' > "$PKG_ROOT/DEBIAN/postinst"
echo "set -xe

if [ ! -e /var/run/postgresql/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi

# Database
su -s /bin/sh -c \"psql -c \\\"CREATE ROLE skeleton WITH LOGIN CREATEDB PASSWORD '$DB_PWD'\\\"\" postgres 2>/dev/null || true
( cd '$APP_HOME' && $RAKE_CMD db:drop db:setup RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 ) || true

# Website
if ! nginx -v 2>&1 | sed 's,^.*nginx/,1.13.5\\\\n,' | sort -VC ; then
  sed -i 's/ssl_client_escaped_cert/ssl_client_cert/' /etc/nginx/sites-available/skeleton.conf
fi
ln -sf /etc/nginx/sites-available/skeleton.conf /etc/nginx/sites-enabled/default

# Service
if [ -d /run/systemd/system ]; then
  systemctl --system daemon-reload 2>/dev/null || true
fi
systemctl enable '$SVC_NAME.service' || true
systemctl start '$SVC_NAME.service' || true" >> "$PKG_ROOT/DEBIAN/postinst"

echo 'activate-noawait nginx-reload' > "$PKG_ROOT/DEBIAN/triggers"

echo '#!/bin/sh' > "$PKG_ROOT/DEBIAN/prerm"
echo "set -xe

if [ ! -e /var/run/postgresql/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi

# Service
if [ -e '$APP_HOME/tmp/pids'/*.pid ]; then
  systemctl stop '$SVC_NAME.service' || true
fi
systemctl disable '$SVC_NAME.service' || true

# Database
pkill -u $RUN_AS -f '$PKG_NAME.*${RAKE_CMD##*/} ' 2>/dev/null || true
( cd '$APP_HOME' && $RAKE_CMD db:drop RACK_ENV=production DISABLE_DATABASE_ENVIRONMENT_CHECK=1 ) || true" >> "$PKG_ROOT/DEBIAN/prerm"

echo '#!/bin/sh' > "$PKG_ROOT/DEBIAN/postrm"
echo "set -xe

# Database
if [ -e /var/run/postgresql/*.pid ]; then
  su -s /bin/sh -c \"psql -c \\\"DROP ROLE IF EXISTS skeleton\\\"\" postgres || true
fi

# Website
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

if [ -d /run/systemd/system ]; then
  systemctl --system daemon-reload 2>/dev/null || true
fi" >> "$PKG_ROOT/DEBIAN/postrm"

( cd "$PKG_ROOT/DEBIAN" && chmod +x post* pre* )


# Build package
OUT_FILE="$(dirname "$0")/${PKG_NAME}_${PKG_VER}_$ARCH.${1:-deb}"

dpkg-deb -b "$PKG_ROOT" "$OUT_FILE"
( dpkg-deb --ctrl-tarfile "$OUT_FILE" | tar -tv | sort -k6 ; dpkg-deb -c "$OUT_FILE" | sort -k6 ) > "${OUT_FILE%.*}.txt"

rm -rf /tmp/*
