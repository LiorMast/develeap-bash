#!/bin/bash

# ==============================================================================
# Script Name: unpack.sh
# Synopsis: unpack [-r] [-v] file [files...]
# Description: Handles multiple compressed files, traverses directories, 
# detects types automatically, and maintains original archives.
# Includes automatic dependency detection and installation.
# ==============================================================================

# --- Global Variables ---
VERBOSE=false
RECURSIVE=false
DECOMPRESSED_COUNT=0
FAILED_COUNT=0

# --- Dependency Management ---

# Function: ensure_dependency
# Purpose: Checks if a command exists; if not, attempts to install the package.
ensure_dependency() {
    local cmd_name="$1"
    local pkg_name="$2"

    # echo "Checking for dependency: '$cmd_name' for package '$pkg_name'"


    if ! command -v "$cmd_name" &> /dev/null; then
        echo "Missing required dependency: '$cmd_name'. Attempting to install package '$pkg_name'..."
        
        # Check if user has sudo privileges or is root
        if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
            echo "Error: Cannot install '$pkg_name'. Please run as root or install sudo." >&2
            exit 1
        fi

        # Attempt installation
        # We use -y to automatically say yes to prompts
        if ! sudo apt-get update -qq || ! sudo apt-get install -y "$pkg_name" &> /dev/null; then
            echo "Error: Failed to install '$pkg_name'. Please install it manually." >&2
            exit 1
        fi
    fi
}

# Check all required tools before processing arguments
# Format: ensure_dependency "command_to_check" "package_to_install"
ensure_dependency "file" "file"
ensure_dependency "gunzip" "gzip"
ensure_dependency "bunzip2" "bzip2"
ensure_dependency "unzip" "unzip"
ensure_dependency "uncompress" "ncompress" # 'uncompress' is usually provided by 'ncompress' on Ubuntu

# --- Argument Parsing ---
# Parse command line options -r and -v

while [[ $1 =~ ^-.*$ ]] ; do
    echo "$1"
    case $1 in
        -v)
            verbose=true
            echo "Verbose mode enabled"
            ;;
        -r)
            recursive=true
            echo "Recursive mode enabled"
            ;;
        -vr|-rv)
            verbose=true
            recursive=true
            echo "Verbose and recursive mode enabled"
            ;;
        -*)
            echo "Invalid option: $1" >&2
            exit 1
            ;;

    esac
    shift
done

# --- Functions ---

# Function: unpack_file
# Purpose: Detects file type and attempts decompression [cite: 21]
unpack_file() {
    local file_path="$1"
    local dir_path
    dir_path=$(dirname "$file_path")
    local filename
    filename=$(basename "$file_path")
    
    # 1. Parse 'file' command output to detect compression type
    # ignoring extensions [cite: 39]
    local file_type
    file_type=$(file -b --mime-type "$file_path")
    
    local unpacked=false

    # 2. Choose decompression method [cite: 22]
    # Design allows simple addition of new formats [cite: 30]
    case "$file_type" in
        application/gzip | application/x-gzip)
            # gunzip: -k (keep original), -f (overwrite) [cite: 26, 22, 23]
            if gunzip -k -f "$file_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        application/x-bzip2)
            # bunzip2: -k (keep original), -f (overwrite) [cite: 27, 22, 23]
            if bunzip2 -k -f "$file_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        application/zip)
            # unzip: -o (overwrite), -d (destination dir)
            # Extracts to same directory [cite: 28, 22]
            if unzip -o -q "$file_path" -d "$dir_path" 2>/dev/null; then
                unpacked=true
            fi
            ;;
        application/x-compress)
            # uncompress [cite: 29]
            # Standard uncompress replaces files, so we use -c and redirection 
            # to satisfy "Keep original" and "Overwrite".
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
             echo "Unpacking $filename..." # [cite: 59]
        fi
    else
        # Count files NOT decompressed [cite: 41]
        ((FAILED_COUNT++))
        if [ "$VERBOSE" = true ]; then
            echo "Ignoring $filename" # [cite: 60]
        fi
    fi
}

# Function: traverse
# Purpose: Handles directory recursion and file processing logic [cite: 17, 37]
traverse() {
    local path="$1"
    local is_root_arg="$2" # "true" if this was passed directly by user

    if [ -f "$path" ]; then
        # It's a file, try to unpack it
        unpack_file "$path"

    elif [ -d "$path" ]; then
        # It's a directory
        # Logic: Directory input: Decompress all files in that directory 
        # (one level deep without -r) [cite: 40]
        
        # We process children if:
        # 1. We are at the root argument (regardless of -r)
        # 2. OR if RECURSIVE is true (subfolders) [cite: 36]
        
        if [ "$is_root_arg" = true ] || [ "$RECURSIVE" = true ]; then
            # Loop through contents
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

# Iterate over all provided arguments [cite: 19]
for arg in "$@"; do
    traverse "$arg" "true"
done

# Output: Echo amount of decompressed files [cite: 40]
echo "Decompressed $DECOMPRESSED_COUNT archive(s)"

# Exit code: Return exact number of files NOT decompressed [cite: 41]
exit $FAILED_COUNT