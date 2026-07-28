# frozen_string_literal: true

# Nuntius — the messenger that breaches the veil.
# Delivers native macOS notification banners to the user via osascript.
# Each message carries a sound-name hint: 'Glass' for info, 'Basso' for warnings.

require 'open3'

module Nuntius
  # Delivers a macOS notification banner.
  # Silently no-ops on non-macOS or if osascript is unavailable.
  #
  # @param title [String] the notification title
  # @param message [String] the notification body
  # @param sound [String] macOS sound name (default: 'Glass')
  def self.deliver(title:, message:, sound: 'Glass')
    script = <<~APPLESCRIPT
      display notification "#{escape(message)}" \
        with title "#{escape(title)}" \
        sound name "#{sound}"
    APPLESCRIPT

    _out, _err, status = Open3.capture3('osascript', '-e', script)
    status.success?
  rescue StandardError
    false
  end

  # Escapes double-quotes and backslashes for safe AppleScript embedding.
  def self.escape(str)
    str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\\\"')
  end

  private_class_method :escape
end
