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
  AEGIS_ID = 1


  @aegis = nil
  
  
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
      migrate db
      restore_aegis db
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
    db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS aegis_state (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tags TEXT,
        context_length INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    SQL
  end


  # Search notes with scoring based on content, tags, and links
  def self.recall_notes(query, limit: 5)
    puts "SEARCH NOTES #{query}"
    query_tokens = tokenize query
    
    sql_query = if query_tokens.empty?
      ''
    else
      'WHERE ' + (%w(content tags links).map{ |field| 
        query_tokens.map{ |keyword| "#{field} LIKE '%#{keyword}%'" }.join ' OR ' 
      }.join ' OR ')
    end
    
    notes = db.execute(
      "SELECT id, content, tags, links FROM project_notes #{sql_query}"
    )
    puts "notes=#{notes}"

    notes.map do |note|
      note.transform_keys! &:to_sym
      score = 0
      
      if query_tokens.empty?
        score = 1
      else
        score += 3 * (query_tokens & tokenize(note[:content])).size
        score += 2 * (query_tokens & tokenize(note[:tags])).size
        score += 1 * (query_tokens & tokenize(note[:links])).size
      end
      
      { **note, score: score }
    end
      .select { |note| note[:score] > 0 }
      .sort_by { |note| -note[:score] }
      .take(limit)
  end
  
  
  def self.save_aegis_state(tags:, context_length:)
    tags_json = tags.join ','
    db.execute(
      'INSERT OR REPLACE INTO aegis_state (id, tags, context_length) VALUES (?, ?, ?)',
      [AEGIS_ID, tags_json, context_length]
    )
  end


  def self.restore_aegis(db)
    aegis = db.execute('SELECT tags, context_length FROM aegis_state ' +
      'WHERE id = ? ORDER BY created_at DESC LIMIT 1', [AEGIS_ID])&.first

    @aegis = if aegis.nil? || aegis.empty? then { tags: [], context_length: 20 }  
             else aegis.transform_keys(&:to_sym) end
  end
  
  
  def self.unveil_aegis(**aegis)
    @aegis = aegis
    save_aegis_state **aegis
    
    recall_aegis_notes
  end
  
  
  def self.recall_aegis_notes
    puts "recall_aegis_notes #{@aegis.inspect}"
    tags = @aegis[:tags]
    tags = tags.split ',' if tags.is_a? String
    recall_notes tags.join(' '), limit: @aegis[:context_length]
  end

  
  def self.aegis
    @aegis
  end
  

  def self.record(params, answer)
    db.execute(
      'INSERT INTO entries (prompt, answer, tags, file, selection) VALUES (?,?,?,?,?)',
      [params['prompt'], answer, Array(params['tags']).join(','), params['file'], 
        params['selection']]
    )
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
    
    puts "SELECT * FROM project_notes WHERE #{(["links LIKE ?"] * links.count).join ' OR '}"
    
    puts links.map { |link| "%#{link}%" }
    db.execute("SELECT * FROM project_notes WHERE #{(["links LIKE ?"] * links.count).join ' OR '}", 
      links.map { |link| "%#{link}%" }).each {|note| note.transform_keys!(&:to_sym)}
  end


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
      db.execute('INSERT INTO tasks (title, payload, status) VALUES (?,?,?)', 
        [params['title'], params['payload'].to_json, 'open'])
      { ok: true }
    when 'update'
      db.execute('UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', 
        [params['status'], params['id']])
      { ok: true }
    else # list
      rows = db.execute('SELECT * FROM tasks ORDER BY created_at DESC')
      rows.map { |r| r }
    end
  end
  
  
  # Recall entries by tags or prompt
  def self.search(query, limit: 5)
    db.execute(
      'SELECT prompt, answer FROM entries WHERE tags ' +
      'LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?', 
      ["%#{query}%", "%#{query}%", "%#{query}%", limit]
    )
  end
  
  
  private
  
  
  def self.tokenize(text)
    return Set.new unless text.is_a?(String)
    tokens = text.downcase.scan(/\w+/)
    Set.new(tokens) - STOP_WORDS
  end
end
