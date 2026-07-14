#!/bin/bash
set -euo pipefail

# Only install on Release builds — Debug builds (Cmd+R) run straight from
# DerivedData as usual and don't touch /Applications.
if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

APP_NAME="WhiteThing.app"
SOURCE="$BUILT_PRODUCTS_DIR/$APP_NAME"
DEST="/Applications/$APP_NAME"

killall "WhiteThing" 2>/dev/null || true

rm -rf "$DEST"
ditto "$SOURCE" "$DEST"

open "$DEST" || true
