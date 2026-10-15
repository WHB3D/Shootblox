#!/usr/bin/env bash
# sb-test.sh [timeout] — automated Play Solo smoke test (run from WSL).
# Builds the place, launches Studio with a temporary autotest plugin, collects
# SBDIAG diagnostics and every script error from the Studio log, closes Studio,
# and ALWAYS removes the plugin (it would otherwise auto-Play any place opened).
set -u
cd "$(dirname "$0")/.."

PLACE=shootblox-selftest.rbxl
TIMEOUT="${1:-120}"
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
PLUGINS_DIR="/mnt/c/Users/user/AppData/Local/Roblox/Plugins"
LOGS_DIR="/mnt/c/Users/user/AppData/Local/Roblox/logs"
PLUGIN="$PLUGINS_DIR/sb-autotest.lua"
PID=""

cleanup() {
	rm -f "$PLUGIN"
	if [ -n "$PID" ]; then
		"$PS" -NoProfile -Command "Stop-Process -Id $PID -Force -ErrorAction SilentlyContinue" >/dev/null 2>&1
	fi
	echo "=== cleanup: plugin removed, studio closed ==="
}
trap cleanup EXIT

echo "=== build ==="
~/bin/rojo build selftest.project.json -o "$PLACE" | tail -1

mkdir -p "$PLUGINS_DIR"
cp tools/sb-autotest.lua "$PLUGIN"

WINPLACE=$(wslpath -w "$(realpath "$PLACE")")
BEFORE=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)

PID=$("$PS" -NoProfile -Command "
\$exe = Get-ChildItem \"\$env:LOCALAPPDATA\Roblox\Versions\" -Recurse -Filter RobloxStudioBeta.exe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
\$p = Start-Process -FilePath \$exe -ArgumentList '\"$WINPLACE\"' -PassThru
\$p.Id" | tr -d '\r')
if [ -z "$PID" ]; then
	echo "FATAL: studio launch failed"
	exit 1
fi
echo "studio pid: $PID"

LOG=""
for _ in $(seq 1 30); do
	LOG=$(ls -t "$LOGS_DIR"/*.log 2>/dev/null | head -1)
	if [ -n "$LOG" ] && [ "$LOG" != "$BEFORE" ]; then break; fi
	sleep 1
done
echo "log: $LOG"

DEADLINE=$((SECONDS + TIMEOUT))
while [ $SECONDS -lt $DEADLINE ]; do
	if grep -qa "SBDIAG plugin done" "$LOG" 2>/dev/null; then break; fi
	sleep 3
done

echo "=== diagnostics ==="
grep -a "SBDIAG" "$LOG" | sed 's/.*SBDIAG/SBDIAG/'

echo "=== game output ==="
grep -aE "\[(Shootblox|[A-Za-z]+Service|[A-Za-z]+Controller|HitboxHistory|RateLimiter|Server|Perf)\]" "$LOG" \
	| sed -E 's/^[^,]+,[^,]+,[^,]+,[0-9]+ *,?//' | grep -av SBDIAG | sort -u | head -40

echo "=== errors ==="
grep -aE "CreatorError|CreatorWarning|Script '" "$LOG" | sed -E 's/^[^,]+,[^,]+,[^,]+,[0-9]+ *,?//' | head -40
