# frozen_string_literal: true

require 'base64'
require 'json'
require 'tempfile'

# VisionCoordinator — bridges screenshot tool outputs to vision-capable models
# Detects image paths in tool results, encodes them as base64, and formats
# them according to each provider's API requirements.
module VisionCoordinator
  VISION_ENABLED = ENV.fetch('VISION_ENABLED', 'true').downcase == 'true'
  MAX_IMAGE_SIZE = ENV.fetch('MAX_IMAGE_SIZE', '20_000_000').to_i # 20MB
  MAX_IMAGE_DIMENSION = ENV.fetch('MAX_IMAGE_DIMENSION', '4096').to_i
  MAX_BASE64_SIZE = ENV.fetch('MAX_BASE64_SIZE', '4_500_000').to_i # ~4.5MB base64 = ~3.4MB data
  SUPPORTED_FORMATS = %w[image/png image/jpeg image/jpg image/webp].freeze
  MIME_TYPE_MAP = { 'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'webp' => 'image/webp' }.freeze

  module_function

  # Extract image references from a tool result
  # Returns array of image references [{path:, mime_type:, size:}] or empty array
  def extract_image_references(tool_result)
    return [] unless VISION_ENABLED
    return [] unless tool_result.is_a?(Hash)

    refs = []

    # Look for take_screenshot result structure
    if (path = tool_result[:path] || tool_result['path'])
      refs << build_image_reference(path, tool_result)
    end

    # Look for embedded image data URIs (already encoded)
    if (data_uri = tool_result[:data_uri] || tool_result['data_uri'])
      refs << { data_uri: data_uri, source: :data_uri }
    end

    # Scan content text for image paths
    content = tool_result[:content] || tool_result['content'] || tool_result.to_s
    if content.is_a?(String)
      content.scan(%r{/tmp/[\w/]+\.(?:png|jpe?g|webp)}) do |match|
        refs << build_image_reference(match, tool_result) if File.exist?(match)
      end
    end

    refs.uniq { |r| r[:path] || r[:data_uri] }
  end

  # Load image from disk and encode as base64 data URI
  # Automatically compresses if base64 would exceed MAX_BASE64_SIZE
  # Returns {data_uri:, mime_type:, dimensions:, bytes:, compressed:} or error hash
  def load_and_encode(image_ref)
    return nil unless VISION_ENABLED

    path = image_ref[:path]
    return nil unless path && File.exist?(path)

    # Check file size
    size = File.size(path)
    return { error: "Image too large: #{size} bytes (max: #{MAX_IMAGE_SIZE})" } if size > MAX_IMAGE_SIZE

    # Determine mime type
    mime_type = image_ref[:mime_type] || MIME_TYPE_MAP[File.extname(path).delete('.').downcase] || 'image/png'
    ext = File.extname(path).delete('.').downcase

    # Read and encode
    data = File.binread(path)
    encoded = Base64.strict_encode64(data)

    # Check if compression needed
    if encoded.length > MAX_BASE64_SIZE
      compressed = compress_image(path, ext, mime_type)
      return compressed if compressed[:error]

      data = compressed[:data]
      mime_type = compressed[:mime_type]
      encoded = Base64.strict_encode64(data)
    end

    data_uri = "data:#{mime_type};base64,#{encoded}"

    {
      data_uri: data_uri,
      mime_type: mime_type,
      bytes: data.length,
      path: path,
      compressed: encoded.length > MAX_BASE64_SIZE ? false : (encoded.length < Base64.strict_encode64(File.binread(path)).length)
    }
  rescue StandardError => e
    { error: "Failed to encode image: #{e.message}", path: path }
  end

  # Compress image to fit within MAX_BASE64_SIZE
  # Uses ImageMagick if available, falls back to macOS sips
  # @param max_dimension [Integer] Optional max width/height for re-compression
  # @param min_quality [Integer] Optional minimum quality for aggressive compression
  # Returns {data:, mime_type:} or {error:}
  def compress_image(path, ext, original_mime_type, max_dimension: 2048, min_quality: 60)
    target_mime = 'image/jpeg'

    # Try ImageMagick first
    if system('which convert > /dev/null 2>&1')
      compress_with_imagemagick(path, max_dimension:, min_quality:)
    else
      compress_with_sips(path, max_dimension:, min_quality:)
    end
  rescue StandardError => e
    { error: "Compression error: #{e.message}" }
  end

  # Compress using ImageMagick
  # @param max_dimension [Integer] Max width/height (default 2048)
  # @param min_quality [Integer] Minimum quality to try (default 60, can go to 40 for extreme cases)
  def compress_with_imagemagick(path, max_dimension: 2048, min_quality: 60)
    quality = 85

    cmd = [
      'convert', path,
      '-resize', "#{max_dimension}x#{max_dimension}>",
      '-strip',
      '-interlace', 'Plane',
      '-quality', quality.to_s,
      '-format', 'jpg', '-'
    ]

    require 'open3'
    stdout, stderr, status = Open3.capture3(*cmd)
    return { error: "ImageMagick failed: #{stderr}" } unless status.success?

    compressed_data = stdout.b

    # Iterate down quality if still too large
    # Standard reduction: 80, 75, 70, 65, 60
    # Extended reduction for extreme cases: down to 40
    qualities = [80, 75, 70, 65, 60]
    qualities += [55, 50, 45, 40] if min_quality < 60
    qualities = qualities.select { |q| q >= min_quality }

    qualities.each do |q|
      break if Base64.strict_encode64(compressed_data).length <= MAX_BASE64_SIZE
      cmd[cmd.index('-quality') + 1] = q.to_s
      stdout, _stderr, status = Open3.capture3(*cmd)
      compressed_data = stdout.b if status.success?
    end

    { data: compressed_data, mime_type: 'image/jpeg' }
  end

  # Fallback compression using macOS sips
  # @param max_dimension [Integer] Max width/height for first pass
  # @param min_quality [Integer] Not directly supported by sips, uses lower dimension instead
  def compress_with_sips(path, max_dimension: 2048, min_quality: 60)
    require 'tempfile'

    # Calculate fallback dimensions based on min_quality
    # Lower quality = smaller dimension
    dimensions = [max_dimension, [max_dimension * 0.75, 600].max.to_i]
    dimensions << [max_dimension * 0.5, 400].max.to_i if min_quality < 60
    dimensions = dimensions.uniq

    data = nil
    dimensions.each do |dim|
      tempfile = Tempfile.new(['compressed', '.jpg'])
      # Quality mapping: sips uses formatOptions 0-100
      # We use 85 for first pass, 70 for second, 50 for third
      quality = dim >= max_dimension ? 85 : (dim >= max_dimension * 0.75 ? 70 : 50)

      system('sips', '-Z', dim.to_s, '--setProperty', 'formatOptions', quality.to_s, path, '--out', tempfile.path, out: '/dev/null', err: '/dev/null')

      if File.exist?(tempfile.path) && File.size(tempfile.path) > 0
        data = File.binread(tempfile.path)
        break if Base64.strict_encode64(data).length <= MAX_BASE64_SIZE
      end

      tempfile.close
      tempfile.unlink
    end

    return { error: 'sips compression failed' } unless data

    { data: data, mime_type: 'image/jpeg' }
  end

  # Transform tool result message to include rich image content
  # Returns message hash suitable for API
  def enrich_tool_message(tool_message, image_attachments)
    return tool_message if image_attachments.empty?

    content_parts = [{ type: :text, text: text_representation(tool_message, image_attachments) }]

    image_attachments.each do |img|
      if img[:error]
        content_parts << { type: :text, text: "\n[Image Error: #{img[:error]}]" }
      else
        content_parts << {
          type: :image,
          data_uri: img[:data_uri],
          mime_type: img[:mime_type],
          source_path: img[:path]
        }
      end
    end

    { **tool_message, content: content_parts }
  end

  # Format image attachments for OpenAI API
  def format_for_openai(content_parts)
    content_parts.map do |part|
      case part[:type]
      when :text
        { type: 'text', text: part[:text] }
      when :image
        { type: 'image_url', image_url: { url: part[:data_uri] } }
      end
    end
  end

  # Format image attachments for Anthropic API
  def format_for_anthropic(content_parts)
    content_parts.map do |part|
      case part[:type]
      when :text
        { type: 'text', text: part[:text] }
      when :image
        {
          type: 'image',
          source: {
            type: 'base64',
            media_type: part[:mime_type],
            data: part[:data_uri].split(',', 2).last
          }
        }
      end
    end
  end

  # Format image attachments for Gemini API
  def format_for_gemini(content_parts)
    parts = []
    content_parts.each do |part|
      case part[:type]
      when :text
        parts << { text: part[:text] }
      when :image
        parts << {
          inline_data: {
            mime_type: part[:mime_type],
            data: part[:data_uri].split(',', 2).last
          }
        }
      end
    end
    parts
  end

  # Check if a provider/model supports vision
  def vision_supported?(provider, model)
    return false unless VISION_ENABLED

    model_str = model.to_s.downcase

    case provider.to_sym
    when :openai
      model_str.include?('gpt-4') && (model_str.include?('vision') || model_str.include?('turbo') || model_str.include?('o'))
    when :anthropic
      model_str.include?('claude-3') || model_str.include?('claude-4')
    when :gemini
      model_str.include?('gemini') && (model_str.include?('pro-vision') || model_str.include?('ultra') || model_str.include?('1.5'))
    when :deepseek
      false # DeepSeek doesn't support vision yet
    else
      false
    end
  end

  # Helper: build image reference from path
  def build_image_reference(path, tool_result)
    ext = File.extname(path).delete('.').downcase
    {
      path: path,
      mime_type: MIME_TYPE_MAP[ext] || 'image/png',
      source: tool_result[:format] || tool_result['format'] || 'unknown',
      size: File.exist?(path) ? File.size(path) : 0
    }
  end

  # Helper: generate text representation of tool result with images
  def text_representation(tool_message, image_attachments)
    original_content = tool_message[:content]
    return original_content unless original_content.is_a?(String)

    image_summary = image_attachments.map do |img|
      if img[:error]
        "[Image error: #{img[:error]}]"
      else
        bs = img[:bytes] || 0
        "[Image: #{File.basename(img[:path] || 'unknown')}, #{bs / 1024}KB]"
      end
    end.join('\n')

    "#{original_content}\n\n---Captured Images---\n#{image_summary}"
  end
end