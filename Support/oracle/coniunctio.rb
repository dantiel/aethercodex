# frozen_string_literal: true

require 'tiktoken_ruby'
require_relative '../mnemosyne/mnemosyne'
require_relative '../instrumentarium/metaprogramming_utils'
require_relative '../instrumentarium/prima_materia'
require_relative '../argonaut/argonaut'
using TokenExtensions

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

      # Handle both single file/selection and multiple attachments
      attachments = params[:attachments] || []

      # For backward compatibility, support old single file/selection format
      if attachments.empty? && (params[:file] || params[:selection])
        attachments = [{
          file:            params[:file],
          selection:       params[:selection],
          line:            params[:line],
          column:          params[:column],
          selection_range: params[:selection_range]
        }]
      end

      puts "[CONIUNCTIO] ATTACHMENTS=#{attachments}"

      project_files = Argonaut.list_project_files
      puts "[CONIUNCTIO] PROJECT_FILES=#{project_files}"

      # Handle history parameter: nil/true = fetch general history, false/[] = no history, array = use provided history
      history = case params[:history]
                when nil, true
                  # Fetch general chat history
                  fetch_and_format_history
                when false, []
                  # No history requested
                  []
                else
                  # Use provided history array
                  params[:history].reverse
                  .flat_map.with_index(&method(:format_history_entry)).reverse
                end

      aegis_notes = Mnemosyne.recall_aegis_notes max_tokens: 500

      ctx = { history:       prepend_summaries(history),
              extra_context: build_extra_context(attachments, project_files, aegis_notes,
                                                 params[:context]) }

      # Update aegis orientation with first attachment if available
      first_attachment = attachments.first
      update_aegis_orientation ctx, first_attachment&.[](:file), first_attachment&.[](:selection)
      ctx
    end


    private


    def inject_tm_env(tm_env)
      tm_env.each { |k, v| ENV[k] = v unless v.nil? }
    end


    def fetch_and_format_history
      # Fetch general chat history with tool calls included
      Mnemosyne.fetch_history(limit: 7, max_tokens: 2200,
                              include_tool_calls: true)
                              .reverse.flat_map.with_index(&method(:format_history_entry)).reverse
    end


    def format_history_entry(entry, index)
      puts "format_history_entry index=#{index}; entry=#{entry.to_s.truncate 50}"
      user_message = { role: 'user', content: entry[:prompt], ts: entry[:created_at] }
      assistant_message = { role: 'assistant', content: entry[:answer], ts: entry[:created_at] }

      # Include tool calls if present with content field integration
      if entry[:tool_calls]&.present?
        tool_calls = Mnemosyne.format_history_tool_calls entry[:tool_calls], index

        assistant_message[:content] = [tool_calls, assistant_message[:content]].join "\n\n"
      end

      [user_message, assistant_message]
    end


    def prepend_summaries(history)
      return history if history.empty?

      summaries = Mnemosyne.fetch_aegis_summaries \
        before: history.last[:ts],
        max_tokens: MAX_SUMMARY_TOKENS

      summaries.map(&method(:format_summary_entry)) + history
    end


    def format_summary_entry(summary)
      {
        role:    'assistant',
        content: "Summary: #{summary[:summary]}\n\nTags: #{summary[:tags]}"
      }
    end


    def build_extra_context(attachments, project_files, aegis_notes, context = nil)
      hermetic_manifest = read_hermetic_manifest

      # For backward compatibility, include first attachment as primary file/selection
      first_attachment = attachments.first || {}

      { project_files:,
        attachments:,
        aegis_orientation: { **Mnemosyne.aegis },
        aegis_notes:,
        messages:          context&.dig(:messages),
        tool_context:      context,
        hermetic_manifest: }
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


    def hermetic_manifest_message(manifest)
      'HERMETIC MANIFEST (Optional project guidance mutable by user and oracle) ' \
        "hermetic.manifest.md:\n#{manifest}"
    end


    def read_hermetic_manifest
      hermetic_manifest = Argonaut.read 'hermetic.manifest.md'
      message = hermetic_manifest[:content] || 'Hermetic manifest file not found'

      puts "[ORACLE][CONIUNCTIO]: #{'NO ' unless hermetic_manifest} Manifest file found."

      { role: :system, content: hermetic_manifest_message(message) }
    rescue StandardError => e
      { role:    :system,
        content: hermetic_manifest_message("Error reading hermetic manifest: #{e.message}") }
    end
  end
end
