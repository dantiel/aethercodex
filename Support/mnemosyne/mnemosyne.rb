# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'set'
require 'json'
require 'tiktoken_ruby'
require 'timeout'
require_relative '../config'
require_relative '../argonaut/argonaut'
require_relative '../instrumentarium/metaprogramming_utils'
using TokenExtensions



class Mnemosyne
  DB_VERSION = 2
  STOP_WORDS = Set.new %w[
    the a an and of in to with on for is are am be was were it this that
    at by from as if or but so not into out about then
  ]

  @aegis = { tags: [], summary: '', temperature: 1.0 }

  # Priority levels for tool call storage and truncation
  PRIORITY_HIGH = 3
  PRIORITY_MEDIUM = 2
  PRIORITY_LOW = 1

  # Default truncation thresholds based on priority
  DEFAULT_TRUNCATION_THRESHOLDS = {
    PRIORITY_HIGH   => { request: 2000, result: 4000 }, # Full or mostly full
    PRIORITY_MEDIUM => { request: 1000, result: 1000 }, # Excerpt of result
    PRIORITY_LOW    => { request: 500, result: 0 } # Truncated request only
  }.freeze

  # Default active memory window size (steps to keep in active memory)
  DEFAULT_ACTIVE_MEMORY_WINDOW = 5

  # Default priority decay rate (how quickly priority decreases with step distance)
  DEFAULT_PRIORITY_DECAY_RATE = 1.0

  # Default token limits for different contexts
  DEFAULT_TOKEN_LIMITS = {
    active_memory:       8000,
    step_context:        4000,
    tool_call_expansion: 2000
  }.freeze


  # Configuration for different operational modes
  OPERATIONAL_MODES = {
    standard:    {
      active_memory_window:  5,
      priority_decay_rate:   1.0,
      truncation_thresholds: DEFAULT_TRUNCATION_THRESHOLDS,
      token_limits:          DEFAULT_TOKEN_LIMITS
    },
    magnum_opus: {
      active_memory_window:  3, # Smaller window for step isolation
      priority_decay_rate:   2.0, # Faster decay for step separation
      truncation_thresholds: {
        PRIORITY_HIGH   => { request: 1500, result: 3000 },
        PRIORITY_MEDIUM => { request: 800, result: 800 },
        PRIORITY_LOW    => { request: 300, result: 0 }
      },
      token_limits:          {
        active_memory:       6000,
        step_context:        3000,
        tool_call_expansion: 1500
      }
    },
    analysis:    {
      active_memory_window:  8,
      priority_decay_rate:   0.5, # Slower decay for analysis context
      truncation_thresholds: {
        PRIORITY_HIGH   => { request: 3000, result: 6000 },
        PRIORITY_MEDIUM => { request: 1500, result: 2000 },
        PRIORITY_LOW    => { request: 800, result: 500 }
      },
      token_limits:          {
        active_memory:       12_000,
        step_context:        6000,
        tool_call_expansion: 3000
      }
    }
  }.freeze

  @current_mode = :standard

  class << self
    attr_reader :aegis

    # Maximum content length for notes to prevent context bloat
    MAX_NOTE_CONTENT_LENGTH = 500

    # Truncate note content to prevent excessive token usage
    def truncate_note_content(content, max_length: MAX_NOTE_CONTENT_LENGTH)
      return content if content.to_s.length <= max_length

      # Preserve structure while truncating
      if content.include? '```'
        # For code blocks, truncate the content but preserve the structure
        content.gsub(/```(\w*)\n.*?\n```/m) do |match|
          lang = ::Regexp.last_match 1
          inner_content = match[(lang.length + 4)..-4]
          if inner_content.length > max_length / 2
            "```#{lang}\n#{inner_content[0...(max_length / 2)]}...\n```"
          else
            match
          end
        end
      else
        "#{content[0...max_length]}..."
      end
    end


    # Create a new task with a plan and workflow type
    def create_task(title:, plan:, workflow_type: 'full', parent_task_id: nil)
      puts "CREATE TASK #{title}:#{plan} (workflow: #{workflow_type})"
      x = db.execute 'INSERT INTO tasks (title, plan, status, workflow_type, parent_task_id) VALUES (?, ?, ?, ?, ?)',
                     [title, plan, 'pending', workflow_type, parent_task_id]
      # puts "x=#{x}, id=#{db.last_insert_row_id}"
      { ok: true, id: db.last_insert_row_id }
    end


    # Get max steps based on workflow type
    def max_steps_for_workflow(workflow_type)
      case workflow_type.to_s
      when 'simple' then 3
      when 'analysis' then 5
      else 10 # full
      end
    end


    # Get step name mapping for workflow type
    def step_name(workflow_type, step_number)
      case workflow_type.to_s
      when 'simple'
        case step_number
        when 0 then 'Initium'
        when 1 then 'Solve'
        when 2 then 'Coagula'
        when 3 then 'Validatio'
        else "Step #{step_number}"
        end
      when 'analysis' # TODO: hermetical name for this workflow type
        case step_number
        when 0 then 'Initium'
        when 1 then 'Research'
        when 2 then 'Plan'
        when 3 then 'Analyze'
        when 4 then 'Synthesize'
        when 5 then 'Report'
        else "Step #{step_number}"
        end
      else # full
        case step_number
        when 0 then 'Initium'
        when 1 then 'Nigredo'
        when 2 then 'Albedo'
        when 3 then 'Citrinitas'
        when 4 then 'Rubedo'
        when 5 then 'Solve'
        when 6 then 'Coagula'
        when 7 then 'Test'
        when 8 then 'Purificatio'
        when 9 then 'Validatio'
        when 10 then 'Documentatio'
        else "Step #{step_number}"
        end
      end
    end


    # Get subtasks for a parent task
    def get_subtasks(parent_task_id)
      db.execute('SELECT * FROM tasks WHERE parent_task_id = ? ORDER BY created_at',
                 [parent_task_id])
        .map do |t|
        t.transform_keys!(&:to_sym)
      end
    end


    # Update subtask results for a parent task
    def update_subtask_results(parent_task_id, subtask_id, result)
      task = get_task parent_task_id
      return unless task

      subtask_results = JSON.parse(task[:subtask_results] || '{}')
      subtask_results[subtask_id.to_s] = result

      db.execute 'UPDATE tasks SET subtask_results = ? WHERE id = ?',
                 [subtask_results.to_json, parent_task_id]
    end


    # Update the Aegis summary dynamically
    def update_aegis_summary(summary)
      @aegis[:summary] = summary
      save_aegis_state(**@aegis)
    end


    # Dynamically adjust the Aegis temperature
    def set_aegis_temperature(temperature)
      @aegis[:temperature] = temperature
      save_aegis_state(**@aegis)
    end


    def fetch_history(limit: 7, max_tokens: nil, include_tool_calls: false)
      # Select all fields including tool_calls_json
      fields_sql = %w[prompt answer tool_call_count execution_time timestamp tool_calls_json
                      created_at].join ','
      entries = Mnemosyne.db.execute(
        "SELECT #{fields_sql} FROM entries ORDER BY id DESC LIMIT ?", [limit]
      ).map { |entry| entry.transform_keys!(&:to_sym) }

      # Process tool calls with priority-based filtering if requested
      if include_tool_calls
        entries = entries.map do |entry|
          if entry[:tool_calls_json] && !entry[:tool_calls_json].empty?
            tool_calls_hash = safe_parse_json entry[:tool_calls_json], {}
            tool_calls = tool_calls_hash.map(&:deep_symbolize_keys)
            # Apply priority-based filtering to tool calls
            filtered_tool_calls = tool_calls
            entry[:tool_calls] = filtered_tool_calls
          else
            entry[:tool_calls] = []
          end
          entry
        end
      end

      unless max_tokens.nil?
        tokens = 0
        included_entries = []
        entries.each do |entry|
          entry_tokens = (entry[:prompt] + entry[:answer]).tok_len

          if entry_tokens > max_tokens
            entry[:answer] = entry[:answer].gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                 '```\\1[CONTENT EXPIRED]```')
            entry_tokens = (entry[:prompt] + entry[:answer]).tok_len
            next if entry_tokens > max_tokens
          end
          break unless tokens + entry_tokens <= max_tokens

          included_entries << entry
          tokens += entry_tokens
        end

        entries = included_entries
      end

      entries.reverse
    end


    def fetch_aegis_summaries(before:, max_tokens:)
      summaries = Mnemosyne.db.execute('
        SELECT summary, tags, created_at FROM aegis_state
        WHERE created_at <= ? ORDER BY created_at DESC
        ', [before]).map { |el| el.transform_keys!(&:to_sym) }

      tokens = 0
      included_summaries = []

      summaries.each do |summary|
        summary_tokens = summary.to_s.tok_len
        break unless tokens + summary_tokens <= max_tokens

        included_summaries << summary
        tokens += summary_tokens
      end

      included_summaries
    end


    # Retrieve a note by ID
    def get_note(note_id)
      note = db.execute('SELECT * FROM project_notes WHERE id = ? LIMIT 1', [note_id]).first
      note&.transform_keys!(&:to_sym)
      note
    end


    # Retrieve a note by ID
    def get_task(task_id)
      task = db.execute('SELECT * FROM tasks WHERE id = ? LIMIT 1', [task_id]).first
      task&.transform_keys!(&:to_sym)
      task[:status] ||= 'pending' if task
      task
    end


    # Update task
    def update_task(task_id, **fields)
      fields.compact!
      x = db.execute "UPDATE tasks SET #{fields.map { |key, _| "#{key} = ?" }.join ', '}, " \
                     'updated_at = CURRENT_TIMESTAMP WHERE id = ?', [*fields.values, task_id]
      puts "UPDATE_TASK=#{x.inspect}"
      get_task task_id
    end


    def db_path
      CONFIG.memory_db_path
    end


    def db
      @db ||= begin
        FileUtils.mkdir_p File.dirname(db_path)
        db = SQLite3::Database.new db_path
        db.results_as_hash = true
        migrate db
        restore_aegis db
        db
      end
    end


    def migrate(db)
      # Create meta table if it doesn't exist
      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
      SQL

      # Get current database version
      db_version = db.execute("SELECT value FROM meta WHERE key = 'db_version'").first&.[]('value').to_i

      # Migrate from older versions if needed
      if 1 > db_version
        # Create entries table with latest schema
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            prompt TEXT,
            answer TEXT,
            tags TEXT,
            file TEXT,
            selection TEXT,
            execution_time REAL,
            tool_call_count INTEGER,
            tool_calls_json TEXT,
            timestamp TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            plan TEXT,
            updates TEXT,
            logs TEXT,
            status TEXT,
            current_step INTEGER DEFAULT 0,
            step_results TEXT DEFAULT '{}',  -- JSON storage for phase results
            workflow_type TEXT DEFAULT 'full',
            parent_task_id INTEGER,
            subtask_results TEXT DEFAULT '{}',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS project_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            links TEXT,
            content TEXT,
            tags TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS aegis_state (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tags TEXT,
            summary TEXT,
            temperature REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        
        
        # Add new columns if they don't exist
        existing_columns = db.execute('PRAGMA table_info(entries)').map { |col| col['name'] }

        unless existing_columns.include? 'execution_time'
          db.execute 'ALTER TABLE entries ADD COLUMN execution_time REAL'
        end

        unless existing_columns.include? 'tool_call_count'
          db.execute 'ALTER TABLE entries ADD COLUMN tool_call_count INTEGER'
        end

        unless existing_columns.include? 'timestamp'
          db.execute 'ALTER TABLE entries ADD COLUMN timestamp TEXT'
        end

        # Update to version 1
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '1')"
      end

      # Migrate to version 2 - add tool_calls_json to tasks table
      if 2 > db_version
        # Add tool_calls_json column to tasks table if it doesn't exist
        existing_task_columns = db.execute('PRAGMA table_info(tasks)').map { |col| col['name'] }

        unless existing_task_columns.include? 'tool_calls_json'
          db.execute "ALTER TABLE tasks ADD COLUMN tool_calls_json TEXT DEFAULT '[]'"
        end

        # Update to version 2
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '2')"
      end

      # Migrate to version 3 - add tool_calls_json to entries table
      if 3 > db_version
        # Add tool_calls_json column to entries table if it doesn't exist
        existing_entries_columns = db.execute('PRAGMA table_info(entries)').map do |col|
          col['name']
        end

        unless existing_entries_columns.include? 'tool_calls_json'
          db.execute 'ALTER TABLE entries ADD COLUMN tool_calls_json TEXT'
        end

        # Update to version 3
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '3')"
      end
    end


    # Search notes with scoring based on content, tags, and links
    def recall_notes(query, limit: 5, max_content_length: nil)
      query_tokens = tokenize query

      sql_query = if query_tokens.empty?
                    ''
                  else
                    'WHERE ' + (%w[content tags links].map do |field|
                      query_tokens&.map { |keyword| "#{field} LIKE '%#{keyword}%'" }&.join ' OR '
                    end.join ' OR ')
                  end

      notes = db.execute \
        "SELECT id, content, tags, links, created_at FROM project_notes #{sql_query}"

      notes.map do |note|
        note.transform_keys!(&:to_sym)

        score = 0

        if query_tokens.empty?
          score = 1
        else
          # Enhanced scoring with path matching for better file relevance
          score += 4 * (query_tokens & tokenize(note[:content])).size
          score += 3 * (query_tokens & tokenize(note[:tags])).size
          score += 2 * (query_tokens & tokenize(note[:links])).size

          # Boost score for exact path matches in links
          score += 5 if note[:links] && query_tokens.any? { |token| note[:links].include?(token) }
        end

        { **note, score: }
      end
      .select { |note| note[:score].positive? }
           .sort_by { |note| -note[:score] }
           .take(limit)
           .map do |note|
        # Apply content length limit if specified
        # puts "RECALL NOTES: #{note}"
        if max_content_length && note[:content] && note[:content].length > max_content_length
          note[:content] =
            truncate_note_content(note[:content], max_length: max_content_length)
        end
        # puts "RECALL NOTES: #{note[:links]}"
        if note[:links]
          note[:links] = note[:links].split(',').map do |link|
            if Argonaut.file_exists? link
              link
            else
              "~~#{link}~~ (path not found)"
            end
          end.join ','
        end
        note # Ensure we return the note hash, not the links string
      end
    end


    def save_aegis_state(tags: [], summary: nil, temperature: 1.0)
      tags = Array tags
      tags_json = tags.join ','
      db.execute \
        'INSERT INTO aegis_state ' \
        '(tags, summary, temperature, created_at) VALUES ' \
        '(?, ?, ?, CURRENT_TIMESTAMP)',
        [tags_json, summary, temperature]
    end


    def load_aegis(db: nil, limit: 3)
      db ||= @db
      db.execute 'SELECT tags, summary, temperature FROM aegis_state ' \
                 'ORDER BY created_at DESC LIMIT ?', [limit]
    end


    def restore_aegis(db = nil)
      db ||= @db
      aegis = (load_aegis db:, limit: 1)&.first
      @aegis = if aegis.nil? || aegis.empty?
                 { tags: [], summary: '', temperature: 1.0 }
               else
                 aegis.transform_keys!(&:to_sym)
               end
    end


    def unveil_aegis(**aegis)
      aegis.compact!
      @aegis.merge! aegis
      save_aegis_state(**aegis)

      recall_aegis_notes
    end


    def recall_aegis_notes(max_tokens: nil, max_content_length: nil)
      tags = @aegis[:tags] || []
      tags = @aegis[:summary].gsub(' ', ',') if tags.empty?
      tags = tags.split ',' if tags.is_a? String
      notes = recall_notes tags&.join(' '), limit: 8, max_content_length: max_content_length

      # Apply token limit if provided
      unless max_tokens.nil?
        token_count = 0
        included_notes = []

        notes.each do |note|
          note_tokens = note.to_json.tok_len
          break if token_count + note_tokens > max_tokens

          included_notes << note
          token_count += note_tokens
        end

        notes = included_notes
      end

      notes
    end


    def record(prompt: '',
               attachments: [],
               tags: nil,
               file: nil,
               execution_time: 0,
               tool_call_count: 0,
               timestamp: nil,
               answer: '',
               tool_calls: [],
               task_id: nil,
               step_id: nil,
               mode: nil)
      # Set operational mode if specified
      set_operational_mode mode if mode

      puts '[MNEMOSYNE][RECORD]: recording ' \
           "#{((prompt.to_json.inspect || '') + (answer || '')).tok_len} " \
           "tokens: #{answer.truncate 200}"
      puts "[MNEMOSYNE][RECORD]: tool_calls=#{tool_calls.inspect}"

      # Apply priority-based truncation to tool calls before storage
      truncated_tool_calls = truncate_tool_calls_by_priority tool_calls
      
      # TODO filter content
      # Calculate tool call count 
      actual_tool_call_count = truncated_tool_calls.is_a?(Array) ? truncated_tool_calls.size : 0

      # Store prompt, answer, and tool_calls in their respective fields
      entry_id = db.execute \
        'INSERT INTO entries (prompt, answer, tags, file, selection, execution_time, ' \
        'tool_call_count, tool_calls_json, created_at) VALUES (?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)',
        [prompt, answer, Array(tags).join(','), file,
         attachments.to_json, execution_time, actual_tool_call_count, truncated_tool_calls.to_json]
      entry_id = db.last_insert_row_id
      entry_id
    end
    

    # Apply priority-based truncation to tool calls before storage
    def truncate_tool_calls_by_priority(tool_calls)
      return [] unless tool_calls.is_a? Array

      tool_calls.map do |tool_call|
        tool_name = tool_call[:request]&.[](:tool) || tool_call['request']&.[]('tool')
        tool_priority = Instrumenta.tools[tool_name&.to_sym]&.history_priority || 1

        # Calculate base truncation limit based on tool priority
        base_limit = case tool_priority
                     when 0..1 then 300   # Standard tools (priority 1)
                     when 2..4 then 600   # Medium priority tools
                     when 5..9 then 1200  # High priority tools
                     else 3000 # Critical priority tools (10+)
                     end

        # Apply truncation to request and result fields
        truncated_tool_call = tool_call.dup

        # Truncate request arguments
        if truncated_tool_call[:request]
          truncated_tool_call[:request] =
            truncate_hash_by_priority(truncated_tool_call[:request], base_limit)
        elsif truncated_tool_call['request']
          truncated_tool_call['request'] =
            truncate_hash_by_priority(truncated_tool_call['request'], base_limit)
        end

        # Truncate result content
        if truncated_tool_call[:result]
          truncated_tool_call[:result] =
            truncate_hash_by_priority(truncated_tool_call[:result], base_limit)
        elsif truncated_tool_call['result']
          truncated_tool_call['result'] =
            truncate_hash_by_priority(truncated_tool_call['result'], base_limit)
        end

        truncated_tool_call
      end
    end


    # Helper method to truncate hash values based on priority limit
    def truncate_hash_by_priority(hash, base_limit)
      return hash unless hash.is_a? Hash

      hash.transform_values do |value|
        case value
        when String
          value.truncate base_limit
        when Hash
          truncate_hash_by_priority(value, base_limit / 2) # Recursively truncate nested hashes
        when Array
          value.map { |v| v.is_a?(String) ? v.truncate(base_limit / 3) : v }
        else
          value
        end
      end
    end


    # Get entry by ID
    def get_entry(entry_id)
      entry = db.execute('SELECT * FROM entries WHERE id = ? LIMIT 1', [entry_id]).first
      entry&.transform_keys!(&:to_sym)
    end


    # Alias for create_note for backward compatibility
    def remember(content:, links: nil, tags: nil)
      create_note content: content, links: links, tags: tags
    end


    # Create a note (id auto-generated, links optional) with content length limit
    def create_note(content:, links: nil, tags: nil)
      truncated_content = truncate_note_content content
      db.execute "
        INSERT INTO project_notes (content, links, tags, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                 [truncated_content, links&.join(','), tags&.join(',')]
      db.last_insert_row_id
    end


    # Alias for create_note for backward compatibility
    def remember(content:, links: nil, tags: nil)
      create_note content: content, links: links, tags: tags
    end


    # Fetch notes by links (for Argonaut file overview)
    def fetch_notes_by_links(links)
      links = [links] unless links.is_a? Array

      result = db.execute("SELECT * FROM project_notes WHERE #{(['links LIKE ?'] * links.count).join ' OR '}",
                          links.map { |link| "%#{link}%" })

      # Handle nil result gracefully
      return [] unless result

      result.each do |note|
        note.transform_keys!(&:to_sym)
      end
    end


    def update_note(id, content: nil, links: nil, tags: nil)
      truncated_content = truncate_note_content(content) if content
      db.execute \
        'UPDATE project_notes SET content = ?, links = ?, tags = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
          truncated_content || content, links&.join(','), tags&.join(','), id
        ]
    end


    # Remove note by id
    def remove_note(id)
      db.execute 'DELETE FROM project_notes WHERE id = ?', [id]
    end


    def remove_task(id)
      manage_tasks action: 'delete', id:
    end


    # Task ledger with states, progress, and dynamic plan updates
    def manage_tasks(params)
      params.transform_keys!(&:to_sym)
      action = params[:action].to_sym || :list
      case action
      when :create
        begin
          workflow_type = params[:workflow_type] || 'full'
          parent_task_id = params[:parent_task_id]
          x = db.execute 'INSERT INTO tasks (title, plan, updates, status, current_step, workflow_type, parent_task_id) VALUES ' \
                         '(?,?,?,?,?,?,?)', [params[:title], params[:plan], '[]', 'pending', 0, workflow_type, parent_task_id]
          { 'ok' => true,
            'id' => db.last_insert_row_id,
            title: params[:title],
            plan: params[:plan],
            workflow_type: workflow_type,
            parent_task_id: parent_task_id }
        rescue SQLite3::Exception => e
          warn "Task creation failed: #{e.message}"
          { 'ok' => false, 'error' => e.message }
        end
      when :update
        if params[:log]
          # Append to existing logs
          current_logs = db.execute('SELECT logs FROM tasks WHERE id = ?', [params[:id]]).first
          logs = if current_logs && current_logs['logs'] && !current_logs['logs'].empty?
                   JSON.parse current_logs['logs']
                 else
                   []
                 end
          logs << { timestamp: Time.now.to_f, message: params[:log] }
          db.execute 'UPDATE tasks SET logs = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [logs.to_json, params[:id]]
        end
        if params[:step_results]
          # Update step results
          db.execute 'UPDATE tasks SET step_results = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [params[:step_results], params[:id]]
        end
        if params[:status]
          db.execute 'UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [params[:status], params[:id]]
        end
        if params[:current_step]
          db.execute 'UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [params[:current_step], params[:id]]
        end
        { ok: true }
      when :activate
        db.execute 'UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   ['active', params[:id]]
        { ok: true }
      when :update_plan
        updates = JSON.parse(db.execute('SELECT updates FROM tasks WHERE id = ?',
                                        [params[:id]]).first['updates']) || []
        updates << { step: params[:current_step], plan: params[:plan], timestamp: Time.now.to_s }
        db.execute 'UPDATE tasks SET plan = ?, updates = ?, current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   [params[:plan], updates.to_json, params[:current_step], params[:id]]
        { ok: true }
      when :advance_step
        db.execute 'UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   [params[:current_step], params[:id]]
        { ok: true }
      when :delete
        db.execute 'DELETE FROM tasks WHERE id = ?', [params[:id]]
        { ok: true }
      else # list
        rows = db.execute 'SELECT * FROM tasks ORDER BY created_at DESC'
        rows.map { |r| r.transform_keys!(&:to_sym) }

        if params[:parent_task_id]
          rows = rows.filter { |task| params[:parent_task_id] == task[:parent_task_id] }
        end

        max_tokens = 1111
        token_count = 0
        included_rows = []

        rows.each do |row|
          row_tokens = row.to_json.tok_len 

          if row_tokens > max_tokens
            row[:message] = row[:message].to_s.gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                    '```\\1[CONTENT EXPIRED]```')
            row_tokens = row.to_json.tok_len
            next if row_tokens > max_tokens
          end

          break if token_count + row_tokens > max_tokens

          included_rows << row
          token_count += row_tokens
        end

        rows = included_rows
        # puts "ROWS=#{rows}"
        rows
      end
    end


    # Recall entries by tags or prompt


    # Recall entries by tags or prompt
    def search(query, limit: 5)
      entries = db.execute \
        'SELECT prompt, answer, tool_calls_json, created_at FROM entries WHERE ' \
        'tags LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?',
        ["%#{query}%", "%#{query}%", "%#{query}%", limit]


      entries.map do |entry|
        entry = entry.deep_symbolize_keys
        if entry[:tool_calls_json].present?
          tool_calls_hash = safe_parse_json entry[:tool_calls_json], {}
          tool_calls_hash = tool_calls_hash.map(&:deep_symbolize_keys)
          entry[:tool_calls] = format_history_tool_calls tool_calls_hash, 0
        end
        entry.delete :tool_calls_json
        entry
      end
    end


    def tokenize(text)
      return Set.new unless text.is_a? String

      tokens = text.downcase.scan(/\w+/)
      Set.new(tokens) - STOP_WORDS
    end


    def format_history_tool_calls(tool_calls, index)
      # Enhanced base_priority calculation with exponential decay
      base_priority = Math.exp(-index.to_f / 1.0) * 3
      
      # Calculate tool call density factor
      total_tool_calls = tool_calls.size
      density_factor = [1.0, total_tool_calls.to_f / 5.0].max

      tool_calls_str = tool_calls.map.with_index do |tcall, tool_index|
        tool_name = tcall[:request][:tool]
        next '' if tool_name.nil? && tcall[:content].nil?

        tool_priority = Instrumenta.tools[tool_name.to_sym]&.history_priority || 0

        # Calculate position factor for current history entry (index == 0)
        position_factor = if index.zero?
                            # In most recent entry, later tools get more detail
                            1.0 + ((tool_index.to_f / total_tool_calls) * 0.5)
                          else
                            # In older entries, all tools get reduced detail
                            1.0
                          end

        # Combined priority calculation
        combined_priority = (base_priority + tool_priority) * position_factor / density_factor

        # Scalable transient priority system with progressive truncation
        # Standard tools have priority 1, higher priorities get more generous limits
        case tool_priority
        when 1 # Standard tools
          args_truncate = [50, (combined_priority * 25).to_i].max
          result_truncate = [0, (combined_priority * 50).to_i].max
          content_truncate = [50, (combined_priority * 25).to_i].max
        when 2..4  # Medium priority tools
          args_truncate = [100, (combined_priority * 50).to_i].max
          result_truncate = [200, (combined_priority * 100).to_i].max
          content_truncate = [100, (combined_priority * 50).to_i].max
        when 5..9  # High priority tools
          args_truncate = [200, (combined_priority * 100).to_i].max
          result_truncate = [400, (combined_priority * 200).to_i].max
          content_truncate = [200, (combined_priority * 100).to_i].max
        when 10..Float::INFINITY # Critical priority tools (like oracle_conjuration)
          args_truncate = [500, (combined_priority * 200).to_i].max
          result_truncate = [1000, (combined_priority * 400).to_i].max
          content_truncate = [500, (combined_priority * 200).to_i].max
        else # Fallback for unknown priorities
          args_truncate = 50
          result_truncate = 0
          content_truncate = 100
        end

        # Apply additional scaling for most recent entry
        if index.zero?
          args_truncate = (args_truncate * 1.5).to_i
          result_truncate = (result_truncate * 1.5).to_i
          content_truncate = (content_truncate * 1.5).to_i
        end
        
        args = if 20 < args_truncate
                 " #{(tcall[:request][:args] || {}).to_s_no_quotes.truncate args_truncate, :middle}"
               else
                 ''
               end
        result = if 30 < result_truncate
                   " → #{tcall[:result].to_s_no_quotes.truncate result_truncate, :middle}\n"
                 else
                   ' # result omitted'
                 end
        # Include content field if present in tool call
        content = if tcall[:content]
                    "=== END TOOL HISTORY ===\n" \
                    "#{tcall[:content].truncate content_truncate}\n" \
                    "=== BEGIN TOOL HISTORY ===\n"
                  else
                    ''
                  end

        "#{tool_name}#{args}#{result}#{content}"
      end.join "\n"
      
      "=== BEGIN TOOL HISTORY ===\n#{tool_calls_str}\n=== END TOOL HISTORY ==="
    end
  end
end
