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

 
 
module Arcanum
  # Aegis state variable to store active tags and context length
  MAX_CONTEXT_LINES = 120
  MAX_HIST_TOKENS = 1200
  MAX_SUMMARY_TOKENS = 300
  
  @tokenizer = Tiktoken.encoding_for_model 'gpt-4'
  
  
  def self.build(params)
    # Inject TextMate environment if provided
    if params['tm_env']
      params['tm_env'].each { |k, v| ENV[k] = v if v }
    end

    # Update Aegis summary dynamically
    # Mnemosyne.update_aegis_summary("Context updated for #{params['file']}") if params['file']
  
    file = params['file']
    selection = params['selection']
    puts "SELECTION=#{selection} FILE=#{file}"
    project_files = Argonaut.list_project_files
    puts "project_files TOKEN LENGTH=#{tok_len project_files.inspect}"
    history = fetch_history(7)
    puts "history TOKEN LENGTH=#{tok_len history.inspect}"
    aegis_notes = Mnemosyne.recall_aegis_notes
    puts "aegis_notes TOKEN LENGTH=#{tok_len aegis_notes.inspect}"
    
    aegis_summary = Mnemosyne.fetch_aegis_summaries(before: history.last[:created_at], max_summary_tokens: MAX_SUMMARY_TOKENS)
    puts "aegis_summary TOKEN LENGTH=#{tok_len aegis_summary.inspect}"

    # Pack history without summaries to respect token limits
    packed_history = pack_context!(
      messages: history.map { |h| [{ role: "user", content: h[:prompt], ts: h[:created_at] },
                                   { role: "system", content: h[:answer], ts: h[:created_at] }]
                                 }.flatten,
      max_hist_tokens: MAX_HIST_TOKENS,
      max_summary_tokens: 0
    )
    puts "packed_history=#{packed_history[:recent].count} TOKEN LENGTH=#{tok_len packed_history.inspect}"

    # Pack notes without summaries to respect token limits
    packed_notes = pack_context!(
      messages: aegis_notes.map { |n| { role: "system", content: n[:content], ts: n[:created_at] } },
      max_hist_tokens: MAX_HIST_TOKENS,
      max_summary_tokens: 0
    )
    puts "packed_notes=#{packed_notes[:recent].count} TOKEN LENGTH=#{tok_len packed_notes.inspect},"

    ctx = {
      history: packed_history[:recent],
      extraContext: {
        project_files:,
        file:,
        selection:,
        snippet: snippet_for(file, selection),
        aegis_orientation: {
          **Mnemosyne.aegis,
          aegis_summary: aegis_summary
        },
        aegis_notes: packed_notes[:recent]
      }
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
      'SELECT prompt, answer, created_at FROM entries ORDER BY id DESC LIMIT ?', [limit]
    ).reverse.map{ |el| el.transform_keys!(&:to_sym) }
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
      puts "#{m.inspect}"
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