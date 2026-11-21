#!/bin/sh
set -eu
SCHEME="${1:-roothide}"
case "$SCHEME" in
  roothide|rootless) ;;
  *) echo "Unsupported package scheme: $SCHEME" >&2; exit 2 ;;
esac
export THEOS_PACKAGE_SCHEME="$SCHEME"
export ARCHS="arm64e"
make clean
make package THEOS_PACKAGE_SCHEME="$SCHEME"
find packages -type f -name '*.deb' -print
