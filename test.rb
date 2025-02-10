require 'json'
require 'yt-dlp'

# Definir el gancho de progreso
def progress_hook(status)
  if status["status"] == "downloading"
    puts "Descargando: #{status['filename']} - #{status['_percent_str']} completado."
  elsif status["status"] == "finished"
    puts "Descarga completada: #{status['filename']}"
  end
end

# Definir el gancho para manejar el JSON
def json_hook(info)
  puts "Información del JSON capturada:"
  puts JSON.pretty_generate(info)
end

# Definir las opciones de descarga, incluyendo los hooks
options = {
  format: 'ba',
  progress: true,
  extract_audio: true,
  audio_format: 'mp3',
#   progress_hooks: [method(:progress_hook)],
  postprocessor_args: [
    "--print-json"
    # "-o", ->(info) { json_hook(info) }  # Definir el hook del JSON
  ]
}

# Función para descargar un video
def download_video(url, options)
  YtDlp.download(url, options)
end

# Ejemplo de uso
url = "https://youtu.be/fAGWhVONL2s?si=5gXOv9-lGe5aHdmp"
download_video(url, options)
