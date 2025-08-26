# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'set'
require 'json'
require 'tiktoken_ruby'
require 'timeout'



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
      if content.include?('```')
        # For code blocks, truncate the content but preserve the structure
        content.gsub(/```(\w*)\n.*?\n```/m) do |match|
          lang = $1
          inner_content = match[lang.length + 4..-4]
          if inner_content.length > max_length / 2
            "```#{lang}\n#{inner_content[0...(max_length / 2)]}...\n```"
          else
            match
          end
        end
      else
        content[0...max_length] + "..."
      end
    end

    # Create a new task with a plan
    def create_task(title:, plan:)
      puts "CREATE TASK #{title}:#{plan}"
      x = db.execute 'INSERT INTO tasks (title, plan, status) VALUES (?, ?, ?)',
                     [title, plan, 'pending']
      puts "x=#{x}, id=#{db.last_insert_row_id}"
      { ok: true, id: db.last_insert_row_id }
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
      cfg_path = File.expand_path '.aethercodex', __dir__
      cfg = File.exist?(cfg_path) ? YAML.load_file(cfg_path) : {}
      path = cfg['memory-db'] || '.tm-ai/memory.db'
      project_root = ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd

      if ENV['TM_DEBUG_PATHS']
        puts "cfg_path=#{cfg_path}"
        puts "path=#{path}"
        puts "project_root=#{project_root}"
      end

      File.join project_root, path
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
                      query_tokens.map { |keyword| "#{field} LIKE '%#{keyword}%'" }.join ' OR '
                    end.join ' OR ')
                  end

      notes = db.execute \
        "SELECT id, content, tags, links, created_at FROM project_notes #{sql_query}"

      notes.map do |note|
        note.transform_keys!(&:to_sym)
        
        # Apply content length limit if specified
        if max_content_length && note[:content] && note[:content].length > max_content_length
          note[:content] = truncate_note_content(note[:content], max_length: max_content_length)
        end
        
        score = 0

        if query_tokens.empty?
          score = 1
        else
          # Enhanced scoring with path matching for better file relevance
          score += 4 * (query_tokens & tokenize(note[:content])).size
          score += 3 * (query_tokens & tokenize(note[:tags])).size
          score += 2 * (query_tokens & tokenize(note[:links])).size
          
          # Boost score for exact path matches in links
          if note[:links] && query_tokens.any? { |token| note[:links].include?(token) }
            score += 5
          end
        end

        { **note, score: }
      end
        .select { |note| note[:score].positive? }
           .sort_by { |note| -note[:score] }
           .take(limit)
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
      notes = recall_notes tags.join(' '), limit: 8, max_content_length: max_content_length

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
      puts "[MNEMOSYNE][RECORD]: recording #{tok_len (params.to_json.inspect || '') + (answer || '')}"
      db.execute \
        'INSERT INTO entries (prompt, answer, tags, file, selection) VALUES (?,?,?,?,?)',
        [params[:prompt], answer, Array(params[:tags]).join(','), params[:file],
         params[:selection]]
    end


    # Create a note (id auto-generated, links optional) with content length limit
    def create_note(content:, links: nil, tags: nil)
      truncated_content = truncate_note_content(content)
      db.execute "
        INSERT INTO project_notes (content, links, tags, created_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                 [truncated_content, links&.join(','), tags&.join(',')]
      db.last_insert_row_id
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
      # TODO: change created_at to updated_at
      truncated_content = truncate_note_content(content) if content
      db.execute \
        'UPDATE project_notes SET content = ?, links = ?, tags = ?, created_at = CURRENT_TIMESTAMP WHERE id = ?', [
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
      action = params[:action] || 'list'
      case action
      when 'create'
        begin
          x = db.execute 'INSERT INTO tasks (title, plan, updates, status, current_step) VALUES (?,?,?,?,?)',
                         [params[:title], params[:plan].to_json, '[]', 'pending', 0]
          { 'ok' => true,
            'id' => db.last_insert_row_id,
            title: params[:title],
            plan: params[:plan] }
        rescue SQLite3::Exception => e
          warn "Task creation failed: #{e.message}"
          { 'ok' => false, 'error' => e.message }
        end
      when 'update'
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
        elsif params[:step_results]
          # Update step results
          db.execute 'UPDATE tasks SET step_results = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [params[:step_results], params[:id]]
        else
          db.execute 'UPDATE tasks SET status = ?, current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                     [params[:status], params[:current_step], params[:id]]
        end
        { ok: true }
      when 'activate'
        db.execute 'UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   ['active', params[:id]]
        { ok: true }
      when 'update_plan'
        updates = JSON.parse(db.execute('SELECT updates FROM tasks WHERE id = ?',
                                        [params[:id]]).first['updates']) || []
        updates << { step: params[:current_step], plan: params[:plan], timestamp: Time.now.to_s }
        db.execute 'UPDATE tasks SET plan = ?, updates = ?, current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   [params[:plan].to_json, updates.to_json, params[:current_step], params[:id]]
        { ok: true }
      when 'advance_step'
        db.execute 'UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                   [params[:current_step], params[:id]]
        { ok: true }
      when 'delete'
        db.execute 'DELETE FROM tasks WHERE id = ?', [params[:id]]
        { ok: true }
      else # list
        rows = db.execute 'SELECT * FROM tasks ORDER BY created_at DESC'
        rows.map { |r| r.transform_keys!(&:to_sym) }

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
        puts "ROWS=#{rows}"
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