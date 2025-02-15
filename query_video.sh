#!/usr/bin/env bash

# This script reads a csv file what contains songs with Title,Artist format to be read
# To search that song on youtube and to pick that song to be download or not.

DEBUG_MODE=false
if $DEBUG_MODE; then
    set -vx
fi

usage() {
    cat <<EOF

Usage: $0 <csv_file_path>

Where <csv_file_path> is a list of songs with at least Title,Artist columns.

Examples:
    ~/Documents/my_songs.csv

EOF
}

# songs_list=()
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
    if [[ "$headers" != *title* || "$headers" != *artist* ]]; then
        echo "Error: Headers from the first line should have column Title,Artist"
        exit 1
    fi

    indices=()
    i=1

    # Get comlumn indices from Title,Artist
    for header in ${headers//,/ }; do
        if [[ "$header" = "title" || "$header" = "artist" ]]; then
            indices+=("$i")
        fi
        ((i++))
    done

    # Delete the first row from the csv, get only the Title,Artist columns, remove the "" and replace "," with "-"
    songs=$(sed '1d' "$path" | cut -f"${indices[0]}","${indices[1]}" -s -d, | sed 's/^"//;s/"$//' | sed 's/,/ - /g')
    mapfile -t songs_list <<< "$songs"
}

prompt_user_song() {
    # Select the corresponding song number or "c" to cancel selection, saving the user choice in "option"
    local i

    i=1
    for song in "${songs_list[@]}"; do
        printf "[%s]\t%s\n" "$i" "$song"
        ((i++))
    done

    local max_index=$((i - 1))

    while true; do
        read -rp "Enter song number or [c] to cancel: " option_song

        # Just exit if the user decides to cancel
        if [[ "$option_song" =~ ^[cC]$ ]]; then
            break
        fi

        # Check if it is a number and it is in range
        if [[ "$option_song" =~ ^[0-9]+$ ]] && ((option_song >= 1 && option_song <= max_index)); then
            break
        fi

        echo "Enter a valid song number (1-$max_index) or [c] to cancel"
    done;
}

get_yt_id() {
    # Will save Title and Youtube URL in a list yt_urls based on the user's choice
    yt_urls=()

    local no_songs="$1"
    local option="$2"

    # option choice starts with 1 and not 0
    ((option--))
    local song="${songs_list[option]}"

    local urls
    urls="$(yt-dlp "$(printf 'ytsearch%d:"%s"' "$no_songs" "$song")" --print "%(title)s (%(webpage_url)s)")"
    mapfile -t yt_urls <<< "$urls"
}

main() {
    local LIMIT_PARAM
    local no_songs
    local file_path

    LIMIT_PARAM=1
    no_songs=3

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

    while true; do
        # Select the corresponding song number or "c" to cancel selection, saving the user choice in "option"
        local i=1
        for song in "${songs_list[@]}"; do
            printf "[%s]\t%s\n" "$i" "$song"
            ((i++))
        done

        local max_index=$((i - 1))

        read -rp "Enter song number or [c] to cancel: " option_song

        # Just exit if the user decides to cancel
        if [[ "$option_song" =~ ^[cC]$ ]]; then
            break
        fi

        # Check if it is a number and it is in range
        if [[ "$option_song" =~ ^[0-9]+$ ]] && ((option_song >= 1 && option_song <= max_index)); then
            printf "\n%s\n" "[INFO] You have selected \"${songs_list[option_song-1]}\", getting URLS..."
            get_yt_id "$no_songs" "$option_song"

            while true; do
                i=1
                for url in "${yt_urls[@]}"; do
                    printf "[%s]\t%s\n" "$i" "$url"
                    ((i++))
                done

                read -rp "Enter url number or [c] to cancel: " option_url

                # Just exit if the user decides to cancel
                if [[ "$option_url" =~ ^[cC]$ ]]; then
                    break
                fi

                ((option_url--))
                local url
                url=$(echo "${yt_urls[option_url]}" | grep -Eo 'https?://[^ >)]+')

                brave-browser --new-window "$url"
            done
        fi
    done;
}

main "$@"
