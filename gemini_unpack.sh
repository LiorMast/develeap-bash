#!/bin/bash

# ==============================================================================
# Script Name: unpack.sh [cite: 17, 85]
# Synopsis: unpack [-r] [-v] file [files...] [cite: 19]
# Description: Handles multiple compressed files, traverses directories, 
# detects types automatically, and maintains original archives.
# ==============================================================================

# --- Global Variables ---
VERBOSE=false
RECURSIVE=false
DECOMPRESSED_COUNT=0
FAILED_COUNT=0

# --- Argument Parsing [cite: 31] ---
# Parse command line options -r and -v
while getopts ":rv" opt; do
  case ${opt} in
    r)
      RECURSIVE=true # Traverse directories recursively 
      ;;
    v)
      VERBOSE=true   # Echo file details and warnings [cite: 33]
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1)) # Shift positional arguments to access files

# --- Functions ---

# Function: unpack_file
# Purpose: Detects file type and attempts decompression 
unpack_file() {
    local file_path="$1"
    local dir_path
    dir_path=$(dirname "$file_path")
    local filename
    filename=$(basename "$file_path")
    
    # 1. Parse 'file' command output to detect compression type 
    # ignoring extensions 
    local file_type
    file_type=$(file -b "$file_path")
    
    local unpacked=false

    # 2. Choose decompression method [cite: 22, 25]
    # Design allows simple addition of new formats [cite: 30]
    case "$file_type" in
        *"gzip compressed data"*)
            # [cite: 26] gunzip: -k (keep original), -f (overwrite)
            if gunzip -k -f "$file_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        *"bzip2 compressed data"*)
            # [cite: 27] bunzip2: -k (keep original), -f (overwrite)
            if bunzip2 -k -f "$file_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        *"Zip archive data"*)
            # [cite: 28] unzip: -o (overwrite), -d (destination dir)
            # Extracts to same directory 
            if unzip -o -q "$file_path" -d "$dir_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        *"compress'd data"*)
            # [cite: 29] uncompress
            # Standard uncompress replaces files, so we use -c and redirection 
            # to satisfy "Keep original"  and "Overwrite".
            # We strip the extension for the output name.
            local out_name="${file_path%.*}"
            # Logic to prevent overwriting the source if it lacks an extension
            if [ "$out_name" == "$file_path" ]; then
                out_name="${file_path}.extracted"
            fi
            
            if uncompress -c "$file_path" > "$out_name" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        *)
            # Not an archive logic handled below
            ;;
    esac

    # 3. Handle status updates and counters
    if [ "$unpacked" = true ]; then
        ((DECOMPRESSED_COUNT++))
        if [ "$VERBOSE" = true ]; then
             echo "Unpacking $filename..." # [cite: 35, 59]
        fi
    else
        # Count files NOT decompressed 
        ((FAILED_COUNT++))
        if [ "$VERBOSE" = true ]; then
            echo "Ignoring $filename" # [cite: 35, 60]
        fi
    fi
}

# Function: traverse
# Purpose: Handles directory recursion and file processing logic
traverse() {
    local path="$1"
    local is_root_arg="$2" # "true" if this was passed directly by user

    if [ -f "$path" ]; then
        # It's a file, try to unpack it
        unpack_file "$path"

    elif [ -d "$path" ]; then
        # It's a directory
        # Logic: Directory input: Decompress all files in that directory 
        # (one level deep without -r) 
        
        # We process children if:
        # 1. We are at the root argument (regardless of -r)
        # 2. OR if RECURSIVE is true (subfolders) [cite: 37]
        
        if [ "$is_root_arg" = true ] || [ "$RECURSIVE" = true ]; then
            # Loop through contents
            # We use finding to handle space safety and strict file separation
            for item in "$path"/*; do
                # Check if glob expansion failed (empty directory)
                [ -e "$item" ] || continue
                
                if [ -d "$item" ]; then
                    # If it's a subdir, only recurse if -r flag was set
                    if [ "$RECURSIVE" = true ]; then
                        traverse "$item" "false"
                    else
                         # Subfolders ignored (no -r flag) - do nothing [cite: 71]
                         : 
                    fi
                elif [ -f "$item" ]; then
                    unpack_file "$item"
                fi
            done
        fi
    fi
}

# --- Main Execution ---

# Iterate over all provided arguments
for arg in "$@"; do
    traverse "$arg" "true"
done

# Output: Echo amount of decompressed files 
echo "Decompressed $DECOMPRESSED_COUNT archive(s)"

# Exit code: Return exact number of files NOT decompressed 
exit $FAILED_COUNT