# Notes

- **This is for personal use, if someone else use it, there are 1000% chances it won't work :)**
- I'm using YtDlp from ruby library, this library doesn't have support to show the progress, because the --print-json flag in its command, this is required to get json information and download the video. Workaroud, run yt-dlp directly from cmd or use another library or wait until YtDlp supports to show progress using hooks.
- It is better to pass the `$@` to the main function instead the single argument `$1` because if you don't pass `$1` to main, it will be a single empty string and still count as argument, passing `$@` it won't make this happen.
- `shellcheck` was used to analize the `query_video.sh`
- If you use `echo` or `printf` before `read`, you will need to flush the buffer.


# App Features & Changes (Download youtube music)

This document summarizes the current features and notable changes implemented in the project.

## Overview
A small interactive CLI tool to find, download, rename, tag and play music (mp3) files using yt-dlp and TagLib. It also includes a helper shell script to query songs from CSV files.

## Quick links
- Main app: [main.rb](main.rb)  
- CSVs: [shazamlibrary.csv](shazamlibrary.csv), [shazamlibrary.csv.bkp](shazamlibrary.csv.bkp)  
- CLI helper script: [query_video.sh](query_video.sh)  
- Tests / experiments: [test.rb](test.rb)  
- Python Drive sample: [download_youtube_music/src/test.py](download_youtube_music/src/test.py)  
- History files: [history.txt](history.txt), [history with duplicates.txt](history with duplicates.txt)  
- Gemfile: [Gemfile](Gemfile)  
- .gitignore: [.gitignore](.gitignore)  
- Readme / notes: [readme.md](readme.md)

## Implemented features

- Downloading audio from YouTube
  - Entry point: [`download_song`](main.rb) — downloads audio from a given YouTube URL using the Ruby yt-dlp wrapper.  
  - Underlying call: [`download_audio`](main.rb) which calls `YtDlp.download`.
  - Default options: [`default_download_options`](main.rb) — extracts audio and converts to `mp3` by default.
  - Output naming: supports custom output template via `options[:output]`.

- Chapter / range support
  - Chapter selection: [`handle_chapters`](main.rb) — shows available chapters and lets user pick one.
  - Manual chop (time-range): [`chop_video`](main.rb) — validates ranges with `TIME_RANGE_REGEX` and returns the formatted range for yt-dlp.

- Filename and artist handling
  - Optional rename prompt: [`rename_file_if_needed`](main.rb) — let user rename a file and optionally prepend artist (from parent folder).
  - Post-download verification: [`verify_download`](main.rb) — asserts the file exists after download.

- Local music search & file operations
  - Search local music: [`search_files`](main.rb) — recursive case-insensitive search under the configured music folder.
  - List files: [`list_songs`](main.rb).
  - Rename files: [`rename_song`](main.rb) — interactive rename, preserves artist prefix when not provided.
  - Play files: [`play_song`](main.rb) — fires `vlc <file>`.

- Tagging metadata (TagLib)
  - Interactive tagging: [`tag_song`](main.rb) — read and update tag fields `:comment`, `:album`, `:artist` using TagLib (`require 'taglib'`).
  - Notes: TagLib returns empty string for missing fields; the code checks `.empty?` before appending.

- CSV integration & external query flow
  - Spawn CSV query GUI/script: [`run_query_video`](main.rb) — spawns [query_video.sh](query_video.sh) in a detached process.
  - `query_video.sh` parses a CSV with Title & Artist columns, de-duplicates rows, runs `yt-dlp` search to get candidate URLs, opens the chosen result in `brave-browser`, and can remove selected rows from the CSV.

- Readline history
  - Load and save CLI history: [`load_history`](main.rb) / [`save_history`](main.rb) with `history.txt`.
  - History deduplication: `save_history` writes unique history entries (`uniq`).

- Interactive CLI menu
  - Main loop: [`main`](main.rb) exposes options:
    - [D]ownload song → download flow
    - [F]ind Song/Artist → search files
    - [R]ename song → rename local files
    - [P]lay song → open with VLC
    - [G]et song from csv → call `query_video.sh`
    - [T]ag song → metadata editor
    - [E]xit

## Key constants / helpers
- [`TIME_RANGE_REGEX`](main.rb) — regex used to validate start-end HH:MM:SS ranges.
- [`FILE_NAME`](main.rb) — history filename (`history.txt`).
- [`ROOT_FOLDER_SCRIPT`](main.rb) — script root directory resolution.

## Notable files & experiments
- [test.rb](test.rb) — experiments with yt-dlp options and Readline completion.
- [download_youtube_music/src/test.py](download_youtube_music/src/test.py) — Python sample to access Google Drive (credentials flow).
- [shazamlibrary.csv.bkp](shazamlibrary.csv.bkp) — backup CSV with many entries and duplicates; `query_video.sh` includes logic to de-duplicate rows.

## Known TODOs and caveats
- See inline TODOs in [main.rb](main.rb) and notes in [readme.md](readme.md).
  - Drive integration (access Google Drive to pull URLs).
  - Auto-detect artist from YouTube title if missing.
  - Fix rename bug when filename contains `-`.
  - The Ruby `yt-dlp.rb` gem currently lacks progress-hooks support the author needs; the readme and [test.rb](test.rb) document this limitation and workarounds (using `--print-json` / raw yt-dlp).
- .gitignore contains `*.csv` but CSVs in repo may already be tracked — if a CSV was previously committed git will keep tracking it until removed from the index.

## How to run (basics)
1. Install gems: `bundle install` (see [Gemfile](Gemfile)).  
2. Run main script: `ruby main.rb`.  
3. Use the interactive menu to download, tag, or query songs.

## Where to look in code (functions)
- main flow and CLI: [`main`](main.rb)  
- Download & yt-dlp integration: [`download_song`](main.rb), [`download_audio`](main.rb), [`default_download_options`](main.rb)  
- Chapter & chopping: [`handle_chapters`](main.rb), [`chop_video`](main.rb), [`TIME_RANGE_REGEX`](main.rb)  
- Filesystem helpers: [`create_folder`](main.rb), [`verify_download`](main.rb), [`rename_file_if_needed`](main.rb)  
- Local music search & playback: [`search_files`](main.rb), [`list_songs`](main.rb), [`rename_song`](main.rb), [`play_song`](main.rb)  
- Tagging: [`tag_song`](main.rb) (uses `taglib`)  
- CSV query orchestration: [`run_query_video`](main.rb) → [query_video.sh](query_video.sh)  
- History: [`load_history`](main.rb), [`save_history`](main.rb)



# References

- [yt-dlp official git documentation](https://github.com/yt-dlp/yt-dlp)
- [yt-dlp python documentation](https://pypi.org/project/yt-dlp/#output-template)
- [yt-dlp ruby gem][https://rubygems.org/gems/yt-dlp.rb/versions/0.2.0?locale=en]
- [yt-dlp official documentation](https://www.rubydoc.info/gems/yt-dlp.rb/#install-the-gem)
- [Regex special characters to escape](https://stackoverflow.com/questions/399078/what-special-characters-must-be-escaped-in-regular-expressions)
- [taglib](https://github.com/robinst/taglib-ruby)

- https://developers.google.com/drive/api/guides/handle-errors
- https://docs.rs/google-youtube3/latest/google_youtube3/
- https://docs.rs/google-drive/latest/google_drive/files/struct.Files.html#method.get
- https://doc.rust-lang.org/nightly/core/result/enum.Result.html
- https://lib.rs/crates/drive-v3
- https://developers.google.com/drive/api/quickstart/python#authorize_credentials_for_a_desktop_application
- https://console.cloud.google.com/apis/credentials/consent?project=eng-name-426603-u4
- https://docs.rs/drive-v3/latest/drive_v3/struct.Drive.html#structfield.files
- https://developers.google.com/drive/api/guides/search-files#python
