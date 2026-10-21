#!/bin/bash
# Usage : scripts/stress.sh <cœurs> <secondes>
# Occupe des cœurs avec `yes`, puis les arrête, même si le script est interrompu.
workers=${1:-2}
seconds=${2:-240}
pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null; }
trap cleanup EXIT INT TERM
for _ in $(seq "$workers"); do
    yes > /dev/null &
    pids+=($!)
done
sleep "$seconds" & wait $!
