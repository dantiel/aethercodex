#!/usr/bin/env bash
# Compile all CoffeeScript files to JavaScript
SRC_DIR="$(dirname "$0")/ui"
coffee --compile --bare --output "$SRC_DIR" "$SRC_DIR"/*.coffee
