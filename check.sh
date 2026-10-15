#!/usr/bin/env bash
# Local CI gate — mirrors .github/workflows/ci.yml. Run from WSL:
#   bash check.sh
set -eo pipefail
cd "$(dirname "$0")"

TOOLS=~/.rokit/tool-storage
SELENE=$(find $TOOLS/kampfkarren/selene -name selene -type f | sort -V | tail -1)
STYLUA=${STYLUA:-$(find $TOOLS/johnnymorganz/stylua -name stylua -type f | sort -V | tail -1)}
LSP=$(find $TOOLS/johnnymorganz/luau-lsp -name luau-lsp -type f | sort -V | tail -1)
ROJO=${ROJO:-~/bin/rojo}

echo "==> selene src"
if ! $SELENE --allow-warnings src/ > /tmp/selene.log 2>&1; then
	grep -B2 -A6 '^error' /tmp/selene.log || cat /tmp/selene.log
	echo "FAILED: selene"
	exit 1
fi
tail -4 /tmp/selene.log

echo "==> stylua --check src tests"
$STYLUA --check src/ tests/

echo "==> rojo sourcemap"
$ROJO sourcemap -o sourcemap.json

echo "==> luau-lsp analyze"
LSP_STATUS=0
$LSP analyze \
  --definitions types/globalTypes.d.lua \
  --sourcemap sourcemap.json \
  --ignore 'Packages/**' --ignore 'DevPackages/**' --ignore 'src/shared/Vendor/**' \
  src/ > /tmp/luau-lsp.log 2>&1 || LSP_STATUS=$?
grep -v '^\[INFO\]' /tmp/luau-lsp.log | grep -v 'didChangeWatchedFiles' | sort -u || true
if [ "$LSP_STATUS" -ne 0 ]; then
	echo "FAILED: luau-lsp analyze"
	exit 1
fi

echo "==> rojo build"
$ROJO build -o /tmp/shootblox-check.rbxl
ls -la /tmp/shootblox-check.rbxl

echo "==> All checks passed."
