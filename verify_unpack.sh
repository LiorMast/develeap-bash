#!/bin/bash

# Setup
mkdir -p verification_test
cd verification_test

# 1. Test single files (mimic test3/morefiles)
echo "file1" > f1.txt
bzip2 -k f1.txt
mv f1.txt.bz2 "1 RnM"

echo "file2" > f2.txt
compress -f f2.txt
mv f2.txt.Z "2 s2"

echo "file3" > f3.txt
zip -q "3 e5" f3.txt

echo "file4" > f4.txt
gzip -c f4.txt > "4 0037"

# 2. Test archives (should use tar)
mkdir tar_content
echo "tar_file" > tar_content/tf.txt
tar -cf archive.tar tar_content
tar -czf archive.tar.gz tar_content
tar -cjf archive.tar.bz2 tar_content
mv archive.tar.gz archive.tgz
mv archive.tar.bz2 archive.tbz

echo "--- Running unpack.sh ---"
../unpack.sh -v .

echo "--- Verification ---"
ls -R
