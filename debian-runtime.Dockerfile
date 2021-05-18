FROM nthachus/debian-systemd:stretch-slim

RUN sed -i 's,/deb\.debian\.org/,/debian.xtdv.net/,' /etc/apt/sources.list \
 && sed -i 's/^deb.* main$/& contrib non-free/' /etc/apt/sources.list \
 && mkdir -p /usr/share/man/man1 /usr/share/man/man7 \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends \
  rsyslog cron logrotate curl \
  ruby ruby-bundler \
  postgresql nginx \
  p7zip-rar graphicsmagick \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

RUN echo 'deb http://debian.xtdv.net/debian buster main' > /etc/apt/sources.list.d/buster.list \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends \
  file uchardet \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* /etc/apt/sources.list.d/buster.list

ENV BUNDLE_SILENCE_ROOT_WARNING=1

RUN sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/*/rubygems/validator.rb \
 && sed -i "s/#\(listen_addresses\)/\1 = '*'\n&/" /etc/postgresql/*/main/postgresql.conf \
 && sed -i 's,# IPv6,host\tall\t\tall\t\t192.168.0.0/16\t\tmd5\n&,' /etc/postgresql/*/main/pg_hba.conf

VOLUME ["/var/lib/postgresql/data"]
EXPOSE 5432 80 443
