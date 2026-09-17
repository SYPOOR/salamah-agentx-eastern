#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
flutter analyze
flutter test --timeout 60s
node --test proxy/test/proxy.test.mjs
