FROM alpine:3.11

ENV LANG C.UTF-8
ENV BUNDLE_SILENCE_ROOT_WARNING=1

RUN apk update \
 && apk add --no-cache \
  abuild \
  ruby-full libpq \
  build-base linux-headers autoconf zlib-dev ruby-dev postgresql-dev \
  nodejs yarn \
 && rm -rf /var/cache/apk/* /tmp/*

# skip installing gem documentation
RUN printf 'install: --no-document\nupdate: --no-document\n' >> /etc/gemrc \
 && yarn config set disable-self-update-check true -g \
 && rm -rf ~/.config ~/.yarn* /tmp/* \
 && sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.6.0/rubygems/validator.rb
