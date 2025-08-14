require "sqlite3"
require "fileutils"
require "yaml"
require "set"
require "json"
require "tiktoken_ruby"
require "timeout"

class Mnemosyne
  @tokenizer = Tiktoken.encoding_for_model "gpt-4"

  DB_VERSION = 1
  STOP_WORDS = Set.new %w[
                         the a an and of in to with on for is are am be was were it this that
                         at by from as if or but so not into out about then
                       ]

  @aegis = { tags: [], context_length: 20, summary: "", temperature: 1.0 }

  # Create a new task with a plan and max steps
  def self.create_task(plan:, max_steps:)
    db.execute "INSERT INTO tasks (plan, max_steps, status) VALUES (?, ?, ?)",
               [plan, max_steps, "pending"]
    { ok: true, id: db.last_insert_row_id }
  end

  # Update the Aegis summary dynamically
  def self.update_aegis_summary(summary)
    @aegis[:summary] = summary
    save_aegis_state(**@aegis)
  end

  # Dynamically adjust the Aegis temperature
  def self.set_aegis_temperature(temperature)
    @aegis[:temperature] = temperature
    save_aegis_state(**@aegis)
  end

  def self.fetch_history(limit)
    Mnemosyne.db.execute(
      "SELECT prompt, answer, created_at FROM entries ORDER BY id DESC LIMIT ?", [limit]
    ).reverse.map { |el| el.transform_keys!(&:to_sym) }
  end

  def self.fetch_aegis_summaries(before:, max_summary_tokens:)
    summaries = Mnemosyne.db.execute(%(
      SELECT summary, tags, created_at FROM aegis_state
      WHERE created_at <= ? ORDER BY created_at DESC
      ), [before]).map { |el| el.transform_keys!(&:to_sym) }

    tokens = 0
    packed_summaries = []

    summaries.each do |summary|
      summary_tokens = tok_len summary
      break unless tokens + summary_tokens <= max_summary_tokens

      packed_summaries << summary
      tokens += summary_tokens
    end

    packed_summaries
  end

  # Retrieve a task by ID
  def self.get_task(task_id)
    db.execute("SELECT * FROM tasks WHERE id = ?", [task_id]).first&.transform_keys(&:to_sym)
  end

  # TODO: missing update_task?
  # Update task progress
  def self.update_task_progress(task_id, progress)
    db.execute "UPDATE tasks SET progress = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
               [progress, task_id]
    { ok: true }
  end

  def self.db_path
    cfg_path = File.expand_path ".aethercodex", __dir__
    cfg = File.exist?(cfg_path) ? YAML.load_file(cfg_path) : {}
    path = cfg["memory-db"] || ".tm-ai/memory.db"
    project_root = ENV["TM_PROJECT_DIRECTORY"] || Dir.pwd
    if ENV["TM_DEBUG_PATHS"]
      puts "cfg_path=#{cfg_path}"
      puts "path=#{path}"
      puts "project_root=#{project_root}"
    end
    File.join project_root, path
  end

  def self.db
    @db ||= begin
        FileUtils.mkdir_p File.dirname(db_path)
        db = SQLite3::Database.new db_path
        db.results_as_hash = true
        migrate db
        restore_aegis db
        puts "restore_aegis=#{@aegis}"
        db
      end
  end

  def self.migrate(db)
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
                   status TEXT,
                   progress INTEGER DEFAULT 0,
                   max_steps INTEGER DEFAULT 10,
                   current_step INTEGER DEFAULT 0,
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
                   context_length INTEGER,
                   summary TEXT,
                   temperature REAL,
                   created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                 );
               SQL
  end

  # Search notes with scoring based on content, tags, and links
  def self.recall_notes(query, limit: 5)
    query_tokens = tokenize query

    sql_query = if query_tokens.empty?
        ""
      else
        "WHERE " + (%w[content tags links].map do |field|
          query_tokens.map { |keyword| "#{field} LIKE '%#{keyword}%'" }.join " OR "
        end.join " OR ")
      end

    notes = db.execute \
      "SELECT id, content, tags, links, created_at FROM project_notes #{sql_query}"

    notes.map do |note|
      note.transform_keys!(&:to_sym)
      score = 0

      if query_tokens.empty?
        score = 1
      else
        score += 3 * (query_tokens & tokenize(note[:content])).size
        score += 2 * (query_tokens & tokenize(note[:tags])).size
        score += 1 * (query_tokens & tokenize(note[:links])).size
      end

      { **note, score: }
    end
      .select { |note| note[:score] > 0 }
      .sort_by { |note| -note[:score] }
      .take(limit)
  end

  # Recall Aegis notes with token and date filtering
  def self.recall_aegis_notes(max_summary_tokens:, since:)
    # Get all notes (we'll filter in Ruby)
    all_notes = recall_notes "", limit: 1000

    # Filter by date if provided
    filtered_notes = if since
        since_time = Time.parse since
        all_notes.select { |note| Time.parse(note[:created_at]) >= since_time }
      else
        all_notes
      end

    # Sort by date descending (newest first)
    sorted_notes = filtered_notes.sort_by { |note| Time.parse(note[:created_at]) }.reverse

    # Select notes until token limit is reached
    selected_notes = []
    current_tokens = 0

    sorted_notes.each do |note|
      note_tokens = note[:content].split.size
      break if current_tokens + note_tokens > max_summary_tokens

      selected_notes << note
      current_tokens += note_tokens
    end

    # Return concatenated content
    selected_notes.map { |n| n[:content] }.join("\n\n")
  end

  def self.save_aegis_state(tags: [], context_length: 10, summary: nil, temperature: 1.0)
    tags = Array tags
    tags_json = tags.join ","
    db.execute \
      "INSERT INTO aegis_state " +
      "(tags, context_length, summary, temperature, created_at) VALUES " +
      "(?, ?, ?, ?, CURRENT_TIMESTAMP)",
      [tags_json, context_length, summary, temperature]
  end

  def self.load_aegis(db: nil, limit: 3)
    db ||= @db
    db.execute "SELECT tags, summary, temperature, context_length FROM aegis_state " +
               "ORDER BY created_at DESC LIMIT ?", [limit]
  end

  def self.restore_aegis(db = nil)
    db ||= @db
    aegis = (load_aegis db:, limit: 1)&.first
    @aegis = if aegis.nil? || aegis.empty?
        { tags: [], context_length: 20, summary: "", temperature: 1.0 }
      else
        aegis.transform_keys!(&:to_sym)
      end
  end

  def self.unveil_aegis(**aegis)
    aegis[:tags] ||= []
    @aegis = aegis
    save_aegis_state(**aegis)

    recall_aegis_notes
  end

  def self.recall_aegis_notes(max_summary_tokens: nil, since: nil)
    tags = @aegis[:tags] || []
    tags = tags.split "," if tags.is_a? String
    notes = recall_notes tags.join(" "), limit: @aegis[:context_length] || 10

    # Filter by date if provided
    notes = notes.select { |note| since.nil? || Time.parse(note[:created_at]) >= since } if since

    # Apply token limit if provided
    if max_summary_tokens
      encoder = Tiktoken.encoding_for_model "gpt-4"
      token_count = 0
      summary_notes = []

      notes.each do |note|
        note_tokens = encoder.encode(note[:content]).size
        break if token_count + note_tokens > max_summary_tokens

        summary_notes << note
        token_count += note_tokens
      end

      notes = summary_notes
    end

    notes
  end

  class << self
    attr_reader :aegis
  end

  def self.record(params, answer)
    db.execute \
      "INSERT INTO entries (prompt, answer, tags, file, selection) VALUES (?,?,?,?,?)",
      [params["prompt"], answer, Array(params["tags"]).join(","), params["file"],
       params["selection"]]
  end

  # Create a note (id auto-generated, links optional)
  def self.create_note(content:, links: nil, tags: nil)
    db.execute "
      INSERT INTO project_notes (content, links, tags, created_at)
      VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
               [content, links&.join(","), tags&.join(",")]
    db.last_insert_row_id
  end

  # Fetch notes by links (for Argonaut file overview)
  def self.fetch_notes_by_links(links)
    links = [links] unless links.is_a? Array

    db.execute("SELECT * FROM project_notes WHERE #{(["links LIKE ?"] * links.count).join " OR "}",
               links.map { |link| "%#{link}%" }).each { |note| note.transform_keys!(&:to_sym) }
  end

  def self.update_note(id, content: nil, links: nil, tags: nil)
    # TODO: change created_at to updated_at
    db.execute \
      "UPDATE project_notes SET content = ?, links = ?, tags = ?, created_at = CURRENT_TIMESTAMP WHERE id = ?", [
        content, links&.join(","), tags&.join(","), id,
      ]
  end

  # Remove note by id
  def self.remove_note(id)
    db.execute "DELETE FROM project_notes WHERE id = ?", [id]
  end

  # Task ledger with states, progress, and dynamic plan updates
  def self.manage_tasks(params)
    params.transform_keys!(&:to_sym)
    action = params[:action] || "list"
    case action
    when "create"
      db.execute("INSERT INTO tasks (title, plan, updates, status, progress, max_steps, current_step) VALUES (?,?,?,?,?,?,?)",
                 [params[:title], params[:plan].to_json, "[]", "pending", 0,
                  params[:max_steps] || 10, 0])
      { ok: true, id: db.last_insert_row_id }
    when "update"
      db.execute "UPDATE tasks SET status = ?, progress = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                 [params[:status], params[:progress], params[:id]]
      { ok: true }
    when "activate"
      db.execute "UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                 ["active", params[:id]]
      { ok: true }
    when "update_plan"
      updates = JSON.parse(db.execute("SELECT updates FROM tasks WHERE id = ?",
                                      [params[:id]]).first["updates"]) || []
      updates << { step: params[:current_step], plan: params[:plan], timestamp: Time.now.to_s }
      db.execute "UPDATE tasks SET plan = ?, updates = ?, current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                 [params[:plan].to_json, updates.to_json, params[:current_step], params[:id]]
      { ok: true }
    when "advance_step"
      db.execute "UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                 [params[:current_step], params[:id]]
      { ok: true }
    else # list
      rows = db.execute "SELECT * FROM tasks ORDER BY created_at DESC"
      rows.map { |r| r.transform_keys(&:to_sym) }
    end
  end

  # Recall entries by tags or prompt
  def self.search(query, limit: 5)
    db.execute \
      "SELECT prompt, answer FROM entries WHERE tags " +
      "LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?",
      ["%#{query}%", "%#{query}%", "%#{query}%", limit]
  end

  def self.tokenize(text)
    return Set.new unless text.is_a? String

    tokens = text.downcase.scan(/\w+/)
    Set.new(tokens) - STOP_WORDS
  end

  def self.tok_len(s) = @tokenizer.encode(s.to_s).length
end
