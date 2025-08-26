# frozen_string_literal: true

require 'tiktoken_ruby'
require_relative 'mnemosyne'
require_relative 'aetherflux'
require_relative 'metaprogramming_utils'
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




# The Coniunctio module orchestrates symbolic computation for the oracle, weaving together:
# - **Contextual Threads**: Dynamic binding of files, selections, and Aegis states.
# - **Token Alchemy**: Encoding/decoding with Tiktoken for precise LLM interactions.
# - **Hermetic Transmutations**: Higher-order transformations of history and summaries.
#
# Its logic mirrors the Emerald Tablet: "As above, so below"—bridging code and the arcane.
module Coniunctio
  # Constants for context and token limits
  MAX_CONTEXT_LINES = 120
  MAX_HISTORY_TOKENS = 2200
  MAX_SUMMARY_TOKENS = 400

  @tokenizer = Tiktoken.encoding_for_model 'gpt-4'


  class << self
    def build(params)
      inject_tm_env params[:tm_env] if params[:tm_env]

      file, selection, context = params.values_at :file, :selection, :context
      puts "TEST#{file}"
      project_files = Argonaut.list_project_files
      puts "PROJECT_FILES#{project_files}"
      history = fetch_and_format_history task_history: params[:history]
      aegis_notes = Mnemosyne.recall_aegis_notes max_tokens: 500

      ctx = { history:       prepend_summaries(history),
              extra_context: build_extra_context(file, selection, project_files, aegis_notes, context) }

      update_aegis_orientation ctx, file, selection
      ctx
    end


    private


    def inject_tm_env(tm_env)
      tm_env.each { |k, v| ENV[k] = v unless v.nil? }
    end


    def fetch_and_format_history(task_history: nil)
      (task_history || Mnemosyne.fetch_history(limit: 7, max_tokens: 2200))
        .flat_map(&method(:format_history_entry))
    end


    def format_history_entry(entry)
      [
        { role: 'user', content: entry[:prompt], ts: entry[:created_at] },
        { role: 'assistant', content: entry[:answer], ts: entry[:created_at] }
      ]
    end


    def prepend_summaries(history)
      summaries = Mnemosyne.fetch_aegis_summaries \
        before: history.last[:ts],
        max_tokens: MAX_SUMMARY_TOKENS

      summaries.map(&method(:format_summary_entry)) + history
    end


    def format_summary_entry(summary)
      {
        role:    'system',
        content: "Summary: #{summary[:summary]}\n\nTags: #{summary[:tags]}",
        ts:      summary[:created_at]
      }
    end


    def build_extra_context(file, selection, project_files, aegis_notes, context = nil)
      hermetic_manifest = read_hermetic_manifest
      
      {
        project_files:,
        file:,
        selection:,
        snippet:           snippet_for(file, selection),
        aegis_orientation: { **Mnemosyne.aegis },
        aegis_notes:,
        tool_context:      context,
        hermetic_manifest: 
      }
    end


    def update_aegis_orientation(ctx, file, selection)
      return unless file

      ctx[:aegis_orientation] ||= {}
      ctx[:aegis_orientation][:files] ||= []
      ctx[:aegis_orientation][:files] << file unless ctx[:aegis_orientation][:files].include? file

      return unless selection

      ctx[:aegis_orientation][:selections] ||= []
      ctx[:aegis_orientation][:selections] << { path: file, range: selection, content: nil }
    end


    def snippet_for(file, selection)
      return unless file && selection

      start_line, end_line = selection.split(':').map(&:to_i)
      content = Argonaut.read(file).lines
      first = [start_line - 20, 0].max
      last = [end_line + 20, content.length - 1].min
      content[first..last].join
    rescue StandardError
      nil
    end


    def read_hermetic_manifest
      hermetic_manifest = Argonaut.read 'hermetic.manifest.md'
      return { content: "Hermetic manifest file not found", present: false } unless hermetic_manifest[:content]
      { content: hermetic_manifest[:content], present: true }
    rescue StandardError => e
      { content: "Error reading hermetic manifest: #{e.message}", present: false }
    end


    def tok_len(str) = @tokenizer.encode(str.to_s).length
  end
end