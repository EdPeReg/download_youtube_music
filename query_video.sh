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
    local songs
    local indices=()
    local path="$1"
    local i=1

    headers=$(head -n 1 "$path" | tr '[:upper:]' '[:lower:]')
    # Check headers Title and Artist exist
    if [[ "$headers" != *title* || "$headers" != *artist* ]]; then
        echo "Error: Headers from the first line should have column Title,Artist"
        exit 1
    fi

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

    local i=1
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

remove_song_csv() {
    # Removes a song given a csv file and index song, index song starts from 1 to ignore csv header

    local csv_path="$1"
    local index_song="$2"
    # Increase because starting from 1 is the header, we want to ignore the header
    ((index_song++))

    sed -i "$index_song"'d' "$csv_path"
}

main() {
    local LIMIT_PARAM=1
    local no_songs=3
    local file_path
    local url

    if [[ "$#" -ne $LIMIT_PARAM ]]; then
        usage
        exit 1
    fi

    file_path=$(realpath "$1")
    if [[ ! -e "$file_path" ]]; then
        echo "File $file_path doesn't exist, provide an existing file"
        exit 1
    fi

    while true; do
        read_csv "$file_path"

        # Select the corresponding song number or "c" to cancel selection, saving the user choice in "option"
        local i=1
        for song in "${songs_list[@]}"; do
            printf "[%s]\t%s\n" "$i" "$song"
            ((i++))
        done

        local max_index=$((i - 1))

        read -rp "enter song number or [c] to cancel: " index_song

        # Just exit if the user decides to cancel
        if [[ "$index_song" =~ ^[cC]$ ]]; then
            break
        fi

        local index_song_bkp="$index_song"

        # Check if it is a number and it is in range
        if [[ "$index_song" =~ ^[0-9]+$ ]] && ((index_song >= 1 && index_song <= max_index)); then
            printf "\n%s\n" "[INFO] You have selected \"${songs_list[index_song-1]}\", getting URLS..."
            get_yt_id "$no_songs" "$index_song"

            while true; do
                i=1
                for url_i in "${yt_urls[@]}"; do
                    printf "[%s]\t%s\n" "$i" "$url_i"
                    ((i++))
                done

                read -rp "Enter url number or [c] to cancel: " index_url

                # Just exit if the user decides to cancel
                if [[ "$index_url" =~ ^[cC]$ ]]; then
                    if [[ -n "$url" ]]; then
                        echo "[INFO]: You have selected ${yt_urls[index_url]}"
                        echo "[INFO]: Copied to the clipboard"
                    fi
                    break
                fi

                ((index_url--))
                url=$(echo "${yt_urls[index_url]}" | grep -Eo 'https?://[^ >)]+')
                brave-browser --new-window "$url"
            done
        fi

        if [[ -n ${yt_urls[index_song_bkp]} ]]; then
            read -rp "Remove song: \"${songs_list[index_song_bkp - 1]}\"? y/n: " remove_option

            if [[ "$remove_option" =~ [Yy] ]]; then
                echo "[INFO]: Removing song \"${songs_list[index_song_bkp - 1]}\""
                remove_song_csv "$file_path" "$index_song_bkp"
            fi
        fi

        if [[ -n "$url" ]]; then
            # Thanks: https://stackoverflow.com/questions/5130968/how-can-i-copy-the-output-of-a-command-directly-into-my-clipboard
            # Copy url to the clipboard
            echo "$url" | xclip -sel clip
            break
        fi
    done;

}

main "$@"
