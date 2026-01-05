.PHONY: test build clean test-verbose

# Note: This package requires macOS 15+ with SwiftUI and WebKit.
# It cannot be built or tested on Linux.

# Run tests (macOS only)
test:
	@if [ "$$(uname)" = "Darwin" ]; then \
		xcodebuild test \
			-scheme LightweightChart \
			-destination 'platform=macOS' \
			-quiet; \
	else \
		echo "Error: This package requires macOS to build and test."; \
		exit 1; \
	fi

# Build the package (macOS only)
build:
	@if [ "$$(uname)" = "Darwin" ]; then \
		xcodebuild build \
			-scheme LightweightChart \
			-destination 'platform=macOS' \
			-quiet; \
	else \
		echo "Error: This package requires macOS to build."; \
		exit 1; \
	fi

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Run tests with verbose output (macOS only)
test-verbose:
	@if [ "$$(uname)" = "Darwin" ]; then \
		xcodebuild test \
			-scheme LightweightChart \
			-destination 'platform=macOS'; \
	else \
		echo "Error: This package requires macOS to build and test."; \
		exit 1; \
	fi
