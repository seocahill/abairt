require "open3"

class CssoCompressor
  def self.call(input)
    Rails.logger.debug "[CssoCompressor] Compressing…"

    # Copy the contents of the CSS file to a temp file
    temp_file = Tempfile.new([input[:name], ".css"])
    temp_file.open
    temp_file.write(input[:data])
    temp_file.flush

    # Run the compressor and capture the output
    css, err, status = Open3.capture3("npx", "csso", temp_file.path)

    {data: css}
  end
end

Rails.application.config.assets.configure do |env|
  env.register_compressor "text/css", :csso, CssoCompressor
end