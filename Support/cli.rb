#!/usr/bin/env ruby
# frozen_string_literal: true

# = ÆtherCodex CLI — Console-first Hermetic Programming Oracle
#
# Subcommands:
#   ask "prompt"    Direct AI query (stdin pipe supported)
#   server            Start web server (TextMate UI)
#   config            Show configuration info
#   task <action>     Task management (list, show, create, execute)
#   (no args)         Interactive REPL with tool execution

require 'json'
require 'optparse'
require_relative 'config'
require_relative 'oracle/oracle'
require_relative 'oracle/terminal_stream'
require_relative 'oracle/coniunctio'
require_relative 'oracle/aetherflux'
require_relative 'instrumentarium/instrumenta'
require_relative 'instrumentarium/prima_materia'
require_relative 'mnemosyne/mnemosyne'
require_relative 'magnum_opus/magnum_opus_engine'

class ÆtherCodexCLI
  def initialize
    @options = {}
    @tools = Instrumenta
    @history = []
  end

  def run
    command = ARGV.shift

    case command
    when 'ask'     then ask_mode
    when 'server'  then server_mode
    when 'config'  then config_mode
    when 'task'    then task_mode
    when 'repl'    then repl_mode
    when 'help', '-h', '--help' then print_help
    when nil       then repl_mode
    else
      ARGV.unshift(command) if command
      repl_mode
    end
  end

  private

  def ask_mode
    prompt = ARGV.join(' ').strip
    prompt = STDIN.read.strip if prompt.empty? && !STDIN.tty?

    if prompt.empty?
      puts "Usage: ÆtherCodex ask \"your question\""
      puts "   or: echo \"question\" | ÆtherCodex ask"
      exit 1
    end

    # Parse --file options
    files = []
    args = prompt.split
    while (idx = args.index('--file') || args.index('-f'))
      args.delete_at(idx)
      files << args.delete_at(idx)
    end
    prompt = args.join(' ')

    context = Coniunctio.build(files: files)
    answer, arts, tool_results = Oracle.divination(prompt, context, tools: @tools) do |name, args, tool_ctx|
      @tools.handle(tool: name, args:, context: tool_ctx)
    end
    puts answer
  end

  def server_mode
    puts "Starting server..."
    require_relative 'limen'
    Limen.start
  end

  def config_mode
    puts "=== ÆtherCodex Configuration ==="
    puts "Provider: #{CONFIG[:provider] || 'deepseek'}"
    puts "Model: #{CONFIG[:model] || 'deepseek-chat'}"
    puts "API Key: #{CONFIG.api_key.to_s[0..8]}..." if CONFIG.api_key
    puts "Memory DB: #{CONFIG.memory_db_path}"
    puts "Project Root: #{ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd}"
    puts "Config Sources: #{CONFIG.debug_info[:config_sources]}"
  end

  def task_mode
    action = ARGV.shift || 'list'

    case action
    when 'list'
      tasks = Mnemosyne.manage_tasks(action: :list)
      if tasks.empty?
        puts "No tasks found."
      else
        tasks.each do |t|
          status = t[:status] || 'unknown'
          puts "[#{status}] ##{t[:id]}: #{t[:title]}"
        end
      end
    when 'show'
      id = ARGV.shift
      task = Mnemosyne.get_task(id.to_i)
      if task
        puts "Task ##{task[:id]}: #{task[:title]}"
        puts "Status: #{task[:status]}"
        puts "Plan: #{task[:plan]}"
        if task[:step_results]
          puts "Steps:"
          JSON.parse(task[:step_results]).each { |k, v| puts "  #{k}: #{v.to_s[0..100]}" }
        end
      else
        puts "Task ##{id} not found."
      end
    when 'create'
      title = ARGV.shift || 'Untitled Task'
      plan = ARGV.join(' ')
      result = Mnemosyne.create_task(title: title, plan: plan)
      puts "Created task ##{result[:id]}"
    when 'execute'
      id = ARGV.shift
      if id
        Mnemosyne.manage_tasks(action: :activate, id: id.to_i)
        puts "Activated task ##{id}. Use MagnumOpusEngine.execute_task(#{id}) for full execution."
      else
        puts "Usage: ÆtherCodex task execute <id>"
      end
    else
      puts "Unknown task action: #{action}"
      puts "Available: list, show <id>, create <title> [plan], execute <id>"
    end
  end

  def print_help
    puts "ÆtherCodex — Console-first Hermetic Programming Oracle"
    puts
    puts "Usage: ÆtherCodex <command> [options]"
    puts
    puts "Commands:"
    puts "  ask \"prompt\"     Ask the oracle a question"
    puts "  server           Start web server (TextMate UI)"
    puts "  config           Show configuration"
    puts "  task list        List tasks"
    puts "  task show <id>   Show task details"
    puts "  task create      Create a new task"
    puts "  task execute <id> Execute a task"
    puts "  help             Show this help"
    puts
    puts "Examples:"
    puts "  ÆtherCodex ask \"What is the meaning of life?\""
    puts "  echo \"explain this code\" | ÆtherCodex ask"
    puts "  ÆtherCodex ask --file app.rb \"Refactor this\""
  end

  def repl_mode
    puts "\e[1m╭─ Delphic Session ──────────────────────────────────╮\e[0m"
    puts "\e[1m│\e[0m  The Pythian oracle awaits your query...             \e[1m│\e[0m"
    puts "\e[1m│\e[0m  type \e[33m/help\e[0m for commands, \e[31mexit\e[0m to depart              \e[1m│\e[0m"
    puts "\e[1m╰──────────────────────────────────────────────────────╯\e[0m"
    puts

    @terminal_stream = TerminalStream.new

    loop do
      print "\e[36mπ\e[0m "
      input = STDIN.gets
      break unless input
      input = input.strip
      break if input == 'exit'
      next if input.empty?

      if input == 'help'
        puts "Commands:"
        puts "  exit          Exit Delphic Session"
        puts "  help          Show this help"
        puts "  /file <path>  Attach a file to the next query"
        puts "  /clear        Clear conversation history"
        puts "  /config       Show current configuration"
        puts "  /tools        List available tools"
        puts
        next
      end

      if input.start_with?('/')
        handle_slash_command(input)
        next
      end

      context = Coniunctio.build(history: @history)
      original_stdout = $stdout
      $stdout = File.open('/dev/null', 'w')
      begin
        answer, arts, tool_results = Oracle.divination(input, context, tools: @tools,
                                                        stream: @terminal_stream) do |name, args, tool_ctx|
          @tools.handle(tool: name, args:, context: tool_ctx)
        end
      ensure
        $stdout.close
        $stdout = original_stdout
      end

      puts "\n\e[36m↯ #{answer}\e[0m\n\n"

      @history << { prompt: input, answer: answer, tool_calls: tool_results, created_at: Time.now }
    end
  end

  def handle_slash_command(input)
    case input
    when '/clear'
      @history.clear
      puts "Conversation history cleared."
    when '/config'
      config_mode
    when '/tools'
      @tools.tools.each do |name, tool|
        puts "  #{name}: #{tool.description}"
      end
    when %r{^/file\s+(.+)}
      path = $1.strip
      if File.exist?(path)
        content = File.read(path)
        puts "Attached: #{path} (#{content.lines.count} lines)"
        @history << { prompt: "/file #{path}", answer: "File attached: #{path}\n\n#{content}" }
      else
        puts "File not found: #{path}"
      end
    else
      puts "Unknown command: #{input}"
    end
  end
end

ÆtherCodexCLI.new.run if __FILE__ == $PROGRAM_NAME