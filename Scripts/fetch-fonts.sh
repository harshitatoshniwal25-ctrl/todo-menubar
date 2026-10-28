#!/bin/bash
# Downloads Caveat and Shantell Sans (both OFL) from the Google Fonts repo into
# the bundle. Run once; the .ttf files are gitignored.
#
# Pinned to one commit of google/fonts and checked against known SHA-256
# fingerprints, so a build always ships exactly the files the app was tested
# with — and anything else, changed upstream or tampered with on the way, is
# refused rather than bundled. To move to newer fonts, change COMMIT, run this,
# and replace the fingerprints with the new ones it reports.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="Sources/ToDo/Resources/Fonts"
COMMIT="ddf386ba1b9fbc6b2c818f1ddcd9148f54ced94b"
BASE="https://raw.githubusercontent.com/google/fonts/${COMMIT}/ofl"
mkdir -p "$DEST"

fetch() {
  local path="$1" out="$2" want="$3"
  echo "fetching $out"
  curl -fsSL "$BASE/$path" -o "$DEST/$out.part"
  local got
  got=$(shasum -a 256 "$DEST/$out.part" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then
    rm -f "$DEST/$out.part"
    echo "refusing $out: fingerprint $got does not match $want" >&2
    exit 1
  fi
  mv "$DEST/$out.part" "$DEST/$out"
}

fetch "caveat/Caveat%5Bwght%5D.ttf" "Caveat.ttf" \
  0bdb6b660482d31531b3945849fba5916b3ef8695da7024a9e6b9ee3c4157988
fetch "shantellsans/ShantellSans%5BBNCE%2CINFM%2CSPAC%2Cwght%5D.ttf" "ShantellSans.ttf" \
  d98a7913853f78d71aa0b86daf66b5eddb5a3266c07bfd51ef70632b88c41084
# Both are OFL, which asks that the licence travel with the fonts.
fetch "caveat/OFL.txt" "Caveat-OFL.txt" \
  1f9d81d094273d82f3898a1ee8b598a717d050ecbf5ff7bede105b704880157b
fetch "shantellsans/OFL.txt" "ShantellSans-OFL.txt" \
  ebfce7d104d597c385b71e9fbf8f0e2034e73320f857086105dc265b82c05caa

echo
echo "done — rebuild with: ./Scripts/make-app.sh"
