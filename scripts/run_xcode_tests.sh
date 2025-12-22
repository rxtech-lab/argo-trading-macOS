#!/bin/bash

# Script to run all Xcode tests for SmartContractApp
# Usage: ./scripts/run_xcode_tests.sh

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${GREEN}Running Xcode tests for ArgoTradingSwift...${NC}"
echo "Project root: $PROJECT_ROOT"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Check if the Xcode project exists
if [ ! -f "ArgoTradingSwift.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}Error: ArgoTradingSwift.xcodeproj not found${NC}"
    exit 1
fi

# Create test results directory
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
mkdir -p "$TEST_RESULTS_DIR"

# Define result bundle path
RESULT_BUNDLE="$TEST_RESULTS_DIR/TestResults.xcresult"

# Remove old result bundle if it exists
if [ -d "$RESULT_BUNDLE" ]; then
    rm -rf "$RESULT_BUNDLE"
fi

# Run tests
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Running ArgoTradingSwift tests${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Store the exit code to handle artifacts even on failure
set +e  # Don't exit on error for test command
xcodebuild test \
    -scheme ArgoTradingSwift \
    -destination 'platform=macOS' \
    -resultBundlePath "$RESULT_BUNDLE" \
    -enableCodeCoverage YES \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | tee "$TEST_RESULTS_DIR/xcodebuild.log"

TEST_EXIT_CODE=$?
set -e  # Re-enable exit on error

# Check if result bundle was created
if [ -d "$RESULT_BUNDLE" ]; then
    echo ""
    echo -e "${YELLOW}Test result bundle created at: $RESULT_BUNDLE${NC}"

    # Extract human-readable test results
    if command -v xcrun &> /dev/null; then
        echo -e "${YELLOW}Extracting test summary...${NC}"
        xcrun xcresulttool get --format json --path "$RESULT_BUNDLE" > "$TEST_RESULTS_DIR/test-summary.json" 2>/dev/null || true
    fi
fi

# Report results
echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All Xcode tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Xcode tests failed${NC}"
    echo -e "${YELLOW}Test artifacts available in: $TEST_RESULTS_DIR${NC}"
    exit 1
fi
