#!/usr/bin/bash

usage() {
    cat <<EOF

Usage: $0 <csv_file_path>

Where <csv_file_path> is a list of songs with at least Title,Artist columns.

Examples:
    ~/Documents/my_songs.csv

EOF
}

read_csv() {
    local headers
    local indices
    local songs
    local path
    local i

    path="$1"
    headers=$(< "$path" grep -E '[Tt]itle')
    headers=$(echo "$headers" | tr '[:upper:]' '[:lower:]')
    indices=()
    i=1

    for header in ${headers//,/ }; do
        if [[ "$header" = "title" ]] || [[ "$header" = "artist" ]]; then
            indices+=("$i")
        fi
        i=$((i+1))
    done

    songs=$(< "$path" cut -f"${indices[0]}","${indices[1]}" -s -d,) 
    songs=$(tail -n +2 <<< "$songs")
    songs="${songs//\",\"/ - }"
    songs=$(sed -e 's/^"//' -e 's/"$//' <<< "$songs")
    
    songs_list=()
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