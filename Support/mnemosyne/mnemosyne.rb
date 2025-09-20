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

# Alias for create_note for backward compatibility
def self.remember(content:, links: nil, tags: nil)
  create_note content: content, links: links, tags: tags
end


class Mnemosyne
  @tokenizer = Tiktoken.encoding_for_model 'gpt-4'

  DB_VERSION = 1
  STOP_WORDS = Set.new %w[
    the a an and of in to with on for is are am be was were it this that
    at by from as if or but so not into out about then
  ]

  @aegis = { tags: [], summary: '', temperature: 1.0 }

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


    def fetch_history(limit: 7, max_tokens: nil)
      entries = Mnemosyne.db.execute(
        'SELECT prompt, answer, created_at FROM entries ORDER BY id DESC LIMIT ?', [limit]
      ).map { |entry| entry.transform_keys!(&:to_sym) }
      unless max_tokens.nil?
        tokens = 0
        included_entries = []
        entries.each do |entry|
          entry_tokens = tok_len entry.to_json

          if entry_tokens > max_tokens
            entry[:answer] = entry[:answer].gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                 '```\\1[CONTENT EXPIRED]```')
            entry_tokens = tok_len entry.to_json
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
        summary_tokens = tok_len summary
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
      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
      SQL
      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          prompt TEXT,
          answer TEXT,
          tags TEXT,
          file TEXT,
          selection TEXT,
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
        note[:links] = note[:links].split(',').map do |link|
          if Argonaut.file_exists? link
            link
          else
            "~~#{link}~~ (path not found)"
          end
        end.join ',' if note[:links]
        note  # Ensure we return the note hash, not the links string
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
      tags = tags.split ',' if tags.is_a? String
      notes = recall_notes tags&.join(' '), limit: 8, max_content_length: max_content_length

      # Apply token limit if provided
      unless max_tokens.nil?
        token_count = 0
        included_notes = []

        notes.each do |note|
          note_tokens = tok_len note.to_json
          break if token_count + note_tokens > max_tokens

          included_notes << note
          token_count += note_tokens
        end

        notes = included_notes
      end

      notes
    end


    def record(params, answer)
      puts "[MNEMOSYNE][RECORD]: recording #{tok_len (params.to_json.inspect || '') + (answer || '')}: #{answer}"
      db.execute \
        'INSERT INTO entries (prompt, answer, tags, file, selection) VALUES (?,?,?,?,?)',
        [params[:prompt], answer, Array(params[:tags]).join(','), params[:file],
         params[:attachments].to_json]
    end
   

    # Alias for create_note for backward compatibility
    def self.remember(content:, links: nil, tags: nil)
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
          rows = rows.filter{ |task| params[:parent_task_id] == task[:parent_task_id] }
        end

        max_tokens = 1111
        token_count = 0
        included_rows = []

        rows.each do |row|
          row_tokens = tok_len row.to_json

          if row_tokens > max_tokens
            row[:message] = row[:message].to_s.gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                    '```\\1[CONTENT EXPIRED]```')
            row_tokens = tok_len row.to_json
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
    def search(query, limit: 5)
      db.execute \
        'SELECT prompt, answer FROM entries WHERE tags ' \
        'LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?',
        ["%#{query}%", "%#{query}%", "%#{query}%", limit]
    end


    def tokenize(text)
      return Set.new unless text.is_a? String

      tokens = text.downcase.scan(/\w+/)
      Set.new(tokens) - STOP_WORDS
    end


    def tok_len(s) = @tokenizer.encode(s.to_s).length
  end
end