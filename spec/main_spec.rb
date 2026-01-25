require "stringio"

require_relative "../src/main"

RSpec.describe "#sanitize_filename" do
  it "removes unsafe characters" do
    input = "  My:/Bad\\Name<>:*?\" \t    "
    expect(sanitize_filename(input)).to eq("My BadName")
  end  

  it "returns empty string when is nil" do
    input = nil
    expect(sanitize_filename(input)).to eq("")
  end
end

RSpec.describe "#create_folder" do
  it "ask to FileUtils to create a folder" do
    folder_path = "my/fake/path"
    expect(FileUtils).to receive(:mkdir_p).with(folder_path)

    create_folder(folder_path)
  end
end

RSpec.describe "#list_songs" do
  it "print songs list with a 1-based index" do
    input = ["/home/music/song1.mp3", "/home/music/song2.mp3"]
    expected = "[1] /home/music/song1.mp3\n[2] /home/music/song2.mp3\n"

    expect{list_songs(input)}.to output(expected).to_stdout
  end

  it "prints nothing when empty array is pass" do
    expected = ""
    expect{list_songs([])}.to output(expected).to_stdout
  end
end

RSpec.describe "#prompt" do
  it "readline is called with the correct arguments" do
    msg = "msg"
    expect(Readline).to receive(:readline).with(msg, add_hist: true)
    prompt(msg)
  end

  it "readline returns the user input" do
    expected = "my_input\n"
    allow(Readline).to receive(:readline).and_return("my_input\n")
    expect(prompt("msg")).to eq(expected)
  end
end

RSpec.describe "#search_files" do
  let(:expected) { ["/music/song.mp3", "/music/folder/song2.mp3"] }
  let(:str_search) { "song" }
  let(:root_folder) { "/music" }
  let(:input) do
    [
      "/music/folder1",
      "/music/folder2",
      "/music/song/folder",
      "/music/song.mp3",
      "/music/folder/song2.mp3"
    ]
  end

  before do
    allow(Dir).to receive(:glob).and_return(input)
    allow(Dir).to receive(:exist?) do |path|
      path.include?(".mp3") ? false : true
    end
  end

  it "filter songs by path and search string" do
    expect(search_files(root_folder, str_search)).to eq(expected)
  end

  context "when search string is uppercase" do
    let(:str_search) { "SONG" }

    it "returns filtered song list using uppercase search string" do
      expect(search_files(root_folder, str_search)).to eq(expected)
    end
  end

  context "when search string is mixed" do
    let(:str_search) { "SoNg" }

    it "returns filtered song list using mixed search string" do
      expect(search_files(root_folder, str_search)).to eq(expected)
    end
  end

  context "no songs found" do
    let(:str_search) { "nonexisting" }

    it "returns empty list when search string is non existing" do
      expect(search_files(root_folder, str_search)).to eq([])
    end
  end
end

RSpec.describe "#verify_download" do
  let(:filename) { "file" }
  let(:path) { "/my/path" }

  it "Checks when the file exist" do
    allow(File).to receive(:file?).and_return(true)
    expect(verify_download(filename, path)).to eq(true) 
  end

  it "Checks when the file does not exist" do
    allow(File).to receive(:file?).and_return(false)
    expect(verify_download(filename, path)).to eq(false)
  end
end

RSpec.describe "#fetch_video_information" do
  context "when video metadata information is available" do
    it "returns the youtube video information from the first element" do
      information = [
        {
          title: "mytitle",
          chapters: "chapters"
        }
      ]

      allow(YtDlp).to receive(:information).and_return(information)
      expect(fetch_video_information("https://myurldummy")).to eq(information.first)
    end
  end

  context "when video metadata is not existing" do
    it "raise an error" do
      # TODO: Is this necessary? if raising in the code is removed this is not necessary anymore
    end
  end
end

RSpec.describe "#download_audio" do
  context "download youtube audio" do
    it "delegates responsibility to YyDlp to download audio" do
      options = {
          format: "ba",
          progress: true,
          extract_audio: true,
          audio_format: "mp3",
      }
      expect(YtDlp).to receive(:download).with("https://url", options)
      download_audio("https://url", options)
    end
  end
end

RSpec.describe "#run_query_video" do
  context "run bash script" do
    it "spawns and detach the process" do
      csv_path = "./csvpath.csv"
      process_id = 123
      expect(Process).to receive(:spawn).with(
        "kitty",
        "./query_video.sh",
        csv_path
      ).and_return(process_id)
      expect(Process).to receive(:detach).with(process_id)
      run_query_video(csv_path)
    end
  end
end

RSpec.describe "#load_history" do
  let(:file_content) { ["one\n", "two\n"] }
  let(:expected) { ["one", "two"] }

  before do
    @original_history = Readline::HISTORY.dup
    Readline::HISTORY.clear
  end

  after do
    Readline::HISTORY = @original_history
  end

  context "load file history for autocompletion" do
    it "file history exist" do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:readlines).and_return(file_content)

      load_history
      expect(Readline::HISTORY).to eq(expected)
    end

    it "file history does not exist" do
      Readline::HISTORY.push("text")
      expected = ["text"]

      allow(File).to receive(:exist?).and_return(false)
      load_history
      expect(Readline::HISTORY).to eq(expected)
    end
  end
end

RSpec.describe "#save_history" do
  before do
    @original_history = Readline::HISTORY.dup
    Readline::HISTORY.clear
  end

  after do
    Readline::HISTORY = @original_history
  end

  context "save user history into a file" do
    it "history user content is stripped and duplicated removed" do
      fake_file = StringIO.new
      Readline::HISTORY = ["one  \n", "  two  \n", "three", "three"]
      expected = "one\ntwo\nthree\n"

      allow(File).to receive(:open).and_yield(fake_file)

      save_history
      expect(expected).to eq(fake_file.string)
    end
  end
end

RSpec.describe "#play_song" do
  let(:songs) { ["song1.mp3"] }

  before do
    allow(self).to receive(:list_songs)
  end

  context "Given a list of songs play a song" do
    it "calls vlc with the correct song when the selection is valid" do
      allow(self).to receive(:prompt).and_return("1")
      expect(self).to receive(:system).with("vlc", "song1.mp3")

      play_song(songs)
    end

    it "vlc is not called when song selection is invalid" do
      allow(self).to receive(:prompt).and_return("-1")
      expect(self).not_to receive(:system)

      # This test might change once this method is refactored to return
      # a meaningful value because checking the return value when the function
      # does not return a value is not good
      result = play_song(songs)
      expect(result).to eq(nil)
    end
  end
end

RSpec.describe "#rename_song" do
  let(:file_path) { "/my/path/yiruma/file.mp3" }
  let(:new_name) { "new_name" }
  let(:new_name_path) { "/my/path/yiruma/yiruma - new_name.mp3" }

  before do
    allow(File).to receive(:exist?).and_return(true)
    allow(self).to receive(:sanitize_filename).and_return(new_name)
  end

  context "Rename a song given a valid file path" do
    it "renames the file when exists prepending the artist" do
      expect(File).to receive(:rename).with(file_path, new_name_path)
      result = rename_song(file_path, new_name)
      expect(result).to be(true)
    end

    it "returns false if renaming file fails" do
      expect(File).to receive(:rename).and_raise(Errno::ENOENT)
      result = rename_song(file_path, new_name)
      expect(result).to be(false)
    end

    it "does not prepend artist name" do
      new_name = "yiruma - new_name"
      expect(File).to receive(:rename).with(file_path, new_name_path)
      result = rename_song(file_path, new_name)
      expect(result).to be(true)
    end
  end

  context "when song path does not exist" do
    before do
      allow(File).to receive(:exist?).and_return(false)
    end

    it "returns false" do
      expect(File).not_to receive(:rename)
      result = rename_song(file_path, new_name)      
      expect(result).to be(false)
    end
  end
end

RSpec.describe "#download_song" do
  let(:path) { "/my/path/" }
  let(:video_info) { 
    [
      {
        title: "mytitle",
        chapters: "chapters"
      }
    ]
  }
  let(:filename) { "youtube title" }
  let(:chapter_name) { "chapter" }
  let(:url) { "https://fakeurl.com" }

  context "when path does not exist" do
    it "return false" do
      allow(Dir).to receive(:exist?).and_return(false)

      # These are the most important functions should not be called
      expect(self).not_to receive(:fetch_video_information)
      expect(self).not_to receive(:download_audio)
      expect(self).not_to receive(:verify_download)

      result = download_song(path)
      expect(result).to be(false)
    end
  end

  context "when path exist" do
    before do
      allow(Dir).to receive(:exist?).and_return(true)
      allow(Dir).to receive(:chdir).and_yield
      allow(self).to receive(:prompt).and_return(url)
    end
    
    context "when url is empty" do
      it "returns false " do
        allow(self).to receive(:prompt).and_return("")

        expect(self).not_to receive(:fetch_video_information)
        expect(self).not_to receive(:download_audio)

        expect(self).not_to receive(:verify_download)
        result = download_song(path)
        expect(result).to be(false)
      end
    end

    it "returns false when fetching video information failed" do
      expect(self).to receive(:fetch_video_information).and_raise(SystemCallError)
      expect(self).not_to receive(:download_audio)
      expect(self).not_to receive(:verify_download)

      result = download_song(path)
      expect(result).to be(false)
    end

    context "when video information is successfully fetched" do
      before do
        allow(self).to receive(:sanitize_filename).and_return(filename)
        allow(self).to receive(:handle_chapters).and_return(chapter_name)
        allow(self).to receive(:fetch_video_information).and_return(video_info.first)
        allow(self).to receive(:default_download_options).and_return({})
        allow(self).to receive(:download_audio)
      end

      it "returns false if download audio fails" do
        expect(self).to receive(:download_audio).and_raise(SystemCallError)
        expect(self).not_to receive(:verify_download)
        expect(self).not_to receive(:rename_song)

        expect(download_song(path)).to be(false)
      end

      it "returns false if download verification fails" do
        allow(self).to receive(:verify_download).and_return(false)
        expect(self).not_to receive(:rename_song)

        expect(download_song(path)).to be(false)
      end

      # Chapter handling section

      it "uses chapter name for download section, output filename, and rename when chapter exists" do
        expected_path = File.join(path, "#{chapter_name}.mp3")

        allow(self).to receive(:sanitize_filename).and_return(chapter_name)

        expect(self).to receive(:download_audio).with(url, {download_section: chapter_name, output: chapter_name + ".%(ext)s"})
        expect(self).to receive(:verify_download).with(chapter_name, path).and_return(true)
        expect(self).to receive(:rename_song).with(expected_path, chapter_name)

        download_song(path)
      end

      it "uses download section when we chop video" do
        allow(self).to receive(:handle_chapters).and_return(nil)
        allow(self).to receive(:prompt).and_return(url, "y")

        expect(self).to receive(:chop_video).and_return("00:00:00-00:00:10")
        expect(self).to receive(:download_audio).with(url, {
          download_section: "00:00:00-00:00:10",
          output: "#{filename}.%(ext)s"
        })

        download_song(path)
      end

      it "does not use download section when chop video is not happening" do
        allow(self).to receive(:handle_chapters).and_return(nil)
        allow(self).to receive(:prompt).and_return(url, "n")

        expect(self).to receive(:download_audio).with(url, {
          output: "#{filename}.%(ext)s"
        })

        download_song(path)
      end

      it "returns true when the entire download flow succeeds" do
        allow(self).to receive(:prompt).and_return(url, "n")
  
        expect(self).to receive(:download_audio)
        expect(self).to receive(:verify_download).and_return(true)
        expect(self).to receive(:rename_song)
        
        expect(download_song(path)).to be(true)
      end
    end
  end
end

RSpec.describe "#handle_chapters" do
  context "when there are no chapters" do
    let(:video_info) { {} }

    it "returns nil" do
      expect(self).not_to receive(:prompt)
      expect(handle_chapters(video_info)).to be_nil
    end
  end

  context "when there are chapters" do
    let(:video_info) {
      {
        chapters: [
          { title: "chapter1" },
          { title: "chapter2" },
        ]
      } 
    }

    it "returns nil when the user chooses not to download a chapter" do
      allow(self).to receive(:prompt).once.and_return("n")
      expect(handle_chapters(video_info)).to be_nil
    end

    it "returns the chapter name when choosing an invalid and valid index" do
      allow(self).to receive(:prompt).and_return("y", "-1", "5", "1")
      expect(handle_chapters(video_info)).to eq("chapter1")
    end
  end

  context "when chapters list are empty" do
    let(:video_info) { { chapters: [] } }

    it "returns nil when chapter list is empty" do
      expect(self).not_to receive(:prompt)
      expect(handle_chapters(video_info)).to be_nil
    end
  end
end
