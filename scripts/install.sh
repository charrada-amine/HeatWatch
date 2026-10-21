#!/bin/bash
# Construit HeatWatch, l'installe dans ~/Applications et le lance.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build-app.sh
pkill -x HeatWatch || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/HeatWatch.app"
cp -R build/HeatWatch.app "$HOME/Applications/"
open "$HOME/Applications/HeatWatch.app"
echo "Installé : $HOME/Applications/HeatWatch.app"
