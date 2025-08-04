require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'set'



class Mnemosyne
  DB_VERSION = 1
  STOP_WORDS = Set.new(%w[
    the a an and of in to with on for is are am be was were it this that
    at by from as if or but so not into out about then
  ])
  
  
  def self.tokenize(text)
    return Set.new unless text.is_a?(String)
    tokens = text.downcase.scan(/\w+/)
    Set.new(tokens) - STOP_WORDS
  end
  

  def self.db_path
    cfg_path = File.expand_path('../.aethercodex', __FILE__)
    cfg = File.exist?(cfg_path) ? YAML.load_file(cfg_path) : {}
    path = cfg['memory-db'] || '.tm-ai/memory.db'
    project_root = ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd
    if ENV['TM_DEBUG_PATHS']
      puts "cfg_path=#{cfg_path}"
      puts "path=#{path}"
      puts "project_root=#{project_root}"
    end
    File.join(project_root, path)
  end
  

  def self.db
    @db ||= begin
      FileUtils.mkdir_p(File.dirname(db_path))
      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true
      migrate(db)
      db
    end
  
  end

  # Search notes with scoring based on content, tags, and links
  def self.search_notes(query, limit: 5)
    puts "SEARCH NOTES #{query}"
    query_tokens = tokenize query
    
    notes = db.execute(
      'SELECT id, content, tags, links FROM project_notes'
    )

    notes.map do |note|
      score = 0
      
      if query_tokens.empty?
        score = 1
      else
        content_tokens = tokenize note['content']
        score += 3 * (query_tokens & content_tokens).size
        content_tokens = tokenize note['tags']
        score += 2 * (query_tokens & content_tokens).size
        content_tokens = tokenize note['links']
        score += 1 * (query_tokens & content_tokens).size
      end
      # score += 3 if note['content']&.include?(query)
      # score += 2 if note['tags']&.include?(query)
      # score += 1 if note['links']&.include?(query)
      { **note, score: score }
    end
      .select { |note| note[:score] > 0 }
      .sort_by { |note| -note[:score] }
      .take(limit)
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
        payload TEXT,
        status TEXT,
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
  end
  

  # Store Q/A
  def self.record(params, answer)
    puts "record #{[params['prompt'], answer, Array(params['tags']).join(','), params['file'], params['selection']].inspect}"
    db.execute(
      'INSERT INTO entries (prompt, answer, tags, file, selection) VALUES (?,?,?,?,?)',
      [params['prompt'], answer, Array(params['tags']).join(','), params['file'], params['selection']]
    )
    puts "record DONE"
  end
  

  # Create a note (id auto-generated, links optional)
  def self.create_note(content:, links: nil, tags: nil)
    db.execute '''
      INSERT INTO project_notes (content, links, tags, created_at) 
      VALUES (?, ?, ?, CURRENT_TIMESTAMP)''',
      [content, links&.join(','), tags&.join(',')]
    db.last_insert_row_id
  end


  # Fetch notes by links (for Argonaut file overview)
  def self.fetch_notes_by_links(links)
    links = [links] unless links.is_a? Array
    
    puts "SELECT * FROM project_notes WHERE #{(["links LIKE ?"] * links.count).join 'OR'}"
    
    puts  ["#{links}"] * links.count
    db.execute("SELECT * FROM project_notes WHERE #{(["links LIKE ?"] * links.count).join 'OR'}", 
      (["%#{links}%"] * links.count))
  end


  # Update note by id
  def self.update_note(id, content: nil, links: nil, tags: nil) 
    # TODO change created_at to updated_at
    db.execute('UPDATE project_notes SET content = ?, links = ?, tags = ?, created_at = CURRENT_TIMESTAMP WHERE id = ?', [content, links&.join(','), tags&.join(','), id])
  end


  # Remove note by id
  def self.remove_note(id)
    db.execute('DELETE FROM project_notes WHERE id = ?', [id])
  end


  # Simple task ledger
  def self.manage_tasks(params)
    action = params['action'] || 'list'
    case action
    when 'create'
      db.execute('INSERT INTO tasks (title, payload, status) VALUES (?,?,?)', [params['title'], params['payload'].to_json, 'open'])
      { ok: true }
    when 'update'
      db.execute('UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [params['status'], params['id']])
      { ok: true }
    else # list
      rows = db.execute('SELECT * FROM tasks ORDER BY created_at DESC')
      rows.map { |r| r }
    end
  end
  
  
  # Recall entries by tags or prompt
  def self.search(query, limit: 5)
    db.execute(
      'SELECT prompt, answer FROM entries WHERE tags LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?', 
      ["%#{query}%", "%#{query}%", "%#{query}%", limit]
    )
  end
end