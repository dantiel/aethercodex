require 'tiktoken_ruby'
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
  MAX_HIST_TOKENS = 1200
  MAX_SUMMARY_TOKENS = 300
  
  @tokenizer = Tiktoken.encoding_for_model("gpt-4")
  
  def self.build(params)
    # Inject TextMate environment if provided
    if params['tm_env']
      params['tm_env'].each { |k, v| ENV[k] = v if v }
    end
  
    file = params['file']
    selection = params['selection']
    
    project_files = Argonaut.list_project_files
    puts "project_files TOKEN LENGTH=#{tok_len project_files.inspect}"
    history = fetch_history(7)
    puts "history TOKEN LENGTH=#{tok_len history.inspect}"
    aegis_notes = Mnemosyne.recall_aegis_notes
    puts "aegis_notes TOKEN LENGTH=#{tok_len aegis_notes.inspect}"

    ctx = {
      history:, project_files:, file:, selection:, snippet: snippet_for(file, selection),
      aegis_orientation: Mnemosyne.aegis, aegis_notes:,
    }
    
    puts "context TOTAL TOKEN LENGTH=#{tok_len ctx.inspect}"

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
  
  
  def self.tok_len(s) = @tokenizer.encode(s.to_s).length


  def self.pack_context!(messages:, max_hist_tokens:, max_summary_tokens:)
    # messages: [{role:, content:, ts:}, ...] oldest→newest
    recent = []
    tokens = 0
    messages.reverse_each do |m|
      l = tok_len("#{m[:role]}: #{m[:content]}")
      break if tokens + l > max_hist_tokens
      recent << m
      tokens += l
    end
    recent.reverse!

    older = messages[0...messages.size - recent.size]
    summary_source = older.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
    summary = if summary_source.empty?
                ""
              else
                # call your model once to summarize older history to ≤ max_summary_tokens
                # e.g. summarize(summary_source, max_tokens: max_summary_tokens)
                "[[summary placeholder ≤ #{max_summary_tokens} tokens]]"
              end

    { summary:, recent: recent }
  end
end
