FROM ubuntu:bionic

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

RUN sed -i 's,/archive\.ubuntu\.com/,/mirror.clearsky.vn/,' /etc/apt/sources.list \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends gpg gpg-agent \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/*

ADD http://deb.nodesource.com/gpgkey/nodesource.gpg.key /tmp/

RUN echo "deb http://deb.nodesource.com/node_10.x bionic main" > /etc/apt/sources.list.d/nodesource.list \
 && apt-key add /tmp/nodesource.gpg.key \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends \
  ruby ruby-bundler libpq5 \
  build-essential zlib1g-dev ruby-dev libpq-dev \
  nodejs \
  wget unzip \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* /etc/apt/sources.list.d/nodesource.list

ENV BUNDLE_SILENCE_ROOT_WARNING=1
RUN sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.5.0/rubygems/validator.rb

RUN npm install -g yarn@1 \
 && yarn config set disable-self-update-check true -g \
 && rm -rf ~/.npm ~/.config ~/.yarn* /tmp/*
