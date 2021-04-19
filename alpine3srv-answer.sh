#!/bin/sh
set -x

# Answer file for setup-alpine script
setup-alpine -c answerfile.cfg
sed -i -e 's/ alpine-test/ vm-alpine3/' -e 's, UTC, Asia/Ho_Chi_Minh,' -e 's/\(PROXYOPTS\)=.*/\1="none"/' \
  -e 's/\(APKREPOSOPTS\)=.*/\1="-1"/' -e 's/ \(openssh\|openntpd\)/ none/' -e 's/-m data/-m sys/' answerfile.cfg
setup-alpine -e -f answerfile.cfg
