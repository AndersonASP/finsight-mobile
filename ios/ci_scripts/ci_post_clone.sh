#!/bin/sh
# Xcode Cloud runs this right after cloning, before resolving packages and
# building. Its machines have no Flutter, so install it and generate what
# `flutter build` normally writes for Xcode: Generated.xcconfig (dart-defines,
# version) and the Swift package with the plugins.
set -eu

FLUTTER_VERSION="3.44.8"
API_BASE_URL="${API_BASE_URL:-https://finsight-api-1007046506524.southamerica-east1.run.app}"

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch "$FLUTTER_VERSION" "$HOME/flutter"
  export PATH="$HOME/flutter/bin:$PATH"
fi

flutter --version
flutter precache --ios

cd "$APP_DIR"
flutter pub get

# CI_BUILD_NUMBER grows with every Xcode Cloud build, so each upload to
# TestFlight gets a new build number; the version name stays from pubspec.yaml.
flutter build ios --config-only --release --no-codesign \
  --build-number="${CI_BUILD_NUMBER:-1}" \
  --dart-define=API_BASE_URL="$API_BASE_URL"
