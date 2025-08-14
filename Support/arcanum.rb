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
  MAX_HISTORY_TOKENS = 1200
  MAX_SUMMARY_TOKENS = 400

  @tokenizer = Tiktoken.encoding_for_model 'gpt-4'


  def self.build(params)
    # Inject TextMate environment if provided
    if params['tm_env']
      params['tm_env'].each { |k, v| ENV[k] = v if v }
    end

    file = params['file']
    selection = params['selection']
    puts "SELECTION=#{selection} FILE=#{file}"
    project_files = Argonaut.list_project_files
    puts "project_files TOKEN LENGTH=#{tok_len project_files.to_json}"
    history = Mnemosyne.fetch_history limit: 7, max_tokens: MAX_HISTORY_TOKENS
    puts "history TOKEN LENGTH=#{tok_len history.to_json}"
    aegis_notes = Mnemosyne.recall_aegis_notes max_tokens: 500
    puts "aegis_notes TOKEN LENGTH=#{tok_len aegis_notes.to_json}"

    history_messages = history.map do |h|
      [{ role: 'user', content: h[:prompt], ts: h[:created_at] },
       { role: 'assistant', content: h[:answer], ts: h[:created_at] }]
    end.flatten

    last_history_ts = history.last[:created_at]

    aegis_summaries = Mnemosyne.fetch_aegis_summaries before: last_history_ts,
                                                      max_tokens: MAX_SUMMARY_TOKENS

    # Prepend each summary as a clean system message
    aegis_summaries.each do |summary|
      history_messages.unshift({ role: 'system',
                                 content: "Summary: #{summary[:summary]}\n\nTags: #{summary[:tags]}",
                                 ts: summary[:created_at] })
    end
    puts "PACKED_HISTORY=#{history_messages.to_json}"

    puts "packed_history=#{history_messages.count} TOKEN LENGTH=#{tok_len history_messages.to_json}"

    ctx = {
      history: history_messages,
      extra_context: {
        project_files:,
        file:,
        selection:,
        snippet: snippet_for(file, selection),
        aegis_orientation: {
          **Mnemosyne.aegis
        },
        aegis_notes:
      }
    }

    puts "context TOTAL TOKEN LENGTH=#{tok_len ctx.to_json}"

    puts "file=#{file}"
    puts "selection=#{selection}"

    # Automatically add attached file to Aegis state
    if file
      ctx[:aegis_orientation] ||= {}
      ctx[:aegis_orientation][:files] ||= []
      ctx[:aegis_orientation][:files] << file unless ctx[:aegis_orientation][:files].include? file

      if selection
        ctx[:aegis_orientation][:selections] ||= []
        ctx[:aegis_orientation][:selections] << { path: file, range: selection, content: nil }
      end
    end

    ctx
  end


  def self.snippet_for(file, selection)
    return nil unless file && selection

    start_line, end_line = selection.split(':').map(&:to_i)
    content = Argonaut.read(file).lines
    first = [start_line - 20, 0].max
    last = [end_line + 20, content.length - 1].min
    content[first..last].join
  rescue StandardError
    nil
  end


  def self.tok_len(s) = @tokenizer.encode(s.to_s).length
end
