require_relative 'scriptorium'



# Live status broadcaster for real-time AI feedback
module HorologiumAeternum
  @websocket = nil
  
  
  def self.display_bytes(bytes)
    if bytes < 1024
      "#{bytes} Bytes"
    else
      kilobytes = bytes / 1024.0
      "%.2f KB" % kilobytes
    end
  end
  

  def self.set_websocket(ws)
    @websocket = ws
  end
  
  
  def self.send(method, type, data = {})
    return unless @websocket
    begin
      payload = {
        method: method,
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
  
  
  def self.send_status(type, data = {})
    send 'status', type, data
  end


  def self.tool_starting(tool_name, args = {})
    send_status('tool_starting', { tool: tool_name, args: args })
  end

  
  def self.oracle_revelation(content)
    send_status('oracle_revelation', { 
      content: Scriptorium.html_with_syntax_highlight(content.to_s) })
  end
  
  
  def self.oracle_conjuration_revelation(message, content)
    send_status('oracle_conjuration_revelation', { 
      message: Scriptorium.html("🏛️ #{message}"), 
      content: Scriptorium.html_with_syntax_highlight(content.to_s) })
  end
    
    
  def self.oracle_conjuration(prompt)
    send_status('oracle_conjuration', { 
      message: Scriptorium.html('🏛️ Oracle Conjuration'), 
      content: Scriptorium.html_with_syntax_highlight("#{prompt}") })
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
        message: Scriptorium.html("📖 Reading #{create_file_link path, nil, range[0]} (lines #{range[0]}-#{range[1]})"),
        path: path, range: range 
      })
    else
      send_status('file_reading', { 
        message: Scriptorium.html("📖 Reading #{create_file_link path}"),
        path: path 
      })
    end
  end
  
  
  def self.file_read_complete(path, bytes_read, range = nil, content = "")
    type = Scriptorium.language_tag_from_path path
    #TODO add linenumbers
    if range
      send_status('file_read_complete', { 
        message: Scriptorium.html("✅ Read #{display_bytes bytes_read} from #{create_file_link path, nil, range[0]}"),
        path: path, bytes: bytes_read, range: range,
        content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```")
      })
    else
      send_status('file_read_complete', { 
        message: Scriptorium.html("✅ Read #{display_bytes bytes_read} from #{create_file_link path}"),
        path: path, bytes: bytes_read,
        content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```")
      })
    end
  end
  
  
  def self.file_read_fail(path, error_message, range = nil)
    send_status('file_read_fail', { 
      message: Scriptorium.html("❌ Reading failed on #{create_file_link path}"),
      path: path, 
      error: error_message,
    })
  end
  
  
  def self.file_creating(path, bytes)
    send_status('file_creating', { 
      message: Scriptorium.html("✏️ Creating #{create_file_link path} (#{display_bytes bytes})"),
      path: path, bytes: bytes 
    })
  end
  
  
  def self.file_created(path, bytes, content="")
    type = Scriptorium.language_tag_from_path path
    send_status('file_created', { 
      message: Scriptorium.html("✅ Created #{create_file_link path} (#{display_bytes bytes} written)"),
      path: path, 
      bytes: bytes,
      content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```"),
    })
  end
  
  
  def self.file_patching(path, diff_content, diff_lines)
    send_status('file_patching', { 
      message: Scriptorium.html("🔧 Applying patch to #{create_file_link path} (#{diff_lines} diff lines)"),
      path: path, 
      diff: Scriptorium.html_with_syntax_highlight("```diff\n#{diff_content}\n```"),
      expandable: true
    })
  end
  
  
  def self.file_patched(path, old_content, new_content)
    html_diff_content = Scriptorium.hunk_based_character_diff old_content, new_content
    
    send_status('file_patched', { 
      message: Scriptorium.html("✅ Patch applied to #{create_file_link path}"),
      path: path, 
      diff: "<pre class=\"diff\"><code>#{html_diff_content}</code></pre>",
      expandable: true
    })
  end
  
  
  def self.file_patched_fail(path, error_message, diff_content)
    send_status('file_patched_fail', {
      message: Scriptorium.html("❌ Patch failed on #{create_file_link path}"),
      path: path, 
      diff: Scriptorium.html_with_syntax_highlight("```\n#{error_message}\n```\n\n```diff\n#{diff_content}\n```"),
      error: error_message
    })
  end
  
  
  def self.command_executing(cmd)
    send_status('command_executing', { 
      message: Scriptorium.html("⚡ Executing: `#{cmd}`"),
      command: cmd 
    })
  end
  
  
  def self.processing(message)
    send_status('processing', { message: "#{message}" })
  end
  
  
  def self.completed(summary)
    send_status('completed', { summary: Scriptorium.html(summary) })
  end
  
  
  def self.command_completed(cmd, output_length, content = "", exit_status = nil)
    symbol = if 0 == exit_status then '✅' else '❌' end
    send_status('command_completed', { 
      message: Scriptorium.html("#{symbol} Command complete: `#{cmd}` (#{output_length} chars output)"),
      command: cmd, output_length: output_length,
      content: content
    })
  end
  
  
  def self.file_renaming(from, to)
    send_status('file_renaming', { 
      message: Scriptorium.html("📝 Renaming #{create_file_link from} → #{create_file_link to}"),
      from: from, to: to 
    })
  end
  
  
  def self.file_renamed(from, to)
    send_status('file_renamed', { 
      message: Scriptorium.html("✅ Renamed #{create_file_link from} → #{create_file_link to}"),
      from: from, to: to 
    })
  end
  
  
  def self.memory_storing(key, bytes)
    send_status('memory_storing', { 
      message: Scriptorium.html("🧠 Storing memory: `#{key}` (#{display_bytes bytes})"),
      key: key, bytes: bytes 
    })
  end
  
  
  def self.memory_stored(key)
    send_status('memory_stored', { 
      message: Scriptorium.html("✅ Memory stored: `#{key}`"),
      key: key 
    })
  end

  
  
  def self.aegis_unveiled(tags, summary, temperature, notes)
    temperature = if temperature then "\n\nTemperature #{temperature}" else '' end
    notes = "\n\n**Notes:**\n\n#{render_notes notes}"
    send_status('aegis_unveiled', { 
      message: Scriptorium.html("🔮 Aegis unveiled: `#{tags.join ', '}`"),
      content: Scriptorium.html_with_syntax_highlight("#{summary}#{temperature}#{notes}")
    })
  end
  
  
  def self.memory_searching(query, limit)
    send_status('memory_searching', { 
      message: Scriptorium.html("🔍 Searching memories for: *#{query}* (limit: #{limit})"),
      query: query, limit: limit 
    })
  end
  
  
  def self.memory_found(query, count, notes)
    send_status('memory_found', { 
      message: Scriptorium.html("✅ Found **#{count}** memories for: *\"#{query}\"*"),
      query: query, count: count, content: notes
    })
  end
    
  
  def self.note_added(note)
    send_status('note_added', { 
      message: "🔒 Note stored",
      content: Scriptorium.html_with_syntax_highlight(render_note note) })
  end
  
  
  def self.note_updated(note)
    send_status('note_updated', { 
      message: "🔒 Note stored.",
      content: Scriptorium.html_with_syntax_highlight(render_note note)
    })
  end


  def self.notes_recalled(query, limit, notes)
    send_status('notes_recalled', { 
      query: query, count: notes.count, 
      message: Scriptorium.html("🔍 Recalled **#{notes.count}** (limit: **#{limit}**) Hermetic notes for: *#{query}*"),
      notes: Scriptorium.html_with_syntax_highlight(render_notes notes)
    })
  end

  
  def self.info_message(message)
    send_status('info', { message: Scriptorium.html_with_syntax_highlight("💬 #{message}") })
  end
  
  
  def self.render_note(note)
    links = if note[:links].nil? || note[:links].empty?
      ''
    else 
      if note[:links].is_a? Array then note[:links]
      else note[:links].split(',') end.map { |link| "- #{create_file_link link}" }.join "\n" 
    end
    # TODO make tags clickable as links
    tags = if note[:tags].nil? || note[:tags].empty? then ''
           else
             if note[:tags].is_a? Array then note[:tags] 
             else note[:tags].split(',') end.map { |tag| "\\\##{tag}" }.join ", " 
           end
    note_info = if note[:id] then "**ID:** #{note[:id]}, **updated:** #{note[:created_at] || note[:updated_at]}"
                else '' end
    <<~MARKDOWN
    #{note_info}

    #{note[:content]}

    #{tags}
    
    #{links}
    MARKDOWN
  end
  
  
  def self.render_notes(notes)
    if notes.empty?
      'None.'
    else
      notes.map { |note| render_note note }.join "\n\n---\n\n"
    end
  end
  
  
  def self.file_overview(path, result)
    content = <<~MARKDOWN
    **File Size:** #{display_bytes result[:file_info][:size]}
    **Number of Lines:** #{result[:file_info][:lines]}
    **Last Modified:** #{result[:file_info][:last_modified]}

    ### Notes:
    #{render_notes result[:notes]}
    MARKDOWN
    
    send_status 'file_overview', {
      message: Scriptorium.html("💬 Overview: #{create_file_link path}"),
      content: Scriptorium.html_with_syntax_highlight(content)
    }
  end
  
  
  def self.thinking(message = "🔮 Consulting the astral codex...", content = "")
    send_status('thinking', { 
      message: Scriptorium.html_with_syntax_highlight("🧠 #{message}"),
      content: Scriptorium.html_with_syntax_highlight("#{content}") })
  end
  
  
  def self.divination(message = "🔮 Consulting the astral codex...")
    send_status('divination', { message: Scriptorium.html("🔮 #{message}") })
  end
  
  
  def self.server_error(error, type = 'Server Error')
    send_status('server_error', {
      error: Scriptorium.html("❌ #{type}#{if error then ': ' else '' end}`#{error}`")
    })
  end
  
  
  def self.system_error(message, error)
    send_status('server_error', {
      message: Scriptorium.html("❌ #{message}: `#{error}`")
    })
  end
  
  
  def self.system_message(message)
    send_status('system_message', {
      message: Scriptorium.html(message)
    })
  end
  
  
  def self.create_file_link(file, display_name = nil, line = nil, column = nil)
    line = " line=\"#{line}\"" if line
    column = " column=\"#{column}\"" if column
    "<file path=\"#{file}\"#{line}#{column}>#{display_name || file}</file>"
  end
  
  
  def self.attach(message, file: nil, selection: nil, lines: nil, content: nil, line: nil, column: nil, selection_range: nil)
    type = Scriptorium.language_tag_from_path file
    selection_html = Scriptorium.html_with_syntax_highlight("```#{type}\n#{selection}\n```") if selection
    file_html = create_file_link file, nil, line, column
    send 'attach', 'attachment', {
      file:, file_html:, selection:, selection_html:, lines:, content:, line:, column:, 
      selection_range:
    }
  end
end
