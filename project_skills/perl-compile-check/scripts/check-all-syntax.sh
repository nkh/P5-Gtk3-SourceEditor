#!/bin/bash
# check-all-syntax.sh -- Run perl -c on every .pm, .pl, and .t file in the project
# Usage: bash check-all-syntax.sh [src_dir]
#   src_dir defaults to the parent of this script's location

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${1:-$(dirname "$SCRIPT_DIR")/src}"

if [ ! -d "$SRC_DIR/lib" ]; then
    echo "ERROR: $SRC_DIR/lib not found. Usage: $0 [path/to/src]" >&2
    exit 1
fi

PASS=0
FAIL=0
WARN=0

echo "=========================================="
echo "  Perl Syntax Check: $SRC_DIR"
echo "=========================================="
echo ""

check_file() {
    local file="$1"
    local output
    output=$(perl -I"$SRC_DIR/lib" -I"$SRC_DIR/t/lib" -c "$file" 2>&1)
    if echo "$output" | grep -q "syntax OK"; then
        PASS=$((PASS + 1))
    elif echo "$output" | grep -q "syntax error\|Can't locate"; then
        FAIL=$((FAIL + 1))
        echo "FAIL: $file"
        echo "  $output"
    else
        # Warnings only (like "used only once")
        WARN=$((WARN + 1))
    fi
}

# Check all .pm files in lib/
for f in $(find "$SRC_DIR/lib" -name "*.pm" | sort); do
    check_file "$f"
done

# Check all scripts
for f in "$SRC_DIR"/script/*.pl "$SRC_DIR"/script/source-*; do
    [ -f "$f" ] && check_file "$f"
done

# Check all test files
for f in "$SRC_DIR"/t/*.t; do
    [ -f "$f" ] && check_file "$f"
done

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $WARN warnings, $FAIL failures"
echo "=========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1
