#!/usr/bin/env bash
# Local CI gate — mirrors .github/workflows/ci.yml. Run from WSL:
#   bash check.sh
set -e
cd "$(dirname "$0")"

TOOLS=~/.rokit/tool-storage
SELENE=$(find $TOOLS/kampfkarren/selene -name selene -type f | sort -V | tail -1)
STYLUA=${STYLUA:-$(find $TOOLS/johnnymorganz/stylua -name stylua -type f | sort -V | tail -1)}
LSP=$(find $TOOLS/johnnymorganz/luau-lsp -name luau-lsp -type f | sort -V | tail -1)
ROJO=${ROJO:-~/bin/rojo}

echo "==> selene src"
$SELENE src/ 2>&1 | tail -4

echo "==> stylua --check src tests"
$STYLUA --check src/ tests/

echo "==> rojo sourcemap"
$ROJO sourcemap -o sourcemap.json

echo "==> luau-lsp analyze"
$LSP analyze \
  --definitions types/globalTypes.d.lua \
  --sourcemap sourcemap.json \
  --ignore 'Packages/**' --ignore 'DevPackages/**' --ignore 'src/shared/Vendor/**' \
  src/ 2>&1 | grep -v '^\[INFO\]' | grep -v 'didChangeWatchedFiles' || true

echo "==> rojo build"
$ROJO build -o /tmp/shootblox-check.rbxl
ls -la /tmp/shootblox-check.rbxl

echo "==> All checks passed."
