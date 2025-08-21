# frozen_string_literal: true

require_relative 'scriptorium'



# Live status broadcaster for real-time AI feedback
module HorologiumAeternum
  @websocket = nil


  def self.display_bytes(bytes)
    if 1024 > bytes
      "#{bytes} Bytes"
    else
      kilobytes = bytes / 1024.0
      '%.2f KB' % kilobytes
    end
  end


  def self.set_websocket(ws)
    @websocket = ws
  end


  def self.send(method, type, data = {}, uuid: nil)
    return unless @websocket

    begin
      uuid ||= SecureRandom.uuid

      payload = {
        method: method,
        result: { type: type, data: data, timestamp: Time.now.to_f, uuid: }
      }.to_json
      @websocket.send payload
      # Force immediate WebSocket flush
      if @websocket.respond_to?(:instance_variable_get) && @websocket.instance_variable_get(:@driver).respond_to?(:flush)
        @websocket.instance_variable_get(:@driver)&.flush
      end
      # Also try explicit sync
      $stdout.flush if $stdout.respond_to? :flush
      uuid
    rescue StandardError => e
      warn "Failed to send status: #{e.message}"
      nil
    end
  end


  def self.send_status(type, data = {}, uuid: nil)
    send 'status', type, data, uuid:
  end


  def self.tool_starting(tool_name, args = {}, uuid: nil)
    send_status('tool_starting', { tool: tool_name, args: args }, uuid:)
  end


  def self.oracle_revelation(content, uuid: nil)
    send_status('oracle_revelation', {
                  content: Scriptorium.html_with_syntax_highlight(content.to_s)
                }, uuid:)
  end


  def self.oracle_conjuration_revelation(message, content, uuid: nil)
    send_status('oracle_conjuration_revelation', {
                  message: Scriptorium.html("🏛️ #{message}"),
                  content: Scriptorium.html_with_syntax_highlight(content.to_s)
                }, uuid:)
  end


  def self.oracle_conjuration(prompt, uuid: nil)
    send_status('oracle_conjuration', {
                  message: Scriptorium.html('🏛️ Oracle Conjuration'),
                  content: Scriptorium.html_with_syntax_highlight(prompt.to_s)
                }, uuid:)
  end


  def self.tool_completed(tool_name, result, uuid: nil)
    send_status('tool_completed', { tool: tool_name, result: result }, uuid:)
  end


  def self.test_pulse(uuid: nil)
    send_status('thinking', { message: '🔮 System pulse test...' }, uuid:)
    sleep 0.5
    send_status('completed', { summary: 'Pulse successful - streaming verified' }, uuid:)
  end


  def self.file_reading(path, range = nil, uuid: nil)
    if range
      send_status('file_reading', {
                    message: Scriptorium.html("📖 Reading #{create_file_link path, nil,
                                                                             range[0]} (lines #{range[0]}-#{range[1]})"),
                    path:    path,
                    range:   range
                  }, uuid:)
    else
      send_status('file_reading', {
                    message: Scriptorium.html("📖 Reading #{create_file_link path}"),
                    path:    path
                  }, uuid:)
    end
  end


  def self.file_read_complete(path, bytes_read, range = nil, content = '', uuid: nil)
    type = Scriptorium.language_tag_from_path path
    # TODO: add linenumbers
    if range
      send_status('file_read_complete', {
                    message: Scriptorium.html("✅ 📖 Read #{display_bytes bytes_read} from " \
                                              "#{create_file_link path, nil, range[0]} " \
                                              "(lines #{range[0]}-#{range[1]})"),
                    path:    path,
                    bytes:   bytes_read,
                    range:   range,
                    content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```")
                  }, uuid:)
    else
      send_status('file_read_complete', {
                    message: Scriptorium.html("✅ 📖 Read #{display_bytes bytes_read} from " \
                                              "#{create_file_link path}"),
                    path:    path,
                    bytes:   bytes_read,
                    content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```")
                  }, uuid:)
    end
  end


  def self.file_read_fail(path, error_message, _range = nil, uuid: nil)
    send_status('file_read_fail', {
                  message: Scriptorium.html("❌ Reading failed on #{create_file_link path}"),
                  path:    path,
                  error:   error_message
                }, uuid:)
  end


  def self.file_creating(path, bytes, uuid: nil)
    uuid = send_status('file_creating', {
                         message: Scriptorium.html("✏️ Creating #{create_file_link path} (#{display_bytes bytes})"),
                         path:    path,
                         bytes:   bytes
                       }, uuid:)
    uuid
  end


  def self.file_created(path, bytes, content = '', uuid: nil)
    type = Scriptorium.language_tag_from_path path
    send_status('file_created', {
                  message: Scriptorium.html("✅ ✏️ Created #{create_file_link path} (#{display_bytes bytes} written)"),
                  path:    path,
                  bytes:   bytes,
                  content: Scriptorium.html_with_syntax_highlight("```#{type}\n#{content}\n```")
                }, uuid:)
  end


  def self.file_patching(path, diff_content, diff_lines, uuid: nil)
    send_status('file_patching', {
                  message:    Scriptorium.html("🔧 Applying patch to #{create_file_link path} (#{diff_lines} diff lines)"),
                  path:       path,
                  diff:       Scriptorium.html_with_syntax_highlight("```diff\n#{diff_content}\n```"),
                  expandable: true
                }, uuid:)
  end


  def self.file_patched(path, old_content, new_content, uuid: nil)
    html_diff_content = Scriptorium.hunk_based_character_diff old_content, new_content, path

    send_status('file_patched', {
                  message:    Scriptorium.html("✅ 🔧 Patch applied to #{create_file_link path}"),
                  path:       path,
                  diff:       "<pre class=\"diff\"><code>#{html_diff_content}</code></pre>",
                  expandable: true
                }, uuid:)
  end


  def self.file_patched_fail(path, error_message, diff_content, uuid: nil)
    send_status('file_patched_fail', {
                  message: Scriptorium.html("❌ Patch failed on #{create_file_link path}"),
                  path:    path,
                  diff:    Scriptorium.html_with_syntax_highlight("```\n#{error_message}\n```\n\n```diff\n#{diff_content}\n```"),
                  error:   error_message
                }, uuid:)
  end


  def self.command_executing(cmd, uuid: nil)
    send_status('command_executing', {
                  message: Scriptorium.html("⚡ Executing: `#{cmd}`"),
                  command: cmd
                }, uuid:)
  end


  def self.processing(message, uuid: nil)
    send_status('processing', { message: message.to_s }, uuid:)
  end


  def self.completed(summary, uuid: nil)
    send_status('completed', { summary: Scriptorium.html(summary) }, uuid:)
  end


  def self.command_completed(cmd, output_length, content = '', exit_status = nil, uuid: nil)
    symbol = if exit_status.zero? then '✅ ⚡' else '❌ ⚡' end
    send_status('command_completed', {
                  message:       Scriptorium.html("#{symbol} Command complete: `#{cmd}` (#{output_length} chars output)"),
                  command:       cmd,
                  output_length: output_length,
                  content:       content
                }, uuid:)
  end


  # Task lifecycle events
  def self.task_updated(task_id, title: nil, plan: nil, progress: nil, max_steps: nil, uuid: nil)
    send_status('task_updated', {
                  message:   Scriptorium.html("🔄 Task progress: #{progress}/#{max_steps}"),
                  title:,
                  task_id:,
                  plan:,
                  progress:,
                  max_steps:
                }, uuid:)
  end


  def self.task_log_added(task_id, timestamp:, message:, uuid: nil)
    send_status('task_log_added', {
                  message:   Scriptorium.html('📝 Task log updated'),
                  task_id:,
                  content:   Scriptorium.html_with_syntax_highlight(message),
                  timestamp:
                }, uuid:)
  end


  def self.task_started(task_id, title, max_steps, uuid: nil)
    send_status('task_started', {
                  message:   Scriptorium.html("📦 Task started: #{title} (0/#{max_steps})"),
                  task_id:,
                  title:,
                  max_steps:,
                  progress:  0
                }, uuid:)
  end


  def self.task_created(title, plan, max_steps, task_id, uuid: nil)
    send_status('task_created', {
                  message:   Scriptorium.html("📋 Task created: #{title} (max steps: #{max_steps})"),
                  title:,
                  max_steps:,
                  progress:  0,
                  task_id:,
                  plan: Scriptorium.html_with_syntax_highlight(plan)
                }, uuid:)
  end


  def self.task_updated(task_id, title: nil, plan: nil, progress: nil, max_steps: nil, uuid: nil)
    send_status('task_updated', {
                  message:   Scriptorium.html("🔄 Task progress: #{progress}/#{max_steps}"),
                  title:,
                  task_id:,
                  plan:,
                  progress:,
                  max_steps:
                }, uuid:)
  end


  def self.task_completed(task_id, title, duration, uuid: nil)
    send_status('task_completed', {
                  message:  Scriptorium.html("✅ Task completed: #{title} (#{duration.round 2}s)"),
                  task_id:,
                  title:,
                  duration:
                }, uuid:)
  end


  def self.task_list(tasks, uuid: nil)
    tasks_md = tasks.map do |task|
      plan = task[:plan].each_line.map { |line| "  #{line}" }.join
      "- \\##{task[:id]} **#{task[:title]}:**\n#{plan}\n  _(Status: #{task[:status]})_"
    end.join "\n\n"
    send_status('task_list', {
                  message: Scriptorium.html("Found **#{tasks.count}** Active Tasks"),
                  content: Scriptorium.html_with_syntax_highlight(tasks_md)
                }, uuid:)
  end


  def self.file_renaming(from, to, uuid: nil)
    send_status('file_renaming', {
                  message: Scriptorium.html("📝 Renaming #{create_file_link from} → #{create_file_link to}"),
                  from:    from,
                  to:      to
                }, uuid:)
  end


  def self.file_renamed(from, to, uuid: nil)
    send_status('file_renamed', {
                  message: Scriptorium.html("✅ 📝 Renamed #{create_file_link from} → #{create_file_link to}"),
                  from:    from,
                  to:      to
                }, uuid:)
  end


  def self.memory_storing(key, bytes, uuid: nil)
    send_status('memory_storing', {
                  message: Scriptorium.html("🧠 Storing memory: `#{key}` (#{display_bytes bytes})"),
                  key:     key,
                  bytes:   bytes
                }, uuid:)
  end


  def self.memory_stored(key, uuid: nil)
    send_status('memory_stored', {
                  message: Scriptorium.html("✅ 🧠 Memory stored: `#{key}`"),
                  key:     key
                }, uuid:)
  end


  def self.aegis_unveiled(tags, summary, temperature, notes, uuid: nil)
    temperature = if temperature then "\n\nTemperature #{temperature}" else '' end
    notes = "\n\n**Notes:**\n\n#{render_notes notes}"
    send_status('aegis_unveiled', {
                  message: Scriptorium.html("🔮 Aegis unveiled: `#{tags.join ', '}`"),
                  content: Scriptorium.html_with_syntax_highlight("#{summary}#{temperature}#{notes}")
                }, uuid:)
  end


  def self.memory_searching(query, limit, uuid: nil)
    send_status('memory_searching', {
                  message: Scriptorium.html("🔍 Searching memories for: *#{query}* (limit: #{limit})"),
                  query:   query,
                  limit:   limit
                }, uuid:)
  end


  def self.memory_found(query, count, notes, uuid: nil)
    send_status('memory_found', {
                  message: Scriptorium.html("✅ 🔍 Found **#{count}** memories for: *\"#{query}\"*"),
                  query:   query,
                  count:   count,
                  content: notes
                }, uuid:)
  end


  def self.note_added(note, uuid: nil)
    send_status('note_added', {
                  message: '🔒 Note stored',
                  content: Scriptorium.html_with_syntax_highlight(render_note(note))
                }, uuid:)
  end


  def self.note_updated(note, uuid: nil)
    send_status('note_updated', {
                  message: '🔒 Note stored.',
                  content: Scriptorium.html_with_syntax_highlight(render_note(note))
                }, uuid:)
  end


  def self.notes_recalled(query, limit, notes, uuid: nil)
    send_status('notes_recalled', {
                  query:   query,
                  count:   notes.count,
                  message: Scriptorium.html("🔍 Recalled **#{notes.count}** (limit: **#{limit}**) Hermetic notes for: *#{query}*"),
                  notes:   Scriptorium.html_with_syntax_highlight(render_notes(notes))
                }, uuid:)
  end


  def self.info_message(message, uuid: nil)
    send_status('info', { message: Scriptorium.html_with_syntax_highlight("💬 #{message}") }, uuid:)
  end


  def self.render_note(note)
    links = if note[:links].nil? || note[:links].empty?
              ''
            else
              if note[:links].is_a? Array then note[:links]
              else
                note[:links].split ',' end.map { |link| "- #{create_file_link link}" }.join "\n"
            end
    # TODO: make tags clickable as links
    tags = if note[:tags].nil? || note[:tags].empty? then ''
           else
             if note[:tags].is_a? Array then note[:tags]
             else
               note[:tags].split ',' end.map { |tag| "\\##{tag}" }.join ', '
           end
    note_info = if note[:id] then "**ID:** #{note[:id]}, **updated:** #{note[:created_at] || note[:updated_at]}"
                else
                  '' end
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


  def self.file_overview(path, result, uuid: nil)
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
    }, uuid:
  end


  def self.thinking(message = '🔮 Consulting the astral codex...', content = '', uuid: nil)
    send_status('thinking', {
                  message: Scriptorium.html_with_syntax_highlight("🧠 #{message}"),
                  content: Scriptorium.html_with_syntax_highlight(content.to_s)
                }, uuid:)
  end


  def self.divination(message = '🔮 Consulting the astral codex...', uuid: nil)
    send_status('divination', { message: Scriptorium.html("🔮 #{message}") }, uuid:)
  end


  def self.server_error(error, type = 'Server Error', uuid: nil)
    send_status('server_error', {
                  error: Scriptorium.html("❌ **#{type}#{':' if error}** `#{error}`")
                }, uuid:)
  end


  def self.system_error(message, error, uuid: nil)
    send_status('server_error', {
                  message: Scriptorium.html("❌ #{message}: `#{error}`")
                }, uuid:)
  end


  def self.system_message(message, uuid: nil)
    send_status('system_message', {
                  message: Scriptorium.html(message)
                }, uuid:)
  end


  def self.create_file_link(file, display_name = nil, line = nil, column = nil)
    line = " line=\"#{line}\"" if line
    column = " column=\"#{column}\"" if column
    "<file path=\"#{file}\"#{line}#{column}>#{display_name || file}</file>"
  end


  def self.attach(_message,
                  file: nil,
                  selection: nil,
                  lines: nil,
                  content: nil,
                  line: nil,
                  column: nil,
                  selection_range: nil,
                  uuid: nil)
    type = Scriptorium.language_tag_from_path file
    if selection
      selection_html = Scriptorium.html_with_syntax_highlight("```#{type}\n#{selection}\n```")
    end
    file_html = create_file_link file, nil, line, column
    send 'attach', 'attachment', {
      file:,
      file_html:,
      selection:,
      selection_html:,
      lines:,
      content:,
      line:,
      column:,
      selection_range:
    }, uuid:
  end
end
