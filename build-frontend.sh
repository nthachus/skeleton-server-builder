#!/bin/sh
set -- angular8-skeleton '' "$@"
. "$(dirname "$0")/download-prj.sh" "$@"

if [ -f "$PRJ_NAME/dist/ng8-skeleton/index.html" ]; then
  exit 0
fi

( cd "$PRJ_NAME"; \
  yarn; yarn cache clean; yarn build; \
  rm -rf node_modules/ ~/.yarn* /tmp/* )

tar -czf "$OUT_FILE" -C "$PRJ_NAME/" .
tar -tzvf "$OUT_FILE" | sort -k6 > "${OUT_FILE%.*}.txt"
