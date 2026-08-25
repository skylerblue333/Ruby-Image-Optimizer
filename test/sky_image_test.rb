# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require_relative "../lib/sky_image"

class SkyImageTest < Minitest::Test
  def with_file(bytes)
    file = Tempfile.new("sky-image")
    file.binmode
    file.write(bytes)
    file.close
    yield file.path
  ensure
    file&.unlink
  end

  def test_png_dimensions_and_digest
    png = "\x89PNG\r\n\x1A\n".b + [13].pack("N") + "IHDR" + [640, 480].pack("NN") + "\x08\x02\x00\x00\x00".b
    with_file(png) do |path|
      result = SkyImage.inspect_file(path)
      assert_equal "png", result.format
      assert_equal 640, result.width
      assert_equal 480, result.height
      assert_equal 64, result.sha256.length
    end
  end

  def test_gif_dimensions
    gif = "GIF89a".b + [320, 200].pack("vv") + "\x00".b * 8
    with_file(gif) do |path|
      result = SkyImage.inspect_file(path)
      assert_equal ["gif", 320, 200], [result.format, result.width, result.height]
    end
  end

  def test_jpeg_dimensions
    jpeg = "\xFF\xD8".b + "\xFF\xC0".b + [17].pack("n") + "\x08".b + [720, 1280].pack("nn") + "\x03".b + "\x00".b * 9
    with_file(jpeg) do |path|
      result = SkyImage.inspect_file(path)
      assert_equal ["jpeg", 1280, 720], [result.format, result.width, result.height]
    end
  end

  def test_unknown_data_is_rejected
    with_file("not-an-image") do |path|
      error = assert_raises(ArgumentError) { SkyImage.inspect_file(path) }
      assert_match(/unsupported or malformed image/, error.message)
    end
  end

  def test_invalid_dimensions_are_rejected
    gif = "GIF89a".b + [0, 200].pack("vv") + "\x00".b * 8
    with_file(gif) do |path|
      assert_raises(ArgumentError) { SkyImage.inspect_file(path) }
    end
  end
end
