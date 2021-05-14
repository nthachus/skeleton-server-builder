FROM alpine:3.11

ENV LANG C.UTF-8
ENV BUNDLE_SILENCE_ROOT_WARNING=1

RUN apk update \
 && apk add --no-cache \
  ruby-full libpq \
  build-base linux-headers autoconf zlib-dev ruby-dev postgresql-dev \
  nodejs yarn \
  abuild unzip \
 && rm -rf /var/cache/apk/* /tmp/*

# skip installing gem documentation
RUN printf 'install: --no-document\nupdate: --no-document\n' >> /etc/gemrc \
 && sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.6.0/rubygems/validator.rb

RUN adduser root abuild \
 && addgroup -S -g 82 www-data \
 && adduser -S -u 82 -D -H -h /var/www -g www-data -G www-data www-data \
 && yarn config set disable-self-update-check true -g \
 && rm -rf ~/.config ~/.yarn* /tmp/* \
