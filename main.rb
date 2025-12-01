#/usr/bin/env ruby

# TOOD: Access to my drive for the youtube links and download the music I dont have already
# TODO: If artist name doesnt exist in the youtube title, put it automatically

require 'fileutils'
require "readline"

require 'yt-dlp.rb'
require 'taglib'

# For the hours, it will only accept until 23, I don't think you will find a video more than 23 hours long
# Thanks copilot for this regex.
TIME_RANGE_REGEX = /^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d-(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$/

FILE_NAME = "history.txt"

# Save script location
ROOT_FOLDER_SCRIPT = File.dirname(File.realpath(__FILE__))

def default_download_options = {
    format: "ba",
    progress: true,
    extract_audio: true,
    audio_format: "mp3",
}

# sanitize a string to be safe as a filename (remove control and reserved chars)
#
# @param [String] name to be sanitized
#
# @return [String] String sanitized
def sanitize_filename(name)
  return "" if name.nil?
  s = name.dup
  # remove nulls and slashes, replace other reserved chars with space
  s.gsub!("\0", "")
  s.gsub!(%r{[\/]}, " ")
  s.gsub!(%r{[<>:"\\|?*]}, "")
  s.strip!
  s.gsub!(/\s+/, " ")
  s
end

# Helper function to prompt user information
def prompt(message)
    Readline.readline(message, add_hist: true)
end

# Collects all files given a folder based in a string
#
# @param [String] root_folder
#   Folder where we are going to start searching
# @param [String] search_str
#   String to be search
#
# @return [Array<String>] A list of files paths that match the search string, empty list if not matching
def search_files(root_folder, search_str)
    # Save all the songs we have in our Music folder
    Dir.glob("#{root_folder}/**/*").select do |song|
        !Dir.exist?(song) && File.basename(song.downcase).include?(search_str.downcase)
    end
end

# Fetch the video information from a youtube url
#
# @param [String] url Youtube valid url
#
# @return [Hash] A hash containing video metadata such as title, duration, etc.
def fetch_video_information(url)
    video_info = YtDlp.information(url)[0]
    raise "[ERROR] Unable to fetch video info" unless video_info

    video_info
end

def handle_chapters(chapters)
    # Handle the chapters from the video and return its name
    puts "\n[Info] Video has chapters, please write chapter number to download specific chapter"
    chapters.each_with_index { |chapter, index| puts "[#{index + 1}] #{chapter[:title]}"}

    chapter_index = nil
    loop do
        chapter_index = Integer(prompt("Enter chapter number-> "))
        break if chapter_index && chapter_index.between?(1, chapters.size)
        puts "[ERROR] Invalid chapter number, please try again"
    end

    chapters[chapter_index - 1][:title]
end

def verify_download(file_name, path)
    file_path = File.join(path, "#{file_name}.mp3")
    if File.file?(file_path) 
        puts "[Info] File downloaded at path #{file_path}"
        return true
    else
        puts "[Error] Something file not downloaded at path #{file_path}"
        return false
    end
end

def chop_video
    # Return a valid range with Hours:Minutes:Seconds with the form start-end to be used for yt-dlp
    loop do
        range_video = prompt("Enter the range with Hour:Minutes:Seconds with the form start-end -> ")
        return "*#{range_video}" if TIME_RANGE_REGEX.match?(range_video)
        puts "[ERROR] Invalid range format, please try again"
    end
end

def download_audio(url, options)
    # Download the mp3 from the youtube video
    YtDlp.download(url, options)
end

# Download a song from youtube saving in a given path
#
# @param [String] path Path to be saved
#
# @return [Boolean] true if download was successful, false otherwise
def download_song(path)
    unless Dir.exist?(path)
        puts "[ERROR] Path does not exist: #{path}"
        return false
    end

    Dir.chdir(path) do
        puts "[Info] Changing to #{path}"
        url = prompt("Enter youtube URL -> ").to_s.strip

        if url.empty?
            puts "[ERROR] Empty url"
            return false
        end

        begin
            video_info = fetch_video_information(url)
        rescue => e
            puts "[ERROR] Failed to fetch video information: #{e}"
            return false
        end

        # Use youtube video title as default file name
        file_name = sanitize_filename(video_info[:title].to_s)
        chapters = video_info[:chapters]
        options = default_download_options.dup

        if chapters && !chapters.empty?
            file_name = handle_chapters(chapters)
            # Because it is a regex it might contain special characters, let's scape them.
            options[:download_section] = Regexp.escape(file_name.to_s)
            file_name = sanitize_filename(file_name)
        else
            puts "[INFO] Chapters not found"
            options[:download_section] = chop_video if prompt("[INFO] Chop the video? y/n -> ").to_s.downcase == 'y'
        end

        options[:output] = "#{file_name}.%(ext)s"

        begin
            download_audio(url, options)
        rescue => e
            puts "[ERROR] Download failed: #{e}"
            return false
        end

        unless verify_download(file_name, path)
            puts "[ERROR] Download verificationfailed for #{file_name}.mp3"
            return false
        end

        option = prompt("[INFO] Rename file with name: '#{file_name}'? y/n -> ").to_s.downcase
        file_path = File.join(path, "#{file_name}.mp3")
        if option.downcase == "y"
            new_song_name = prompt("[INFO] Enter new file name without extension with format [Artist name -] new_name -> ").to_s.strip
        end
        rename_song(file_path, option.downcase == "y" ? new_song_name: file_name)
        true
    end
end

def create_folder(path)
    begin
        FileUtils.mkdir_p(path)
        puts "[Info] Folder created at #{path}"
    rescue Errno::EEXIST
        puts "[Error] Error creating the folder, folder already exist #{path}"
        exit(1)
    end
end

def list_songs(songs)
    # List songs in a list format starting from index 1
    songs.each_with_index {|song, index| puts "[#{index + 1}] #{song}"}
end

# Rename a song with a new name
#
# @param [String] file_path
#   Complete file path of the file to be renamed
# @param [String] new_song_name
#   New file name to use without extension
#
# @return [Boolean] true if successful rename, false otherwise
def rename_song(file_path, new_song_name)
    unless File.exist?(file_path)
        puts "[ERROR] Source file does not exist: #{file_path}"
        return false
    end

    # Ensure new_song_name does not have extension
    extension = File.extname(file_path)
    new_song_name = File.basename(new_song_name, extension).to_s.strip
    new_song_name = sanitize_filename(new_song_name)

    # Prepend artist from parent folder if no '-' present
    unless new_song_name.include?("-")
        artist_name = File.basename(File.dirname(file_path))
        # What happen if the artist name is a folder? like Vivaldi/Opera
        new_song_name = "#{artist_name} - #{new_song_name}"
    end
    
    begin
        new_name = File.join(File.dirname(file_path), new_song_name + extension)
        File.rename(file_path, new_name)
        puts "[Info] File renamed successfuly with new name #{new_name}"
        true
    rescue Errno::SystemCallError => e
        puts "[Error] Error renaming the file #{file_path}: #{e}"
        return false
    end
end

def play_song(songs)
    list_songs(songs)
    index = Integer(prompt("Select the [number] you want to play: ")) - 1
    song = songs.at(index)
    return puts "[Error] File not found" unless song
    system("vlc", "#{song}")
end

def run_query_video(csv_path)
    Process.detach(Process.spawn("kitty", "./query_video.sh", csv_path))
end

def load_history
    if File.exist?(FILE_NAME)
        File.readlines(FILE_NAME).each { |line| Readline::HISTORY.push(line.chomp)}
    end
end

# Save the user input history in a file "history.txt"
#
# File will be created if does not exist and it will append
# each element.
def save_history

    # Save user input history in a text file called history.txt
    # Remove duplicated elements.
    unique_history = Readline::HISTORY.to_a.uniq
    File.open(FILE_NAME, "w") do |f|
        unique_history.to_a.each { |line| f.puts line.strip}
    end
end

# Tag metadata song such as: comment, album, artist, title
#
# @param [Array<String>] songs Array that contains a list of songs
def tag_song(songs)
    # Should match with the Tag functions from here:
    # https://rubydoc.info/gems/taglib-ruby/TagLib/Tag#comment-instance_method
    fields = [:comment, :album, :artist, :title]

    list_songs(songs)
    index = Integer(prompt("Select the [number] you want to play: ")) - 1
    song = songs[index]
    unless song
        puts "[Error] File not found" unless song
        return
    end

    TagLib::FileRef.open(song) do |file|
        if file.nil?
            puts "[ERROR] Could not open file #{song}"
            return
        end

        puts "[INFO] Selected song #{song}"
        tag = file.tag
        changed = false

        fields.each do |field|
            current = tag.send(field)
            puts "[INFO] Current #{field}: #{current}"
            new_value = prompt("[INFO] Enter a new #{field} value (empty to skip) -> ").to_s.strip
            if new_value.empty?
                next
            end

            confirm = prompt("[INFO] Update #{field} to '#{new_value}'? y/n -> ").to_s.downcase
            unless confirm == "y"
                puts "[INFO] No changes made to #{field}"
                next
            end

            if !current.empty?
                append = prompt("[INFO] #{field} already present, append? y/n -> ").to_s.downcase == "y"
                tag.send("#{field}=", append ? "#{current}\n#{new_value}" : new_value)
            else
                tag.send("#{field}=", new_value)
            end

            puts "[INFO] #{field}: #{tag.send(field)}"
            changed = true
        end

        file.save if changed
    end
end

def main
    root_folder = File.join(Dir.home, "/Music/Music")
    
    load_history
    # Escape characters that can broke the regex.
    completation = proc { |s| Readline::HISTORY.to_a.grep(/#{Regexp.escape(s)}/) }
    Readline.completion_proc = completation

    loop do
        puts "\n[D]ownload song"
        puts "[F]ind Song/Artist"
        puts "[R]ename song"
        puts "[P]lay song"
        puts "[G]et song from csv"
        puts "[T]ag song"
        puts "[E]xit"

        option = prompt("Enter an option -> ").downcase

        case option
        when "d" # Download
            str = prompt("Enter relative path to download the song starting from Music/ eg. Artist/folder1/folder2/... [c] to cancel -> " )
            if str != 'c'
                path = File.join(root_folder, str)
                    
                unless Dir.exist?(path)
                    create_folder(path)
                else
                    puts "[Info] Folder already exists"
                end
                unless download_song(path)
                    puts "[ERROR] Download song failed to: #{path}"
                end
            end

        when "f" # Find
            songs = search_files(root_folder, prompt("Please enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : list_songs(songs)

        when "r" # Rename
            songs = search_files(root_folder, prompt("[INFO] Please enter the song/artist name to search: ").downcase)
            list_songs(songs)
            index = Integer(prompt("[INFO] Select the [number] you want to rename: ")) - 1
            song_path = songs[index]

            unless song_path
                puts "[Error] File not found #{song_path}" unless song_path
                return
            end

            new_song_name = prompt("[INFO] Enter new file name without extension with format [Artist name -] new_name -> ")
            songs.empty? ? puts("[Info] Song/Artist not found\n") : rename_song(song_path, new_song_name)

        when "p" # Play song
            songs = search_files(root_folder, prompt("Please enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : play_song(songs)

        when "g" # Get song from csv
            begin
                csv_path = prompt("Enter csv file path: ").downcase
                csv_path_abs = File.realpath(csv_path)
                run_query_video(csv_path_abs)
            rescue Errno::ENOENT
                puts("[ERROR]: File #{csv_path} doesn't exist, make sure csv file exist.")
            end

        when "t" # Tag song
            songs = search_files(root_folder, prompt("Please enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : tag_song(songs)

        when "e" # Exit
            puts "BYE :)"
            break

        else
            puts "Please enter a valid option"
        end
    end

    save_history
end

main
