#!/bin/bash

# macOS Test Plan Script
# Runs the ArgoTradingSwift UI test plan with retry-on-failure.

set -e
set -o pipefail

echo "======================================"
echo "ArgoTradingSwift UI Test Plan"
echo "======================================"
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$PROJECT_ROOT/ArgoTradingSwift.xcodeproj"
SCHEME="${SCHEME:-ArgoTradingSwift}"
TEST_PLAN="${TEST_PLAN:-uitest}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DESTINATION="${DESTINATION:-platform=macOS}"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-$TEST_RESULTS_DIR/TestResults.xcresult}"
TEST_ITERATIONS="${TEST_ITERATIONS:-3}"
PARALLEL_WORKERS="${PARALLEL_WORKERS:-3}"

if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}Error: $PROJECT_PATH not found${NC}"
    exit 1
fi

mkdir -p "$TEST_RESULTS_DIR"
rm -rf "$RESULT_BUNDLE_PATH"

echo -e "${BLUE}Project:${NC} $PROJECT_PATH"
echo -e "${BLUE}Scheme:${NC} $SCHEME"
echo -e "${BLUE}Test Plan:${NC} $TEST_PLAN"
echo -e "${BLUE}Configuration:${NC} $CONFIGURATION"
echo -e "${BLUE}Destination:${NC} $DESTINATION"
echo -e "${BLUE}Result Bundle:${NC} $RESULT_BUNDLE_PATH"
echo -e "${BLUE}Test Iterations:${NC} $TEST_ITERATIONS"
echo -e "${BLUE}Parallel Workers:${NC} $PARALLEL_WORKERS"
echo ""

echo "Running tests..."
echo ""

set +e

if command -v xcbeautify &> /dev/null; then
    FORMATTER="xcbeautify"
elif command -v xcpretty &> /dev/null; then
    FORMATTER="xcpretty"
else
    echo -e "${YELLOW}No formatter found, using raw xcodebuild output${NC}"
    FORMATTER="cat"
fi

SIGNING_ARGS=()
if [ -n "$SIGNING_CERTIFICATE_NAME" ]; then
    echo -e "${BLUE}Signing:${NC} manual, identity=$SIGNING_CERTIFICATE_NAME"
    SIGNING_ARGS+=(
        CODE_SIGN_IDENTITY="$SIGNING_CERTIFICATE_NAME"
        CODE_SIGN_STYLE=Manual
    )
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        SIGNING_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
    fi
fi

xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -testPlan "$TEST_PLAN" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -resultBundlePath "$RESULT_BUNDLE_PATH" \
    -enableCodeCoverage YES \
    -allowProvisioningUpdates \
    -skipPackagePluginValidation \
    -skipMacroValidation \
    -retry-tests-on-failure \
    -test-iterations "$TEST_ITERATIONS" \
    -test-repetition-relaunch-enabled YES \
    -parallel-testing-enabled YES \
    -parallel-testing-worker-count "$PARALLEL_WORKERS" \
    "${SIGNING_ARGS[@]}" \
    2>&1 | tee "$TEST_RESULTS_DIR/xcodebuild.log" | $FORMATTER

TEST_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ -d "$RESULT_BUNDLE_PATH" ]; then
    echo ""
    echo -e "${YELLOW}Test result bundle: $RESULT_BUNDLE_PATH${NC}"
    if command -v xcrun &> /dev/null; then
        xcrun xcresulttool get --format json --path "$RESULT_BUNDLE_PATH" > "$TEST_RESULTS_DIR/test-summary.json" 2>/dev/null || true
    fi
fi

echo ""
echo "======================================"

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Tests failed${NC}"
    echo -e "${YELLOW}Artifacts: $TEST_RESULTS_DIR${NC}"
    exit 1
fi
