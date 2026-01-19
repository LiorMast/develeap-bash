#!/bin/bash

# Directory setup
TEST_DIR="test_env"
SUB_DIR="$TEST_DIR/subfolder"
rm -rf "$TEST_DIR"
mkdir -p "$SUB_DIR"

echo "Creating test environment in '$TEST_DIR'..."

# --- Create Dummy Content ---
echo "This is a text file." > dummy.txt

# --- Create Archives in Root ($TEST_DIR) ---

# 1. Zip file
cp dummy.txt file1.txt
zip -q "$TEST_DIR/test_zip.zip" file1.txt
rm file1.txt

# 2. Gzip file
cp dummy.txt file2.txt
gzip -c file2.txt > "$TEST_DIR/test_gzip.gz"
rm file2.txt

# 3. Bzip2 file
cp dummy.txt file3.txt
bzip2 -c file3.txt > "$TEST_DIR/test_bzip.bz2"
rm file3.txt

# 4. Compress (.Z) file
# Note: 'compress' might not be installed by default on all modern Ubuntu systems.
# If 'compress' is missing, install 'ncompress' via 'sudo apt install ncompress'.
if command -v compress &> /dev/null; then
    cp dummy.txt file4.txt
    compress -c file4.txt > "$TEST_DIR/test_compress.Z"
    rm file4.txt
else
    echo "Warning: 'compress' utility not found. Skipping .Z file creation."
fi

# 5. Non-archive text file
cp dummy.txt "$TEST_DIR/not_an_archive.txt"

# --- Create Archives in Subdirectory ($SUB_DIR) ---

# 6. Zip in subdir
cp dummy.txt sub_file1.txt
zip -q "$SUB_DIR/sub_test_zip.zip" sub_file1.txt
rm sub_file1.txt

# 7. Non-archive in subdir
cp dummy.txt "$SUB_DIR/sub_text.txt"

# Cleanup
rm dummy.txt

echo "Test files created successfully."
echo "------------------------------------------------"
echo "Structure created:"
tree "$TEST_DIR" 2>/dev/null || find "$TEST_DIR" -print | sed -e "s;[^/]*/;|____;g;s;____|; |;g"
echo "------------------------------------------------"
echo "You can now run your unpack script against this folder."
echo "Example 1 (Normal): ./unpack.sh $TEST_DIR"
echo "Example 2 (Recursive): ./unpack.sh -r $TEST_DIR"
echo "Example 3 (Verbose): ./unpack.sh -v $TEST_DIR/*"