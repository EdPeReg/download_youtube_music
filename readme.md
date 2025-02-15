# Notes

- **This is for personal use, if someone else use it, there are 1000% chances it won't work :)**
- I'm using YtDlp from ruby library, this library doesn't have support to show the progress, because the --print-json flag in its command, this is required to get json information and download the video. Workaroud, run yt-dlp directly from cmd or use another library or wait until YtDlp supports to show progress using hooks.
- It is better to pass the `$@` to the main function instead the single argument `$1` because if you don't pass `$1` to main, it will be a single empty string and still count as argument, passing `$@` it won't make this happen.
- `shellcheck` was used to analize the `query_video.sh`
- If you use `echo` or `printf` before `read`, you will need to flush the buffer.

# References

- [yt-dlp official git documentation](https://github.com/yt-dlp/yt-dlp)
- [yt-dlp python documentation](https://pypi.org/project/yt-dlp/#output-template)
- [yt-dlp ruby gem][https://rubygems.org/gems/yt-dlp.rb/versions/0.2.0?locale=en]
- [yt-dlp official documentation](https://www.rubydoc.info/gems/yt-dlp.rb/#install-the-gem)
- [Regex special characters to escape](https://stackoverflow.com/questions/399078/what-special-characters-must-be-escaped-in-regular-expressions)

- https://developers.google.com/drive/api/guides/handle-errors
- https://docs.rs/google-youtube3/latest/google_youtube3/
- https://docs.rs/google-drive/latest/google_drive/files/struct.Files.html#method.get
- https://doc.rust-lang.org/nightly/core/result/enum.Result.html
- https://lib.rs/crates/drive-v3
- https://developers.google.com/drive/api/quickstart/python#authorize_credentials_for_a_desktop_application
- https://console.cloud.google.com/apis/credentials/consent?project=eng-name-426603-u4
- https://docs.rs/drive-v3/latest/drive_v3/struct.Drive.html#structfield.files
- https://developers.google.com/drive/api/guides/search-files#python
