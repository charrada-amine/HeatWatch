#!/bin/bash
# Usage : scripts/calibrate.sh [secondes au repos] [secondes en charge] [cœurs]
# Relève la température du CPU toutes les 10 s : d'abord au repos, puis pendant scripts/stress.sh.
set -uo pipefail
cd "$(dirname "$0")/.."
idle=${1:-180}
load=${2:-180}
cores=${3:-4}
swift build -c release >/dev/null || exit 1
BIN=.build/release/HeatWatch

read_temp() { "$BIN" --probe | awk -F': ' '/^Processeur/ { sub(/ °C/, "", $2); print $2 }'; }

measure() { # <phase> <seconds>
    local phase=$1 seconds=$2 end=$((SECONDS + $2)) values=()
    while [ $SECONDS -lt $end ]; do
        local t
        t=$(read_temp)
        values+=("$t")
        echo "$(date +%T)  $phase  $t °C"
        sleep 10
    done
    printf '%s\n' "${values[@]}" | awk -v p="$phase" '
        { s += $1; if (NR == 1 || $1 < min) min = $1; if ($1 > max) max = $1 }
        END { printf "== %s : min %.1f °C, moyenne %.1f °C, max %.1f °C (%d mesures)\n", p, min, s / NR, max, NR }' >> "$SUMMARY"
}

SUMMARY=$(mktemp)
trap 'rm -f "$SUMMARY"; kill "$stress_pid" 2>/dev/null' EXIT
measure repos "$idle"
scripts/stress.sh "$cores" "$load" &
stress_pid=$!
measure "charge-${cores}c" "$load"
wait "$stress_pid" 2>/dev/null
cat "$SUMMARY"
