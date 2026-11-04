#!/bin/bash
# Builds "Phone Mirror.app" next to this script. Needs Apple's command line tools:
#   xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swiftc >/dev/null; then
  echo "swiftc not found. Run:  xcode-select --install   then re-run this script."
  exit 1
fi

APP="Phone Mirror.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 main.swift \
  -o "$APP/Contents/MacOS/PhoneMirror" \
  -framework Cocoa -framework AVFoundation -framework CoreMedia -framework CoreMediaIO

codesign --force --sign - "$APP"
echo "Built: $(pwd)/$APP"
echo "Open it with:  open \"$APP\"   (or drag it into /Applications)"
