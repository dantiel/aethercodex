require 'sqlite3'
require 'fileutils'
require 'yaml'

class Mnemosyne
  DB_VERSION = 1


  def self.db_path
    cfg_path = File.expand_path('../.deepseekrc', __FILE__)
    cfg = File.exist?(cfg_path) ? YAML.load_file(cfg_path) : {}
    path = cfg['memory_db'] || '.tm-ai/memory.db'
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
  def self.create_note(content, links: nil, tags: nil)
    db.execute(
      'INSERT INTO project_notes (content, links, tags) VALUES (?, ?, ?)',
      [content, links&.join(','), tags&.join(',')]
    )
    db.last_insert_row_id
  end


  # Fetch notes by links (for Argonaut file overview)
  def self.fetch_notes_by_links(links)
    links = Array(links).join(',')
    db.execute('SELECT * FROM project_notes WHERE links LIKE ?', ["%#{links}%"])
  end


  # Update note by id
  def self.update_note(id, content: nil, links: nil, tags: nil)
    db.execute('UPDATE project_notes SET content = ?, links = ?, tags = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [content, links&.join(','), tags&.join(','), id])
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