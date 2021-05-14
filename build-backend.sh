#!/bin/sh
set -- sinatra-rest-skeleton '' "$(getconf LONG_BIT)$@"
. "$(dirname "$0")/download-prj.sh" "$@"

if [ -e "$PRJ_NAME/vendor/bundle/ruby"/*/bin/unicorn ]; then
  exit 0
fi

sed -i "s/^# \(gem 'rake'\)/\1/" "$PRJ_NAME/Gemfile"
sed -i '/^    \(json\|minitest\) /d' "$PRJ_NAME/Gemfile.lock"

( cd "$PRJ_NAME"; \
  bundle install --path vendor/bundle --without 'test:development' --no-cache; \
  tr '\n' '\f' < Gemfile.lock | sed 's/\f\(RUBY\|BUNDLED\).*//' | tr '\f' '\n' | tee Gemfile.lock; \
  GEM_HOME="$(echo "$PWD/vendor/bundle/ruby"/*)" gem check; \
  rm -rf .git* coverage/ log/* storage/* tmp/*/* ~/.bundle ~/.gem /tmp/* )

find "$PRJ_NAME/vendor/bundle/ruby"/*/extensions \( -iname '*.log' -o -iname '*.out' \) -type f -delete
if [ ! -e "$PRJ_NAME/db/seeds/production.rb" ]; then
  ln -s development.rb "$PRJ_NAME/db/seeds/production.rb"
fi

tar -czf "$OUT_FILE" -C "$PRJ_NAME/" .
tar -tzvf "$OUT_FILE" | sort -k6 > "${OUT_FILE%.*}.txt"
