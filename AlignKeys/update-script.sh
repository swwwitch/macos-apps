#!/bin/zsh
# ./update-script.sh  copy the latest IdAlignToNearestEdgePalette.jsx from indesign-scripts into Script/ (then build again)
set -euo pipefail
cd "${0:A:h}"
source="${ALIGNKEYS_SCRIPT_SOURCE:-$HOME/Git/indesign-scripts/jsx/frame/IdAlignToNearestEdgePalette.jsx}"
cp "$source" Script/IdAlignToNearestEdgePalette.jsx
grep -m1 '^var SCRIPT_VERSION' Script/IdAlignToNearestEdgePalette.jsx
