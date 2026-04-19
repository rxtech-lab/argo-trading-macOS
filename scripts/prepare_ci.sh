#!/bin/bash

# prepare_ci.sh — fetch large test fixtures not committed to git.
# Used by CI and can be run locally: ./scripts/prepare_ci.sh

set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

S3_BASE="${S3_BASE:-https://argoswift.s3.ap-southeast-1.amazonaws.com}"

STRATEGY_DIR="$PROJECT_ROOT/testdata/strategy"
DATA_DIR="$PROJECT_ROOT/testdata/data"

mkdir -p "$STRATEGY_DIR" "$DATA_DIR"

download() {
    local url="$1"
    local dest="$2"
    echo -e "${BLUE}→${NC} $url"
    echo -e "  to ${dest#$PROJECT_ROOT/}"
    curl -fL --retry 3 --retry-delay 2 --progress-bar -o "$dest" "$url"
    echo -e "${GREEN}✓${NC} $(ls -lh "$dest" | awk '{print $5, $9}')"
    echo ""
}

echo "======================================"
echo "Preparing CI test fixtures"
echo "======================================"
echo ""

download \
    "$S3_BASE/place_order_plugin.wasm" \
    "$STRATEGY_DIR/place_order_plugin.wasm"

download \
    "$S3_BASE/BTCUSDT_2026-04-18_2026-04-19_1_minute.parquet" \
    "$DATA_DIR/BTCUSDT_2026-04-18_2026-04-19_1_minute.parquet"

echo -e "${GREEN}All fixtures ready${NC}"
