#!/bin/bash

###############################################################################
# Test Script for Hidden Managed Package Detection
#
# Purpose: Verify that the detection function correctly identifies hidden content
# Usage: ./test-hidden-detection.sh
###############################################################################

set -e

# Create test directory
TEST_DIR="$(mktemp -d)/test-metadata"
mkdir -p "$TEST_DIR/main/default/lwc/testComponent1"
mkdir -p "$TEST_DIR/main/default/lwc/testComponent2"
mkdir -p "$TEST_DIR/main/default/lwc/legitimateComponent"

echo "Creating test files..."

# Test Component 1: All files hidden with "hidden;"
echo "hidden;" > "$TEST_DIR/main/default/lwc/testComponent1/testComponent1.js"
echo "(hidden)" > "$TEST_DIR/main/default/lwc/testComponent1/testComponent1.html"
echo "(hidden)" > "$TEST_DIR/main/default/lwc/testComponent1/testComponent1.css"
echo "(hidden)" > "$TEST_DIR/main/default/lwc/testComponent1/testComponent1.js-meta.xml"

# Test Component 2: Mixed hidden and non-hidden
echo "hidden;" > "$TEST_DIR/main/default/lwc/testComponent2/testComponent2.js"
echo "<template><h1>Real Content</h1></template>" > "$TEST_DIR/main/default/lwc/testComponent2/testComponent2.html"

# Legitimate Component: Real content
cat > "$TEST_DIR/main/default/lwc/legitimateComponent/legitimateComponent.js" << 'EOF'
import { LightningElement } from 'lwc';

export default class LegitimateComponent extends LightningElement {
    // Real code here
}
EOF

echo "<template><div>Content</div></template>" > "$TEST_DIR/main/default/lwc/legitimateComponent/legitimateComponent.html"

# Define the detection function inline for testing
is_hidden_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local file_size=$(wc -c < "$file" 2>/dev/null | tr -d ' ' || echo "999")
    if [[ $file_size -gt 10 ]]; then
        return 1
    fi

    local content=$(cat "$file" 2>/dev/null | tr -d '[:space:]' || echo "")

    if [[ "$content" == "hidden" ]] || [[ "$content" == "hidden;" ]] || [[ "$content" == "(hidden)" ]]; then
        return 0
    fi

    return 1
}

echo ""
echo "Running detection tests..."
echo "=========================="

# Test 1: Hidden file detection
echo ""
echo "Test 1: Detecting hidden files"
echo "-------------------------------"

test_file="$TEST_DIR/main/default/lwc/testComponent1/testComponent1.js"
if is_hidden_file "$test_file"; then
    echo "✓ PASS: Correctly detected 'hidden;' pattern"
else
    echo "✗ FAIL: Failed to detect 'hidden;' pattern"
fi

test_file="$TEST_DIR/main/default/lwc/testComponent1/testComponent1.html"
if is_hidden_file "$test_file"; then
    echo "✓ PASS: Correctly detected '(hidden)' pattern"
else
    echo "✗ FAIL: Failed to detect '(hidden)' pattern"
fi

# Test 2: Legitimate file detection (should NOT be flagged as hidden)
echo ""
echo "Test 2: Ignoring legitimate files"
echo "----------------------------------"

test_file="$TEST_DIR/main/default/lwc/legitimateComponent/legitimateComponent.js"
if is_hidden_file "$test_file"; then
    echo "✗ FAIL: False positive - flagged legitimate file as hidden"
else
    echo "✓ PASS: Correctly ignored legitimate file"
fi

# Test 3: File size check
echo ""
echo "Test 3: File size validation"
echo "-----------------------------"

# Create a file that's too large but has "hidden;" content
large_file="$TEST_DIR/main/default/lwc/testComponent2/large.js"
echo "hidden; with extra content that makes it too large" > "$large_file"

if is_hidden_file "$large_file"; then
    echo "✗ FAIL: Incorrectly flagged large file as hidden"
else
    echo "✓ PASS: Correctly ignored file > 10 bytes"
fi

# Test 4: Component analysis
echo ""
echo "Test 4: Component-level analysis"
echo "---------------------------------"

echo "Analyzing testComponent1 (all files hidden):"
hidden_count=0
total_count=0
for file in "$TEST_DIR/main/default/lwc/testComponent1"/*; do
    if [[ -f "$file" ]]; then
        total_count=$((total_count + 1))
        if is_hidden_file "$file"; then
            hidden_count=$((hidden_count + 1))
        fi
    fi
done

if [[ $hidden_count -eq 4 ]] && [[ $total_count -eq 4 ]]; then
    echo "✓ PASS: Correctly identified all 4 files as hidden"
else
    echo "✗ FAIL: Expected 4/4 hidden files, got $hidden_count/$total_count"
fi

echo ""
echo "Analyzing testComponent2 (mixed content):"
hidden_count=0
total_count=0
for file in "$TEST_DIR/main/default/lwc/testComponent2"/*; do
    if [[ -f "$file" ]]; then
        total_count=$((total_count + 1))
        if is_hidden_file "$file"; then
            hidden_count=$((hidden_count + 1))
        fi
    fi
done

if [[ $hidden_count -eq 1 ]] && [[ $total_count -eq 3 ]]; then
    echo "✓ PASS: Correctly identified 1/3 files as hidden"
else
    echo "✗ FAIL: Expected 1/3 hidden files, got $hidden_count/$total_count"
fi

# Cleanup
rm -rf "$(dirname "$TEST_DIR")"

echo ""
echo "=========================="
echo "Test suite complete!"
echo "=========================="
