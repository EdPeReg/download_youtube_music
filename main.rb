#/usr/bin/env ruby

# TOOD: Access to my drive for the youtube links and download the music I dont have already
# TODO: If artist name doesnt exist in the youtube title, put it automatically

require 'fileutils'

require 'yt-dlp.rb'

# For the hours, it will only accept until 23, I don't think you will find a video more than 23 hours long
# Thanks copilot for this regex.
TIME_RANGE_REGEX = /^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d-(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$/

# Save script location
ROOT_FOLDER_SCRIPT = File.dirname(File.realpath(__FILE__))

def default_download_options = {
    format: "ba",
    progress: true,
    extract_audio: true,
    audio_format: "mp3",
}

def prompt(message)
    print message
    gets.chomp
end

def search_files(root_folder, search_str)
    # Save all the songs we have in our Music folder
    Dir.glob("#{root_folder}/**/*").select do |song|
        !Dir.exist?(song) && File.basename(song.downcase).include?(search_str)
    end
end

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

def rename_file_if_needed(file_name, path)
    option = prompt("Rename the file with name: '#{file_name}'? y/n -> ")
    return file_name unless option.downcase == 'y'

    file_name = prompt("Enter new file name without extension, optionally you can enter Artist name, eg. 'Queen - ' -> ")

    # If we don't decide to write the artist name, take the parent folder as artist name
    # TODO: Bug, if in the file name we include "-", it won't take the parent folder as artist name
    # for example "Violin concerto in G-minor"
    unless file_name.include?("-")
        # TODO: What about if the artist name is a subfolder like Vivaldi/Opera 
        artist_name = File.basename(path)
        file_name = "#{artist_name} - #{file_name}"
    end

    file_name.strip
end

def verify_download(file_name, path)
    file_path = File.join(path, "#{file_name}.mp3")
    if File.file?(file_path) 
        puts "[Info] File downloaded at path #{file_path}"
    else
        puts "[Error] Something file not downloaded at path #{file_path}"
        exit(1)
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

def download_song(path)
    Dir.chdir(path)
    puts "[Info] Changing to #{path}"
    url = prompt("Enter youtube URL -> ")
    video_info = fetch_video_information(url)
    file_name = video_info[:title]         # Use youtube video title as default file name   
    chapters = video_info[:chapters]
    options = default_download_options

    if chapters
        file_name = handle_chapters(chapters)
        # Because it is a regex it might contain special characters, let's scape them.
        options[:download_section] = Regexp.escape(file_name)
    else
        puts "[INFO] Chapters not found"
        options[:download_section] = chop_video if prompt("Chop the video? y/n -> ").downcase == 'y'
    end
    
    file_name = rename_file_if_needed(file_name, path)
    options[:output] = "#{file_name}.%(ext)s"
    download_audio(url, options)
    verify_download(file_name, path)

    # Go back to the folder where the script is
    Dir.chdir(ROOT_FOLDER_SCRIPT)
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
    songs.each_with_index {|song, index| puts "[#{index + 1}] #{song}"}
end

def rename_song(songs)
    list_songs(songs)

    index = Integer(prompt("\nSelect the [number] you want to rename: ")) - 1
    old_song = songs.at(index)
    return puts "[Error] File not found" unless old_song

    artist_name = File.basename(File.dirname(old_song))
    new_song = prompt("Enter the new file name without extension -> ")
    # If we don't decide to write the artist name, take the parent folder as artist name
    # This if won't be executed if we decide to write ourselves the artist/song name
    unless new_song.include?("-")
        new_song = "#{artist_name} - #{new_song}"
    end
    
    begin
        new_name = File.join(File.dirname(old_song), new_song) + ".mp3"
        File.rename(old_song, new_name)
        puts "[Info] File renamed successfuly with new name #{new_name}"
    rescue Errno::SystemCallError
        puts "[Error] Error renaming the file #{old_song}"
    end
end

def play_song(songs)
    list_songs(songs)
    index = Integer(prompt("\nSelect the [number] you want to play: ")) - 1
    song = songs.at(index)
    return puts "[Error] File not found" unless song
    system("vlc", "#{song}")
end

def run_query_video(csv_path)
    system("./query_video.sh", "#{csv_path}")
end

def main
    root_folder = File.join(Dir.home, "/Music/Music")
    
    loop do
        puts "\n[D]ownload song"
        puts "[F]ind Song/Artist"
        puts "[R]ename song"
        puts "[P]lay song"
        puts "[G]et song from csv"
        puts "[E]xit"

        option = prompt("Enter an option -> ").downcase

        case option
        when "d" # Download
            # songs = search_files(root_folder, prompt("\nPlease enter the song/artist name: ").downcase)
            # songs.empty? ? puts("[Info] Song/Artist not found\n") : list_songs(songs)

            # continue = prompt("Continue Y/N? ").downcase
            str = prompt("\nEnter relative path to download the song starting from Music/ eg. Artist/folder1/folder2/... [c] to cancel -> " )
            if str != 'c'
                path = File.join(root_folder, str)
                    
                unless Dir.exist?(path)
                    create_folder(path)
                else
                    puts "[Info] Folder already exists"
                end
                download_song(path)
            end

        when "f" # Find
            songs = search_files(root_folder, prompt("\nPlease enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : list_songs(songs)

        when "r" # Rename
            songs = search_files(root_folder, prompt("\nPlease enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : rename_song(songs)

        when "p" # Play song
            songs = search_files(root_folder, prompt("\nPlease enter the song/artist name: ").downcase)
            songs.empty? ? puts("[Info] Song/Artist not found\n") : play_song(songs)

        when "g" # Get song from csv
            begin
                csv_path = prompt("\nEnter csv file path: ").downcase
                csv_path_abs = File.realpath(csv_path)
                run_query_video(csv_path_abs)
            rescue Errno::ENOENT
                puts("[ERROR]: File #{csv_path} doesn't exist, make sure csv file exist.")
            end

        when "e" # Exit
            puts "BYE :)"
            break

        else
            puts "Please enter a valid option"
        end
    end
end

main
