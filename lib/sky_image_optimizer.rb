require "open3"
require "pathname"

module SkyImageOptimizer
  SUPPORTED_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
  MAX_DIMENSION = 16_384
  MIN_QUALITY = 1
  MAX_QUALITY = 100

  Result = Data.define(:input, :output, :input_bytes, :output_bytes, :saved_bytes, :command)

  module_function

  def build_command(input:, output:, quality: 82, max_width: nil, max_height: nil)
    input_path = Pathname(input)
    output_path = Pathname(output)
    validate_paths!(input_path, output_path)
    quality = Integer(quality)
    raise ArgumentError, "quality must be between #{MIN_QUALITY} and #{MAX_QUALITY}" unless quality.between?(MIN_QUALITY, MAX_QUALITY)

    width = normalize_dimension(max_width, "max_width")
    height = normalize_dimension(max_height, "max_height")

    command = ["magick", input_path.to_s, "-auto-orient", "-strip"]
    if width || height
      geometry = "#{width || ''}x#{height || ''}>"
      command.concat(["-resize", geometry])
    end
    command.concat(["-quality", quality.to_s, output_path.to_s])
    command
  end

  def optimize(input:, output:, quality: 82, max_width: nil, max_height: nil, runner: Open3.method(:capture3))
    command = build_command(
      input: input,
      output: output,
      quality: quality,
      max_width: max_width,
      max_height: max_height
    )
    input_path = Pathname(input)
    output_path = Pathname(output)
    raise ArgumentError, "input file does not exist" unless input_path.file?
    raise ArgumentError, "input file must not be empty" if input_path.size.zero?

    stdout, stderr, status = runner.call(*command)
    unless status.success?
      detail = stderr.to_s.strip.empty? ? stdout.to_s.strip : stderr.to_s.strip
      raise RuntimeError, "ImageMagick failed#{detail.empty? ? '' : ": #{detail}"}"
    end
    raise RuntimeError, "ImageMagick did not create the output file" unless output_path.file?

    input_bytes = input_path.size
    output_bytes = output_path.size
    Result.new(
      input: input_path.to_s,
      output: output_path.to_s,
      input_bytes: input_bytes,
      output_bytes: output_bytes,
      saved_bytes: input_bytes - output_bytes,
      command: command
    )
  end

  def validate_paths!(input, output)
    raise ArgumentError, "input and output paths must differ" if input.expand_path == output.expand_path
    raise ArgumentError, "unsupported input format" unless SUPPORTED_EXTENSIONS.include?(input.extname.downcase)
    raise ArgumentError, "unsupported output format" unless SUPPORTED_EXTENSIONS.include?(output.extname.downcase)
  end

  def normalize_dimension(value, name)
    return nil if value.nil?

    dimension = Integer(value)
    raise ArgumentError, "#{name} must be between 1 and #{MAX_DIMENSION}" unless dimension.between?(1, MAX_DIMENSION)
    dimension
  rescue ArgumentError, TypeError
    raise ArgumentError, "#{name} must be between 1 and #{MAX_DIMENSION}"
  end
end
