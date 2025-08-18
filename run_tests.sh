#!/bin/bash

# Script to run tests for Virtual Running Companion
# This script can be used when Swift is available in the environment

echo "Running Virtual Running Companion Tests..."

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed or not in PATH"
    echo "Please install Swift or Xcode command line tools"
    exit 1
fi

# Run Swift Package Manager tests
echo "Running Swift Package Manager tests..."
swift test

# Check test results
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed. Please check the output above."
    exit 1
fi