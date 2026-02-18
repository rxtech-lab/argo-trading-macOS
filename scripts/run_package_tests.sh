#!/bin/bash
#
# run_package_tests.sh
# Runs swift test for all Swift packages in the packages/ folder
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PACKAGES_DIR="$ROOT_DIR/packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FAILED_PACKAGES=()
PASSED_PACKAGES=()

# Check if xcpretty is available
if command -v xcpretty &> /dev/null; then
    FORMATTER="xcpretty"
else
    echo -e "${YELLOW}xcpretty not found, using raw output${NC}"
    FORMATTER="cat"
fi

echo -e "${BLUE}=== Running Package Tests ===${NC}"
echo "Packages directory: $PACKAGES_DIR"
echo ""

# Check if packages directory exists
if [ ! -d "$PACKAGES_DIR" ]; then
    echo -e "${RED}Error: packages directory not found at $PACKAGES_DIR${NC}"
    exit 1
fi

# Find all Package.swift files in packages/
PACKAGE_COUNT=0
for package_file in "$PACKAGES_DIR"/*/Package.swift; do
    # Check if glob matched any files
    if [ ! -f "$package_file" ]; then
        echo -e "${YELLOW}No Swift packages found in $PACKAGES_DIR${NC}"
        exit 0
    fi

    PACKAGE_COUNT=$((PACKAGE_COUNT + 1))
    package_dir=$(dirname "$package_file")
    package_name=$(basename "$package_dir")

    echo -e "${BLUE}Testing package: ${package_name}${NC}"
    echo "----------------------------------------"

    cd "$package_dir"
    if swift test 2>&1 | $FORMATTER; then
        echo -e "${GREEN}PASSED: ${package_name}${NC}"
        PASSED_PACKAGES+=("$package_name")
    else
        echo -e "${RED}FAILED: ${package_name}${NC}"
        FAILED_PACKAGES+=("$package_name")
    fi
    echo ""
done

# Print summary
echo "========================================"
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "========================================"
echo "Total packages: $PACKAGE_COUNT"
echo -e "${GREEN}Passed: ${#PASSED_PACKAGES[@]}${NC}"
echo -e "${RED}Failed: ${#FAILED_PACKAGES[@]}${NC}"

if [ ${#PASSED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Passed packages:${NC}"
    for pkg in "${PASSED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done
fi

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed packages:${NC}"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  - $pkg"
    done
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}All package tests passed!${NC}"
exit 0
