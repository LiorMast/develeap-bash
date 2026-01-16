#!/bin/bash

verbose=false
recursive=false


decompressed_count=0
fail_count=0

for cmd in file gunzip bunzip2 tar unzip; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed." >&2
        echo "Installing dependencies..."
        install_dependencies
    fi
done

install_dependencies() {
    local pkgs=("file" "gzip" "bzip2" "tar" "unzip" "ncompress")
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y "${pkgs[@]}"
    elif command -v yum &> /dev/null; then
        sudo yum install -y "${pkgs[@]}"
    elif command -v brew &> /dev/null; then
        brew install "${pkgs[@]}"
    else
        echo "Error: No supported package manager found. Please install ${pkgs[*]} manually." >&2
        return 1
    fi
}


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

if [[ $# -eq 0 ]]; then
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
        # if [[ $recursive = true ]]; then

        # fi
    else
        fail_count=$((fail_count + 1))
    fi
done


echo "Decompressed $decompressed_count files"


exit $fail_count
    