require_relative 'markdown_renderer'



# Live status broadcaster for real-time AI feedback
module LiveStatus
  @websocket = nil
  
  
  def self.set_websocket(ws)
    @websocket = ws
  end
  
  
  def self.send_status(type, data = {})
    return unless @websocket
    begin
      payload = {
        method: 'status',
        result: { type: type, data: data, timestamp: Time.now.to_f }
      }.to_json
      @websocket.send(payload)
      # Force immediate WebSocket flush
      if @websocket.respond_to?(:instance_variable_get)
        if @websocket.instance_variable_get(:@driver).respond_to?(:flush)
          @websocket.instance_variable_get(:@driver)&.flush 
        end
      end
      # Also try explicit sync
      $stdout.flush if $stdout.respond_to?(:flush)
    rescue => e
      warn "Failed to send status: #{e.message}"
    end
  end


  def self.tool_starting(tool_name, args = {})
    send_status('tool_starting', { tool: tool_name, args: args })
  end
  
  
  def self.ai_response(content)
    send_status('ai_response', { content: MarkdownRenderer.html_with_syntax_highlight(content.to_s), is_partial: false })
  end
  
  
  def self.tool_completed(tool_name, result)
    send_status('tool_completed', { tool: tool_name, result: result })
  end
  
  
  def self.test_pulse
    send_status('thinking', { message: '🔮 System pulse test...' })
    sleep(0.5)
    send_status('completed', { summary: 'Pulse successful - streaming verified' })
  end
  
    
  def self.file_reading(path, range = nil)
    if range
      send_status('file_reading', { 
        message: MarkdownRenderer.html("📖 Reading `#{path}` (lines #{range[0]}-#{range[1]})"),
        path: path, range: range 
      })
    else
      send_status('file_reading', { 
        message: MarkdownRenderer.html("📖 Reading `#{path}`"),
        path: path 
      })
    end
  end
  
  
  def self.file_read_complete(path, bytes_read, range = nil, content = "")
    type = MarkdownRenderer.language_tag_from_path path
    #TODO add linenumbers
    if range
      send_status('file_read_complete', { 
        message: MarkdownRenderer.html("✅ Read #{bytes_read} bytes from `#{path}`"),
        path: path, bytes: bytes_read, range: range,
        content: MarkdownRenderer.html_with_syntax_highlight("```#{type}\n#{content}\n```")
      })
    else
      send_status('file_read_complete', { 
        message: MarkdownRenderer.html("✅ Read #{bytes_read} bytes from `#{path}`"),
        path: path, bytes: bytes_read,
        content: MarkdownRenderer.html_with_syntax_highlight("```#{type}\n#{content}\n```")
      })
    end
  end
  
  
  def self.file_read_fail(path, error_message, range = nil)
    send_status('file_read_fail', { 
      message: MarkdownRenderer.html("❌ Reading failed on `#{path}`"),
      path: path, 
      error: error_message,
    })
  end
  
  
  def self.file_creating(path, bytes)
    send_status('file_creating', { 
      message: MarkdownRenderer.html("✏️ Creating `#{path}` (#{bytes} bytes)"),
      path: path, bytes: bytes 
    })
  end
  
  
  def self.file_created(path, bytes, content="")
    type = MarkdownRenderer.language_tag_from_path path
    send_status('file_created', { 
      message: MarkdownRenderer.html("✅ Created `#{path}` (#{bytes} bytes written)"),
      path: path, 
      bytes: bytes,
      content: MarkdownRenderer.html_with_syntax_highlight("```#{type}\n#{content}\n```"),
    })
  end
  
  
  def self.file_patching(path, diff_lines)
    send_status('file_patching', { 
      message: MarkdownRenderer.html("🔧 Applying patch to `#{path}` (#{diff_lines} diff lines)"),
      path: path, 
      diff_lines: diff_lines,
      expandable: true
    })
  end
  
  
  def self.file_patched(path, diff_content)
    send_status('file_patched', { 
      message: MarkdownRenderer.html("✅ Patch applied to `#{path}`"),
      path: path, 
      diff: MarkdownRenderer.html_with_syntax_highlight("```diff\n#{diff_content}\n```"),
      expandable: true
    })
  end
  
  
  def self.file_patched_fail(path, error_message, diff_content)
    send_status('file_patched_fail', {
      message: MarkdownRenderer.html("❌ Patch failed on `#{path}`"),
      path: path, 
      diff: MarkdownRenderer.html_with_syntax_highlight("```\n#{error_message}```\n\n```diff\n#{diff_content}\n```"),
      error: error_message
    })
  end
  
  
  def self.command_executing(cmd)
    send_status('command_executing', { 
      message: MarkdownRenderer.html("⚡ Executing: `#{cmd}`"),
      command: cmd 
    })
  end
  
  
  def self.processing(message)
    send_status('processing', { message: "#{message}" })
  end
  
  
  def self.completed(summary)
    send_status('completed', { summary: summary })
  end
  
  
  def self.command_completed(cmd, output_length, content = "")
    send_status('command_completed', { 
      message: MarkdownRenderer.html("✅ Command complete: `#{cmd}` (#{output_length} chars output)"),
      command: cmd, output_length: output_length,
      content: content
    })
  end
  
  
  def self.file_renaming(from, to)
    send_status('file_renaming', { 
      message: MarkdownRenderer.html("📝 Renaming `#{from}` → `#{to}`"),
      from: from, to: to 
    })
  end
  
  
  def self.file_renamed(from, to)
    send_status('file_renamed', { 
      message: MarkdownRenderer.html("✅ Renamed `#{from}` → `#{to}`"),
      from: from, to: to 
    })
  end
  
  
  def self.memory_storing(key, bytes)
    send_status('memory_storing', { 
      message: MarkdownRenderer.html("🧠 Storing memory: `#{key}` (#{bytes} bytes)"),
      key: key, bytes: bytes 
    })
  end
  
  
  def self.memory_stored(key)
    send_status('memory_stored', { 
      message: MarkdownRenderer.html("✅ Memory stored: `#{key}`"),
      key: key 
    })
  end
  
  
  def self.memory_searching(query, limit)
    send_status('memory_searching', { 
      message: MarkdownRenderer.html("🔍 Searching memories for: \"#{query}\" (limit: #{limit})"),
      query: query, limit: limit 
    })
  end
  
  
  def self.memory_found(query, count)
    send_status('memory_found', { 
      message: MarkdownRenderer.html("✅ Found **#{count}** memories for: \"#{query}\""),
      query: query, count: count 
    })
  end
  
  
  def self.info_message(message)
    send_status('info', { message: MarkdownRenderer.html("💬 #{message}") })
  end
  
  
  def self.thinking(message = "🔮 Consulting the astral codex...")
    send_status('thinking', { message: MarkdownRenderer.html("🧠 #{message}") })
  end
  
  
  def self.divination(message = "🔮 Consulting the astral codex...")
    send_status('divination', { message: MarkdownRenderer.html("🔮 #{message}") })
  end
  
  
  def self.server_error(error)
    send_status('server_error', {
      message: MarkdownRenderer.html("❌ Server Error: #{error}")
    })
  end
end
