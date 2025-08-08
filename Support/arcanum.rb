require_relative 'mnemosyne'
require_relative 'argonaut'

# TM_TAB_SIZE 
# TM_SOFT_TABS
# TM_DISPLAYNAME
# TM_INPUT_START_LINE_INDEX
# TM_INPUT_START_COLUMN
# TM_INPUT_START_LINE
# TM_SCOPE
# TM_SELECTED_FILES
# TM_SELECTION"=>"36:20-36:4",
# TM_SELECTED_FILE

 
 
class Arcanum
  MAX_CONTEXT_LINES = 120

  def self.build(params)
    # Inject TextMate environment if provided
    if params['tm_env']
      params['tm_env'].each { |k, v| ENV[k] = v if v }
    end
  
    file = params['file']
    selection = params['selection']

    ctx = {
      history: fetch_history(7),
      project_files: Argonaut.list_project_files,
      file: file,
      selection: selection,
      snippet: snippet_for(file, selection),
      aegis_orientation: Mnemosyne.aegis,
      aegis_notes: Mnemosyne.recall_aegis_notes,
    }

    puts "file=#{file}"
    puts "selection=#{selection}"
    
    # Automatically add attached file to Aegis state    
    if file
      ctx[:aegis_orientation] ||= {}
      ctx[:aegis_orientation][:files] ||= []
      ctx[:aegis_orientation][:files] << file unless ctx[:aegis_orientation][:files].include?(file)

      if selection
        ctx[:aegis_orientation][:selections] ||= []
        ctx[:aegis_orientation][:selections] << { path: file, range: selection, content: nil }
      end
    end

    ctx
  end
  

  def self.fetch_history(limit)
    Mnemosyne.db.execute(
      'SELECT prompt, answer FROM entries ORDER BY id DESC LIMIT ?', [limit]
    ).reverse
  end
  

  def self.snippet_for(file, selection)
    return nil unless file && selection
    start_line, end_line = selection.split(':').map(&:to_i)
    content = Argonaut.read(file).lines
    first = [start_line - 20, 0].max
    last  = [end_line + 20, content.length - 1].min
    content[first..last].join
  rescue
    nil
  end
end
