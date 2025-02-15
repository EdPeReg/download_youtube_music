#!/usr/bin/env bash

# This script reads a csv file what contains songs with Title,Artist format to be read
# To search that song on youtube and to pick that song to be download or not.
# TODO: Validate that xclip and brave-browser are installed.

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

read_csv() {
    # Read a csv file that contains Title,Artist as column, gets the information
    # from those two columns and save the content in a list.
    #
    # Parameters:
    #   $1: csv file path that contains songs list.
    #
    # Returns:
    #   songs_list(): Array that contains all the songs from the csv.
    #
    # Raises:
    #   Exit with code 1 if csv file don't have the "Title,Artist" in the first row.
    
    local headers
    local songs
    local indices=()
    local csv_path="$1"
    local i=1

    headers=$(head -n 1 "$csv_path" | tr '[:upper:]' '[:lower:]')
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
    songs=$(sed '1d' "$csv_path" | cut -f"${indices[0]}","${indices[1]}" -s -d, | sed 's/^"//;s/"$//' | sed 's/,/ - /g')
    mapfile -t songs_list <<< "$songs"
}

get_yt_id() {
    # Will save Title and Youtube URL in a list yt_urls based on the user's choice
    #
    # Parameters:
    #   $1: How many songs we wanto to search
    #   $2: The index from the songs_list
    #
    # Returns:
    #   yt_urls(): Array that will store "Title - URL"

    local num_songs="$1"
    local option="$2"

    # option choice starts with 1 and not 0
    ((option--))
    local song="${songs_list[option]}"

    local urls
    urls="$(yt-dlp "$(printf 'ytsearch%d:"%s"' "$num_songs" "$song")" --print "%(title)s (%(webpage_url)s)")"
    mapfile -t yt_urls <<< "$urls"
}

remove_song_csv() {
    # Removes a song given a csv file and index song, index song starts from 1 to ignore csv header
    #
    # Parameters:
    #   $1: csv file path that  contains the list songs
    #   $2: The song index to be removed from the csv, starting from 1

    local csv_path="$1"
    local index_song="$2"
    # Increase because starting from 1 is the header, we want to ignore the header
    ((index_song++))

    sed -i "$index_song"'d' "$csv_path"
}

select_from_list() {
    # Selects an item given a list with a custom prompt
    #
    # Parameters:
    #   $1: Array passed by reference that contains the items.
    #   $2: Custom message that wlil appear to prompt the user.
    #
    # Returns:
    #
    #   Returns the index from the item selected in "selected_index".

    local -n list="$1"
    local prompt_message="$2"
    local i=1

    for item in "${list[@]}"; do
        # Using >&2 makes to use stderr to show the content immediatelly, it is necessary
        # if we want to show information and use read.
        echo "[$i]    $item" >&2
        ((i++))
    done

    read -rp "$prompt_message" selected_index
    echo "$selected_index"
}

main() {
    local LIMIT_PARAM=1
    local no_songs=3
    local file_path
    local url
    local song

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
        index_song=$(select_from_list songs_list "Enter song number or [c] to cancel: ")

        # Just exit if the user decides to cancel
        if [[ "$index_song" =~ ^[cC]$ ]]; then
            break
        fi

        local index_song_bkp="$index_song"

        # Check if it is a number and it is in range
        if [[ "$index_song" =~ ^[0-9]+$ ]] && ((index_song >= 1 && index_song <= "${#songs_list[@]}")); then
            printf "\n%s\n" "[INFO] You have selected \"${songs_list[index_song-1]}\", getting URLS..."
            get_yt_id "$no_songs" "$index_song"

            while true; do
                index_url=$(select_from_list yt_urls "Enter URL number or [c] to cancel: ")
                # Just exit if the user decides to cancel
                if [[ "$index_url" =~ ^[cC]$ ]]; then
                    if [[ -n "$url" ]]; then
                        echo "[INFO]: You have selected \"$song\""
                    fi
                    break
                fi

                ((index_url--))
                song="${yt_urls[index_url]}"
                url=$(echo "$song" | grep -Eo 'https?://[^ >)]+')
                brave-browser --new-window "$url"
            done
        fi

        if [[ -n ${yt_urls[index_song_bkp]} ]]; then
            read -rp "Remove song from the csv: \"${songs_list[index_song_bkp - 1]}\"? y/n: " remove_option

            if [[ "$remove_option" =~ [Yy] ]]; then
                echo "[INFO]: Removing song \"${songs_list[index_song_bkp - 1]}\""
                remove_song_csv "$file_path" "$index_song_bkp"
            fi
        fi

        if [[ -n "$url" ]]; then
            # Thanks: https://stackoverflow.com/questions/5130968/how-can-i-copy-the-output-of-a-command-directly-into-my-clipboard
            # Copy url to the clipboard
            echo "$url" | xclip -sel clip
            echo "[INFO]: Copied to the clipboard"
            break
        fi
    done;

}

main "$@"
