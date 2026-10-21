#!/bin/bash
# Construit HeatWatch, l'installe dans /Applications et le lance.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=/Applications/HeatWatch.app
scripts/build-app.sh
pkill -x HeatWatch || true
rm -rf "$DEST"
cp -R build/HeatWatch.app "$DEST"
# Older versions were installed in ~/Applications: remove that copy so only one remains.
rm -rf "$HOME/Applications/HeatWatch.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST" || true
open "$DEST"
echo "Installé : $DEST"
