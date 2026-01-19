#!/bin/bash

verbose=false
recursive=false


decompressed_count=0
fail_count=0

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
ensure_dependency "uncompress" "ncompress"


decompress_file() {
    local file="$1"
    local file_type=$(file -b --mime-type "$file")
    case "$file_type" in
        application/gzip | application/x-gzip)
            [[ $verbose == true ]] && echo "Unpacking $file..."
            gunzip "$file"
            ;;
        application/x-bzip2)
            [[ $verbose == true ]] && echo "Unpacking $file..."
            bunzip2 "$file"
            ;;
        application/zip)
            [[ $verbose == true ]] && echo "Unpacking $file..."
            unzip -q "$file"
            ;;
        application/x-compress)
            [[ $verbose == true ]] && echo "Unpacking $file..."
            uncompress "$file"
            ;;
        *)
            [[ $verbose == true ]] && echo "Ignoring $file"
            ;;
    esac
    # return $decompressed_count
}

while [[ $1 =~ ^-.*$ ]] ; do
    case $1 in
        -v)
            verbose=true
            ;;
        -r)
            recursive=true
            ;;
        -vr|-rv)
            verbose=true
            recursive=true
            ;;
        -*)
            echo "Invalid option: $1" >&2
            exit 1
            ;;

    esac
    shift
done

if [[ $# -eq 0 ]]; then # no arguments left
    echo "Usage: $0 [-r] [-v] file [files...]" >&2
    exit 1
fi


for file in "$@"; do
    if [[ -f "$file" ]]; then
        if decompress_file "$file"; then
            decompressed_count=$((decompressed_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    elif [[ -d "$file" ]]; then
        if [[ $verbose = true ]]; then
            echo "$file is a directory"
        fi
        
    else
        fail_count=$((fail_count + 1))
    fi
done


echo "Decompressed $decompressed_count files"


exit $fail_count
    