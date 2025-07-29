require_relative 'mnemosyne'
require_relative 'file_manager'



class ContextBuilder
  MAX_CONTEXT_LINES = 120


  def self.build(params)
    # Inject TextMate environment if provided
    if params['tm_env']
      params['tm_env'].each { |k, v| ENV[k] = v if v }
    end
    
    file = params['file']
    selection = params['selection']
    ctx = {
      history: fetch_history(10),
      project_files: list_project_files,
      file: file,
      selection: selection,
      snippet: snippet_for(file, selection)
    }
    ctx
  end


  def self.fetch_history(limit)
    Mnemosyne.db.execute(
      'SELECT prompt, answer FROM entries ORDER BY id DESC LIMIT ?', [limit]
    ).reverse
  end


  def self.list_project_files  
    FileManager.list_project_files
  end


  def self.snippet_for(file, selection)
    return nil unless file && selection
    start_line, end_line = selection.split(':').map(&:to_i)
    content = FileManager.read(file).lines
    first = [start_line - 20, 0].max
    last  = [end_line + 20, content.length - 1].min
    content[first..last].join
  rescue
    nil
  end
end
