# frozen_string_literal: true

require "digest"

module SkyImage
  MAX_BYTES = 32 * 1024 * 1024

  Result = Data.define(:format, :width, :height, :bytes, :sha256, :recommendations)

  module_function

  def inspect_file(path)
    raise ArgumentError, "path is required" if path.nil? || path.empty?
    raise ArgumentError, "input must be a regular file" unless File.file?(path)

    size = File.size(path)
    raise ArgumentError, "image exceeds #{MAX_BYTES} byte limit" if size > MAX_BYTES
    raise ArgumentError, "image is empty" if size.zero?

    data = File.binread(path)
    format, width, height = dimensions(data)
    raise ArgumentError, "unsupported or malformed image; supported formats: PNG, JPEG, GIF" unless format

    Result.new(
      format: format,
      width: width,
      height: height,
      bytes: size,
      sha256: Digest::SHA256.hexdigest(data),
      recommendations: recommendations(format, width, height, size)
    )
  end

  def dimensions(data)
    return png_dimensions(data) if data.start_with?("\x89PNG\r\n\x1A\n".b)
    return gif_dimensions(data) if data.start_with?("GIF87a".b, "GIF89a".b)
    return jpeg_dimensions(data) if data.start_with?("\xFF\xD8".b)

    nil
  end

  def png_dimensions(data)
    return nil if data.bytesize < 24 || data.byteslice(12, 4) != "IHDR"

    width, height = data.byteslice(16, 8).unpack("NN")
    valid_dimensions("png", width, height)
  end

  def gif_dimensions(data)
    return nil if data.bytesize < 10

    width, height = data.byteslice(6, 4).unpack("vv")
    valid_dimensions("gif", width, height)
  end

  def jpeg_dimensions(data)
    offset = 2
    while offset + 4 <= data.bytesize
      offset += 1 while offset < data.bytesize && data.getbyte(offset) != 0xFF
      return nil if offset + 3 >= data.bytesize

      offset += 1 while offset < data.bytesize && data.getbyte(offset) == 0xFF
      return nil if offset >= data.bytesize

      marker = data.getbyte(offset)
      offset += 1
      next if marker == 0xD8 || marker == 0xD9
      return nil if marker == 0xDA
      return nil if offset + 2 > data.bytesize

      length = data.byteslice(offset, 2).unpack1("n")
      return nil if length < 2 || offset + length > data.bytesize

      if sof_marker?(marker)
        return nil if length < 7
        height, width = data.byteslice(offset + 3, 4).unpack("nn")
        return valid_dimensions("jpeg", width, height)
      end

      offset += length
    end
    nil
  end

  def sof_marker?(marker)
    [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF].include?(marker)
  end

  def valid_dimensions(format, width, height)
    return nil unless width.positive? && height.positive?
    return nil if width > 100_000 || height > 100_000

    [format, width, height]
  end

  def recommendations(format, width, height, bytes)
    notes = []
    pixels = width * height
    notes << "consider responsive resizing; pixel dimensions exceed 12 megapixels" if pixels > 12_000_000
    notes << "consider lossless metadata stripping or recompression; file exceeds 2 MiB" if bytes > 2 * 1024 * 1024
    notes << "consider evaluating a modern delivery format such as WebP/AVIF where client support permits" if %w[jpeg png].include?(format)
    notes << "no size-based recommendation triggered" if notes.empty?
    notes.freeze
  end
end
