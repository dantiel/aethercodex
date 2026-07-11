#!/usr/bin/env bash
# Compile all CoffeeScript and SCSS files
set -e

DIR="$(dirname "$0")"

echo "⚒️ Compiling CoffeeScript…"
SRC_DIR="$DIR/pythia"
coffee --compile --bare --output "$SRC_DIR" "$SRC_DIR"/*.coffee

SRC_DIR="$DIR/../docs"
coffee --compile --bare --output "$SRC_DIR" "$SRC_DIR"/*.coffee

echo ""
bash "$DIR/forge_scss.sh"