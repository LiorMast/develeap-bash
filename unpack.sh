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

get_output_name() {
    local file="$1"
    local base=$(basename "$file")
    local dir=$(dirname "$file")
    
    # Handle compound extensions first
    if [[ "$base" == *.tgz || "$base" == *.taz ]]; then
        echo "$dir/${base%.*}.tar"
        return
    elif [[ "$base" == *.tbz || "$base" == *.tbz2 ]]; then
        echo "$dir/${base%.*}.tar"
        return
    fi
    
    # Handle standard extension removal
    local name="${base%.*}"
    if [[ "$name" != "$base" ]]; then
        echo "$dir/$name"
    else
        # No extension (or unknown), append .out
        echo "$dir/$base.out"
    fi
}


decompress_file() {
    local file="$1"
    local file_type=$(file -b --mime-type "$file")
    local file_name=$(basename "$file")
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        return 1
    fi

    case "$file_type" in
        application/gzip | application/x-gzip)
            [[ $verbose == true ]] && echo "Unpacking $file_name..."
            local target=$(get_output_name "$file")
            # Use -c to write to stdout and redirect to target, avoiding suffix issues
            if gunzip -c "$file" > "$target"; then
                return 0
            else
                rm -f "$target" # Cleanup on failure (e.g. valid empty file created before error)
                return 1
            fi
            ;;
        application/x-bzip2)
            [[ $verbose == true ]] && echo "Unpacking $file_name..."
            local target=$(get_output_name "$file")
            # Use -c to avoid "Can't guess original name" and allow explicit target
            if bunzip2 -c "$file" > "$target"; then
                return 0
            else
                rm -f "$target"
                return 1
            fi
            ;;
        application/zip)
            [[ $verbose == true ]] && echo "Unpacking $file_name..."
            # -o: overwrite without prompting
            # -d: extract to the file's directory
            if unzip -o -q "$file" -d "$(dirname "$file")"; then
                return 0
            else
                return 1
            fi
            ;;
        application/x-compress)
            [[ $verbose == true ]] && echo "Unpacking $file_name..."
            local target=$(get_output_name "$file")
            if uncompress -c "$file" > "$target"; then
                return 0
            else
                rm -f "$target"
                return 1
            fi
            ;;
        *)
            # According to specs: "Warn for each file that was NOT decompressed" is handled by verbose check here?
            # Actually, "Warn for each file that was NOT decompressed" is usually for -v.
            # But "Uncompressed files: Take no action"
            [[ $verbose == true ]] && echo "Ignoring $file_name"
            return 1
            ;;
    esac
    # return $decompressed_count
}

traverse_dir() {
    local dir="$1"
    
    # Enable nullglob to handle empty directories correctly
    local shopt_nullglob=$(shopt -p nullglob)
    shopt -s nullglob
    local files=("$dir"/*) #if nullglob is not set, this could result in an error if the directory is empty because the glob expansion fails
    $shopt_nullglob
    
    for item in "${files[@]}"; do
        if [[ -d "$item" ]]; then
            if [[ $recursive == true ]]; then
                traverse_dir "$item"
            fi
        elif [[ -f "$item" ]]; then
            if decompress_file "$item"; then
                decompressed_count=$((decompressed_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
        else
            # Count non-files/non-dirs as failures
            fail_count=$((fail_count + 1))
        fi
    done
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
        # "Directory input: Decompress all files in that directory (one level deep without -r)"
        # But wait, looking at "Directory input: Decompress all files in that directory (one level deep without -r)"
        # And "Recursive Directory Handling ... Processed some-folder and all subfolders"
        
        # My traverse_dir handles recursion if $recursive is true.
        # But if $recursive is false, traverse_dir ONLY iterates the current dir?
        # My traverse_dir implementation:
        # if [[ -d "$item" ]]; then if [[ $recursive == true ]]; then traverse_dir ...
        # So yes, it handles the "one level deep without -r" automatically by NOT recursing.
        
        traverse_dir "$file"
    else
        # Argument that is neither file nor directory (e.g. invalid path)
        # Should we count this as fail?
        # "Exit code: Return the exact number of files NOT decompressed"
        [[ $verbose == true ]] && echo "Ignoring $file"
        fail_count=$((fail_count + 1))
    fi
done


echo "Decompressed $decompressed_count archive(s)"


exit $fail_count
    