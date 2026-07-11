#!/usr/bin/env bash
# Compile all SCSS files to CSS
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Locate Dart Sass — prefer project-local, fall back to system
if [ -x "$ROOT/Support/bin/dart-sass/sass" ]; then
  SASS="$ROOT/Support/bin/dart-sass/sass"
elif command -v sass &>/dev/null && sass --version 2>&1 | grep -q dart; then
  SASS="sass"
else
  echo "⚠️ dart-sass not found — install with: npm install -g sass"
  exit 1
fi

compile_dir() {
  local src_dir="$1"
  for scss in "$src_dir"/*.scss; do
    [ -e "$scss" ] || continue
    local css="${scss%.scss}.css"
    echo "  ✦ ${scss#$ROOT/} → ${css#$ROOT/}"
    "$SASS" --no-source-map --style=compressed "$scss" "$css"
  done
}

echo "⚒️ Compiling SCSS…"
compile_dir "$ROOT/Support/pythia"
compile_dir "$ROOT/docs"
echo "✅ Done."