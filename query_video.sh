#!/usr/bin/bash

# This script reads a csv file what contains songs with Title,Artist format to be read
# To search that song on youtube and to pick that song to be download or not.

songs_list=()

usage() {
    cat <<EOF

Usage: $0 <csv_file_path>

Where <csv_file_path> is a list of songs with at least Title,Artist columns.

Examples:
    ~/Documents/my_songs.csv

EOF
}

read_csv() {
    # Read a csv file that contains Title,Artist as column, gets the information
    # from those two columns and save the content in a list.
    # It will exit with 1 if csv file don't have Title,Artist in the first row.
    
    local headers
    local indices
    local songs
    local path
    local i

    path="$1"
    headers=$(head -n 1 "$path" | tr '[:upper:]' '[:lower:]')
    # Check headers Title and Artist exist
    if [[ "$headers" != *title* ]] || [[ "$headers" != *artist* ]]; then
        echo "Error: Headers from the first line should have column Title,Artist"
        exit 1
    fi

    indices=()
    i=1

    # Get comlumn indices from Title,Artist
    for header in ${headers//,/ }; do
        if [[ "$header" = "title" ]] || [[ "$header" = "artist" ]]; then
            indices+=("$i")
        fi
        i=$((i+1))
    done

    songs=$(sed '1d' "$path" | cut -f"${indices[0]}","${indices[1]}" -s -d, | sed 's/^"//;s/"$//')
    while IFS= read -r line; do
        songs_list+=("$line")
    done <<< "$songs"
}

main() {
    local LIMIT_PARAM
    local file_path

    LIMIT_PARAM=1
    if [[ "$#" -ne $LIMIT_PARAM ]]; then
        usage
        exit 1
    fi

    file_path=$(realpath "$1")
    if [[ ! -e "$file_path" ]]; then
        echo "File $file_path doesn't exist, provide an existing file"
        exit 1
    fi

    read_csv "$file_path"
}

main "$@"