#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${1:-$HOME/Applications/QuickNote.app}"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

swiftc \
  -O \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  "$SCRIPT_DIR/Models.swift" \
  "$SCRIPT_DIR/ContentView.swift" \
  "$SCRIPT_DIR/QuickNoteApp.swift" \
  -o "$MACOS_DIR/QuickNote"

codesign --force --deep --sign - "$APP_DIR"

echo "Built successfully: $APP_DIR"
