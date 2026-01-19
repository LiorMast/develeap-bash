#!/bin/bash

# Setup
TEST_DIR="test_unpack_env"
mkdir -p "$TEST_DIR"
mkdir -p "$TEST_DIR/sub1"
mkdir -p "$TEST_DIR/sub1/sub2"

# Create dummy files
touch "$TEST_DIR/file.txt"
echo "content" > "$TEST_DIR/test1.txt"
gzip -c "$TEST_DIR/test1.txt" > "$TEST_DIR/test1.txt.gz"
rm "$TEST_DIR/test1.txt"

echo "content2" > "$TEST_DIR/sub1/test2.txt"
gzip -c "$TEST_DIR/sub1/test2.txt" > "$TEST_DIR/sub1/test2.txt.gz"
rm "$TEST_DIR/sub1/test2.txt"

echo "content3" > "$TEST_DIR/sub1/sub2/test3.txt"
gzip -c "$TEST_DIR/sub1/sub2/test3.txt" > "$TEST_DIR/sub1/sub2/test3.txt.gz"
rm "$TEST_DIR/sub1/sub2/test3.txt"

echo "--- Test 1: unpack directory non-recursive ---"
./unpack.sh -v "$TEST_DIR"
ls -R "$TEST_DIR"
if [[ -f "$TEST_DIR/test1.txt" ]] && [[ ! -f "$TEST_DIR/sub1/test2.txt" ]]; then
    echo "PASS: Top level unpacked, subdirs ignored"
else
    echo "FAIL: Top level not unpacked or subdirs unpacked unexpectedly"
fi

# Clean up for next test
rm "$TEST_DIR/test1.txt"
rm -f "$TEST_DIR/sub1/test2.txt"

echo "--- Test 2: unpack directory recursive ---"
./unpack.sh -v -r "$TEST_DIR"
if [[ -f "$TEST_DIR/test1.txt" ]] && [[ -f "$TEST_DIR/sub1/test2.txt" ]] && [[ -f "$TEST_DIR/sub1/sub2/test3.txt" ]]; then
    echo "PASS: All levels unpacked"
else
    echo "FAIL: Recursion failed"
    [[ -f "$TEST_DIR/test1.txt" ]] || echo "  Missing level 1"
    [[ -f "$TEST_DIR/sub1/test2.txt" ]] || echo "  Missing level 2"
    [[ -f "$TEST_DIR/sub1/sub2/test3.txt" ]] || echo "  Missing level 3"
fi
