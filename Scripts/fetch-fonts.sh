#!/bin/bash
# Downloads Caveat and Shantell Sans (both OFL) from the Google Fonts repo into
# the bundle. Run once; the .ttf files are gitignored.
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="Sources/ToDo/Resources/Fonts"
mkdir -p "$DEST"

fetch() {
  local url="$1" out="$2"
  echo "fetching $out"
  curl -fsSL "$url" -o "$DEST/$out"
}

fetch "https://github.com/google/fonts/raw/main/ofl/caveat/Caveat%5Bwght%5D.ttf" "Caveat.ttf"
fetch "https://github.com/google/fonts/raw/main/ofl/shantellsans/ShantellSans%5BBNCE%2CINFM%2CSPAC%2Cwght%5D.ttf" "ShantellSans.ttf"
# Both are OFL, which asks that the licence travel with the fonts.
fetch "https://github.com/google/fonts/raw/main/ofl/caveat/OFL.txt" "Caveat-OFL.txt"
fetch "https://github.com/google/fonts/raw/main/ofl/shantellsans/OFL.txt" "ShantellSans-OFL.txt"

# A 404 would otherwise leave a plausible-looking but empty bundle.
for f in Caveat.ttf ShantellSans.ttf Caveat-OFL.txt ShantellSans-OFL.txt; do
  [ -s "$DEST/$f" ] || { echo "missing $f"; exit 1; }
done

echo
echo "done — rebuild with: ./Scripts/make-app.sh"
