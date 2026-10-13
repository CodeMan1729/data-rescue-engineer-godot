#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../firmware"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
cp player.c player.h trace_harness.c "$temp/"
gcc -std=c11 -Wall -Wextra "$temp/player.c" "$temp/trace_harness.c" -o "$temp/old"
"$temp/old" >"$temp/old.txt" || true
grep -Fq 'SUMMARY|1|4|2|2' "$temp/old.txt"
grep -Fq 'STEP|1|4|0|7|1|41424341424300' "$temp/old.txt"
python3 - "$temp/player.c" <<'PY'
import pathlib, sys
f=pathlib.Path(sys.argv[1])
s=f.read_text()
s=s.replace('    uint8_t snapshot[4096] = {0};\n    memcpy(snapshot, out, *used);\n','')
s=s.replace('out[start + i] = snapshot[start - distance + i];','out[start + i] = out[start + i - distance];')
f.write_text(s)
PY
gcc -std=c11 -Wall -Wextra "$temp/player.c" "$temp/trace_harness.c" -o "$temp/fixed"
"$temp/fixed" >"$temp/fixed.txt"
grep -Fq 'SUMMARY|4|4|2|2' "$temp/fixed.txt"
grep -Fq 'STEP|1|4|0|7|1|41424341424341' "$temp/fixed.txt"
echo 'C harness PASSED. Original 1/4+2 guards, fixed 4/4+2 guards. Real trace checked.'
