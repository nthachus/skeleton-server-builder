#!/bin/bash
set -x

if [ ! -f angular8-skeleton/dist/ng8-skeleton/index.html ] || [ ! -f sinatra-rest-skeleton/vendor/bundle/ruby/*/bin/unicorn ]; then
  exit 1
fi

PKG_VER=`grep -i '"version":' angular8-skeleton/package.json | sed 's/^.*: "\|",$//g'`
PKG_ROOT=/tmp/skeleton-server_${PKG_VER}_all
APP_ROOT=$PKG_ROOT/opt/skeleton
APP_PATH=$APP_ROOT/backend

RUBY_LIB_PATH=$PKG_ROOT/var/lib/gems
RUBY_VER=`ls -1 sinatra-rest-skeleton/vendor/bundle/ruby | head -1`
APP_HOME=/opt/skeleton/backend

RUN_USER=www-data
RUN_GROUP=adm

# Application
mkdir -p $APP_ROOT
mv sinatra-rest-skeleton $APP_PATH
mv angular8-skeleton/dist/ng8-skeleton $APP_ROOT/frontend
rm -rf $APP_PATH/.git $APP_PATH/.bundle $APP_PATH/coverage $APP_PATH/log/* $APP_PATH/storage/* $APP_PATH/tmp/*/*
sed -i -e 's/# listen "/listen "/' -e 's/listen 3000/# &/' $APP_PATH/unicorn.rb
sed -i 's/host: skeleton-db/# &/' $APP_PATH/config/database.yml

# Ruby dependencies
mkdir -p $RUBY_LIB_PATH $PKG_ROOT/usr/local
mv $APP_PATH/vendor/bundle/ruby/$RUBY_VER $RUBY_LIB_PATH/ && rm -rf $APP_PATH/vendor/*
chmod +x $RUBY_LIB_PATH/$RUBY_VER/bin/* $RUBY_LIB_PATH/$RUBY_VER/gems/*/bin/*
mv $RUBY_LIB_PATH/$RUBY_VER/bin $PKG_ROOT/usr/local/

# SSL
mkdir -p $PKG_ROOT/etc/ssl/certs $PKG_ROOT/etc/ssl/private
cp $APP_PATH/spec/fixtures/ldap_data/server.crt $PKG_ROOT/etc/ssl/certs/server-lvh.crt
cp $APP_PATH/spec/fixtures/ldap_data/server.key $PKG_ROOT/etc/ssl/private/server-lvh.key
cp $APP_PATH/spec/fixtures/ldap_data/ca.crt $PKG_ROOT/etc/ssl/certs/ca-skeleton.crt
cp $APP_PATH/spec/fixtures/ldap_data/ca.key $PKG_ROOT/etc/ssl/private/ca-skeleton.key
chmod o-r $PKG_ROOT/etc/ssl/private/*

# Website
mkdir -p $PKG_ROOT/etc/nginx/snippets $PKG_ROOT/etc/nginx/sites-available
cp $APP_PATH/spec/fixtures/nginx_data/proxy.conf $PKG_ROOT/etc/nginx/snippets/
cp $APP_PATH/spec/fixtures/nginx_data/site.conf $PKG_ROOT/etc/nginx/sites-available/skeleton.conf
sed -i -e 's/server skeleton-api\|limit_rate/# &/' \
  -e "s,# server unix:/usr/src/app/,server unix:$APP_HOME/," \
  -e 's,/etc/nginx/ssl/server.crt,/etc/ssl/certs/server-lvh.crt,' \
  -e 's,/etc/nginx/ssl/server.key,/etc/ssl/private/server-lvh.key,' \
  -e 's,/etc/nginx/ssl/ca.crt,/etc/ssl/certs/ca-skeleton.crt,' \
  -e "s,/var/www/html,${APP_HOME:0:-7}frontend," \
  -e 's,/etc/nginx/data/,/etc/nginx/snippets/,' $PKG_ROOT/etc/nginx/sites-available/skeleton.conf

# Services
chown $RUN_USER:$RUN_GROUP -R $APP_ROOT
mkdir -p $PKG_ROOT/lib/systemd/system
echo "[Unit]
Description=Unicorn Skeleton service
After=network.target postgresql.service

[Service]
Type=forking
WorkingDirectory=$APP_HOME
User=$RUN_USER
PIDFile=$APP_HOME/tmp/pids/unicorn.pid
ExecStart=/usr/local/bin/unicorn -c unicorn.rb -E production -D
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
KillSignal=SIGQUIT
Restart=on-failure
SyslogIdentifier=unicorn-skeleton

[Install]
WantedBy=multi-user.target" > $PKG_ROOT/lib/systemd/system/unicorn-skeleton.service

# Cronjobs
mkdir -p $PKG_ROOT/etc/cron.d $PKG_ROOT/etc/logrotate.d
echo "* *  * * *  $RUN_USER  cd $APP_HOME && rake app:delete_expired_uploads RACK_ENV=production
*/2 *  * * *  $RUN_USER  cd $APP_HOME && rake app:identify_file_types RACK_ENV=production
*/3 *  * * *  $RUN_USER  cd $APP_HOME && rake app:compute_file_checksums RACK_ENV=production
*/5 *  * * *  $RUN_USER  cd $APP_HOME && rake app:delete_expired_sessions RACK_ENV=production" > $PKG_ROOT/etc/cron.d/skeleton-server

echo "$APP_HOME/log/*.log {
  weekly
  missingok
  rotate 12
  compress
  delaycompress
  notifempty
  create 0640 $RUN_USER $RUN_GROUP
}" > $PKG_ROOT/etc/logrotate.d/skeleton-api

PKG_SIZE=`du -s -BK $PKG_ROOT | sed 's/K.*//'`
DB_PWD=`grep -i 'password:' $APP_PATH/config/database.yml | sed 's/^.*: //'`

# DEBIAN files
mkdir -p $PKG_ROOT/DEBIAN
( find $PKG_ROOT/etc -type f -not -path "$PKG_ROOT/etc/ssl/*" | sort ; ls -1 $APP_PATH/config/*.yml ) | sed "s,^$PKG_ROOT,," > $PKG_ROOT/DEBIAN/conffiles
find $PKG_ROOT \( -type f -or -type l \) -not -path "$PKG_ROOT/etc/*" -not -path "$PKG_ROOT/DEBIAN/*" -exec md5sum {} + | sort -k2 | sed "s, \+\*\?$PKG_ROOT/,  ," > $PKG_ROOT/DEBIAN/md5sums

echo "Package: skeleton-server
Version: $PKG_VER
Section: web
Priority: optional
Architecture: all
Maintainer: Thach Nguyen (https://github.com/nthachus)
Homepage: https://github.com/nthachus/angular8-skeleton
Description: An Angular application using Sinatra Restful-API skeleton.
Depends: ruby2.3, ruby-bundler, postgresql, nginx, file
Recommends: uchardet (>= 0.0.6), p7zip-rar, graphicsmagick
Suggests: libreoffice-writer (>= 1:6.1.5), libreoffice-calc (>= 1:6.1.5), libreoffice-impress (>= 1:6.1.5)
Installed-Size: $PKG_SIZE" > $PKG_ROOT/DEBIAN/control

echo '#!/bin/sh' > $PKG_ROOT/DEBIAN/postinst
echo "set -x

# Database
if [ ! -f /var/run/postgresql/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi
sudo -u postgres psql -c \"DROP ROLE IF EXISTS skeleton; CREATE ROLE skeleton WITH LOGIN CREATEDB PASSWORD '$DB_PWD'\"
cd $APP_HOME && rake db:drop db:setup RACK_ENV=production

# Website
ln -sf /etc/nginx/sites-available/skeleton.conf /etc/nginx/sites-enabled/default

# Service
if [ -d /run/systemd/system ]; then
  systemctl --system daemon-reload
fi
systemctl enable unicorn-skeleton.service" >> $PKG_ROOT/DEBIAN/postinst

echo '#!/bin/sh' > $PKG_ROOT/DEBIAN/prerm
echo "set -x

# Database
if [ ! -f /var/run/postgresql/*.pid ]; then
  echo 'PostgreSQL is not running' >&2
  exit 1
fi
cd $APP_HOME && rake db:drop RACK_ENV=production
sudo -u postgres psql -c \"DROP ROLE IF EXISTS skeleton\"

# Website
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Service
if [ -d /run/systemd/system ]; then
  systemctl stop unicorn-skeleton.service
fi
systemctl disable unicorn-skeleton.service" >> $PKG_ROOT/DEBIAN/prerm

echo '#!/bin/sh' > $PKG_ROOT/DEBIAN/postrm
echo "set -x

# Service
if [ -d /run/systemd/system ]; then
  systemctl --system daemon-reload
fi" >> $PKG_ROOT/DEBIAN/postrm

# Build package
chmod +x $PKG_ROOT/DEBIAN/postinst $PKG_ROOT/DEBIAN/prerm $PKG_ROOT/DEBIAN/postrm
dpkg-deb --build $PKG_ROOT
mv -f $PKG_ROOT.deb "$(dirname "`realpath "$0"`")/"
rm -rf angular8-skeleton/ sinatra-rest-skeleton/ /tmp/*
