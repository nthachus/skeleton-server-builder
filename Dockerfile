FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8

RUN echo "deb http://deb.nodesource.com/node_10.x stretch main" > /etc/apt/sources.list.d/nodesource.list \
 && apt-get update -qq \
 && apt-get install -qy --no-install-recommends --allow-unauthenticated \
  ruby ruby-bundler libpq5 \
  build-essential zlib1g-dev ruby-dev libpq-dev \
  nodejs \
  wget unzip \
 && rm -rf /var/cache/apt/* /var/lib/apt/lists/* /tmp/* /etc/apt/sources.list.d/nodesource.list

RUN npm install -g yarn@1 \
 && yarn config set disable-self-update-check true -g \
 && rm -rf ~/.npm ~/.config /tmp/* \
 && sed -i 's/"Extra file"/&\n\t  File.unlink File.join(gem_directory, extra)/' /usr/lib/ruby/2.3.0/rubygems/validator.rb

ENV BUNDLE_SILENCE_ROOT_WARNING=1
