# frozen_string_literal: true

# TerminalStream — Hermetic output adapter for the terminal.
# Implements the same event interface as HorologiumAeternum but writes to STDOUT
# with ANSI colors and structured formatting.
class TerminalStream
  def initialize
    @thinking_start = Time.now
    @tool_count = 0
  end

  def thinking(message, uuid: nil)
    puts "\e[2m  ◇ #{message}\e[0m"
  end

  def send_status(type, data = {}, uuid: nil)
    case type
    when 'thinking_complete'
      thinking_time = data[:thinking_time]
      puts "\e[2m  ◇ Thought for #{thinking_time}s\e[0m"
    when 'oracle_revelation'
      # Content is shown as answer, not during streaming
    when 'oracle_conjuration_revelation'
      puts "\e[36m  #{data[:message]}\e[0m" if data[:message]
    when 'file_reading'
      puts "  \e[34m📖 #{data[:message]}\e[0m"
    when 'file_read_complete'
      puts "  \e[32m  ✓ read #{data[:message]&.gsub(/^Read /, '')}\e[0m"
    when 'file_read_fail'
      puts "  \e[31m  ✗ #{data[:message]}\e[0m"
    when 'file_creating'
      puts "  \e[34m✏️  #{data[:message]}\e[0m"
    when 'file_created'
      puts "  \e[32m  ✓ created\e[0m"
    when 'file_patching'
      puts "  \e[33m🔧 #{data[:message] || "Patching #{data[:path]}"}\e[0m"
    when 'file_patched'
      puts "  \e[32m  ✓ patched\e[0m"
    when 'file_patched_fail'
      puts "  \e[31m  ✗ patch failed: #{data[:error]}\e[0m"
    when 'command_executing'
      puts "  \e[33m⚡ #{data[:cmd]}\e[0m"
    when 'command_completed'
      puts "  \e[32m  ✓ done (#{data[:bytes]}b)\e[0m"
    when 'memory_searching'
      puts "  \e[34m🔍 #{data[:query]}\e[0m"
    when 'memory_found'
      puts "  \e[32m  ✓ #{data[:count]} results\e[0m"
    when 'note_added'
      puts "  \e[32m  📝 stored\e[0m"
    when 'note_removed'
      puts "  \e[33m  🗑 removed\e[0m"
    when 'aegis_unveiled'
      puts "  \e[32m  🔮 aegis\e[0m"
    when 'task_created'
      puts "  \e[32m  📋 task ##{data[:id]}\e[0m"
    when 'task_started'
      puts "  \e[33m  ▶ task\e[0m"
    when 'task_completed'
      puts "  \e[32m  ✓ task done\e[0m"
    when 'info_message'
      puts "  \e[36m  #{data[:message]}\e[0m"
    when 'system_error'
      puts "  \e[31m  ✗ #{data[:message]}\e[0m"
    when 'thinking'
      puts "\e[2m  ◇ #{data[:message]}\e[0m"
    when 'completed'
      puts "\e[2m  ◇ #{data[:summary]}\e[0m"
    else
      puts "\e[2m  ◇ [#{type}]\e[0m"
    end
  end

  # Delegate all other HorologiumAeternum methods to send_status
  def method_missing(method_name, *args, **kwargs, &block)
    if method_name.to_s.start_with?('file_', 'tool_', 'command_', 'memory_', 'note_', 'aegis_', 'task_', 'temp_')
      type = method_name.to_s
      data = kwargs.dup
      data[:message] = args.first if args.first.is_a?(String) && !data.key?(:message)
      send_status(type, data)
    elsif %i[thinking oracle_revelation oracle_conjuration_revelation info_message system_error completed].include?(method_name)
      data = { message: args.first }
      data = data.merge(kwargs) if kwargs.any?
      send_status(method_name.to_s, data)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.start_with?('file_', 'tool_', 'command_', 'memory_', 'note_', 'aegis_', 'task_', 'temp_') ||
      %i[thinking oracle_revelation oracle_conjuration_revelation info_message system_error completed].include?(method_name) ||
      super
  end

  private

  def puts(*args)
    STDOUT.puts(*args)
  end
end