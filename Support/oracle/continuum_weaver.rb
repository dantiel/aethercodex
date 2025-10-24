# frozen_string_literal: true

require_relative 'oracle'
# require_relative '../config'
# LOG = File.open CONFIG.log_file_path, 'a'
# LOG.sync = true
# $stdout = $stderr = LOG
require_relative '../instrumentarium/context_extractor'



# Continuum Weaver - Hermetic Code Completion System
# Weaves the fabric of code continuum through revelation and inscription
# Provides context-aware code generation without tool access
class ContinuumWeaver
  class << self
    # Generate FIM completion for given context (cursor mode)
    def complete(before_context:, after_context:, scope:, file_path:, cursor_line:, cursor_column:)
      # Build comprehensive context including file structure and notes
      context = build_completion_context \
        before_context: before_context,
        after_context: after_context,
        scope: scope,
        file_path: file_path,
        cursor_line: cursor_line,
        cursor_column: cursor_column

      # Use Oracle completion with specialized FIM prompt
      result = Oracle.complete context
      puts "FIM Debug: Oracle result = #{result.inspect}" if defined?(Rails)
      
      # Extract just the completion content from the result
      extract_completion extract_response_content(result)
    end

    # Generate refactoring for selected text (selection mode)
    def refactor(before_context:, after_context:, selected_text:, selection_range:, scope:, file_path:)
      # Build comprehensive context for refactoring
      context = build_refactoring_context \
        before_context: before_context,
        after_context: after_context,
        selected_text: selected_text,
        selection_range: selection_range,
        scope: scope,
        file_path: file_path
      
      # Use Oracle completion with specialized refactoring prompt
      result = Oracle.complete context
      puts "Refactor Debug: Oracle result = #{result.inspect}" if defined?(Rails)
      
      # Extract just the refactoring content from the result
      extract_replacement extract_response_content(result)
    end


    # Generate proactive code suggestions based on current context
    def generate_proactive_suggestion(content, cursor_line, file_path, scope)

      # Extract context using unified extractor (cursor_line is 1-based)
      context = ContextExtractor.extract_context_around_cursor(
        content,
        cursor_line.to_i,
        1,  # Default column 1 for proactive suggestions
        max_chars: 2000,
        context_lines: 20
      )
      puts "generate_proactive_suggestion1 #{context.inspect}"
      
      before_context = context[:before]
      after_context  = context[:after]
      
      puts "generate_proactive_suggestion2"
      
      # Build proactive context
      context = build_proactive_context \
        before_context: before_context,
        after_context: after_context,
        cursor_line: cursor_line,
        scope: scope,
        file_path: file_path
      
      puts "generate_proactive_suggestion3"
      
      # Use Oracle for proactive suggestions
      result = Oracle.complete(context)
      
      puts "generate_proactive_suggestion4"
      
      # Extract and return the suggestion
      extract_response_content result

    rescue e
      puts "ERROR: #{e.inspect}"
    end


    private


    # Build completion context with file structure and notes
    def build_completion_context(before_context:,
                                 after_context:,
                                 scope:,
                                 file_path:,
                                 cursor_line:,
                                 cursor_column:)
      # Get file structure overview
      file_structure = get_file_structure file_path

      # Get relevant notes for context
      relevant_notes = get_relevant_notes file_path

      # Build the completion prompt
      {
        snippet: build_fim_prompt(
          before_context: before_context,
          after_context:  after_context,
          file_structure: file_structure,
          relevant_notes: relevant_notes,
          scope: scope,
          file_path: file_path,
          cursor_line: cursor_line,
          cursor_column: cursor_column
        )
      }
    end


    # Get file structure without using tools
    def get_file_structure(file_path)
      return '' unless File.exist? file_path

      # Read file and extract structural elements
      content = File.read file_path

      # Extract class/module definitions, method signatures
      structure = []
      content.lines.each_with_index do |line, index|
        structure << "Line #{index + 1}: #{line.strip}" if line.match?(/^\s*(class|module|def)\s+/)
      end

      structure.join "\n"
    end


    # Get relevant notes without using tools
    def get_relevant_notes(file_path)
      # Use internal Mnemosyne access if available
      if defined?(Mnemosyne)
        notes = Mnemosyne.recall_notes query: file_path, limit: 3
        notes.map { |note| note[:content] }.join("\n")
      else
        ''
      end
    rescue StandardError
      ''
    end


    # Build the FIM completion prompt
    def build_fim_prompt(before_context:,
                         after_context:,
                         file_structure:,
                         relevant_notes:,
                         scope:,
                         file_path:,
                         cursor_line:,
                         cursor_column:)
      <<~PROMPT
      You are a FIM (Fill-In-Middle) completion assistant. Your ONLY task is to generate the code that should appear between the provided context.

      RULES:
      - Generate ONLY the code that belongs between the contexts.
      - Do NOT include the before or after context in your response.
      - Do NOT add explanations, comments, or any extra text.
      - Match the style, indentation, and patterns of the surrounding code.
      - Generate clean, idiomatic code that fits naturally.
      - Leak guard: do not output any entire line that appears in before_context or after_context, and do not output any substring of 12+ consecutive characters from them. Identifiers/literals may be reused when necessary.

      CONTEXT:
      File: #{file_path}
      Position: Line #{cursor_line}, Column #{cursor_column}
      Scope: #{scope}

      FILE STRUCTURE (orientation only; do not copy):
      #{file_structure}

      RELEVANT NOTES (read-only; identifiers here may be reused):
      #{relevant_notes}

      FILE CONTENT (read-only; may include elisions like ⟪…N lines elided…⟫ — do NOT expand or reproduce them):
      `[[CURSOR]]` marks the position where content must be inserted.
      [file part begin]
      #{before_context}[[CURSOR]]#{after_context}
      [file part end]

      OUTPUT:
      <COMPLETION>
      [Only the code to insert at [[CURSOR]]. Nothing else.]
      </COMPLETION>
      PROMPT
    end

    # Build refactoring context with file structure and notes
    def build_refactoring_context(before_context:,
                                  after_context:,
                                  selected_text:,
                                  selection_range:,
                                  scope:,
                                  file_path:)
      # Get file structure overview
      file_structure = get_file_structure file_path

      # Get relevant notes for context
      relevant_notes = get_relevant_notes file_path

      # Build the refactoring prompt
      {
        snippet: build_refactoring_prompt(
          before_context: before_context,
          after_context: after_context,
          selected_text: selected_text,
          selection_range: selection_range,
          file_structure: file_structure,
          relevant_notes: relevant_notes,
          scope: scope,
          file_path: file_path
        )
      }
    end

    # Build the refactoring prompt
    def build_refactoring_prompt(before_context:,
                                 after_context:,
                                 selected_text:,
                                 selection_range:,
                                 file_structure:,
                                 relevant_notes:,
                                 scope:,
                                 file_path:)
      
      <<~PROMPT
      You are a code refactoring assistant. Replace ONLY the selected text with improved code.

      HARD RULES:
      - Edit scope is restricted to the selection. Surrounding code is READ-ONLY.
      - Do not include, duplicate, or modify any content from before_context or after_context.
      - Leak guard: do not output any entire line that appears in before_context or after_context, and do not output any substring of 12+ consecutive characters from them. You may reuse identifiers and literals if needed.
      - Do not add or remove outer scope delimiters that belong outside the selection. No extra or missing def/class/module/function/braces/ends/tags beyond what exists inside the selection.
      - Keep public API stable (names, signatures, return shape, side effects) unless those are wholly defined inside the selection.
      - Match indentation and style implied by the surrounding code and scope.

      CONTEXT (READ-ONLY):
      File: #{file_path}
      Selection Range: #{selection_range}
      Scope: #{scope}

      FILE STRUCTURE (orientation only; do not copy):
      #{file_structure}

      RELEVANT NOTES (read-only; identifiers here may be reused):
      #{relevant_notes}

      CONTENT WINDOW (read-only; may include elisions like ⟪…N lines elided…⟫ — do NOT expand or reproduce them):
      [[SELECTION WINDOW]]
      #{before_context}[[SELECTION BEGIN]]#{selected_text}[[SELECTION END]]#{after_context}
      [[/SELECTION WINDOW]]

      TASK:
      - Produce improved, idiomatic code that drops in exactly where [[SELECTION BEGIN]]..[[SELECTION END]] was.
      - If the selection is a single token (e.g., a name or literal), return a single-token replacement that remains valid in this context.
      - Keep the outer function/class/module untouched if the selection is inside one. No duplicated signatures, no new wrappers.

      STRICT OUTPUT:
      <REPLACEMENT>
      [Only the replacement code goes here. Nothing else.]
      </REPLACEMENT>
      PROMPT
    end

    # Extract completion content from Oracle response
    def extract_response_content result
      if result.is_a?(String) && result.include?('"content"=>')
        # Parse JSON response to extract content
        content_match = result.match(/"content"=>"([^"]+)"/)
        result = content_match ? content_match[1] : result
      end
      
      result
    end


    def extract_replacement raw
      raw[/<REPLACEMENT>\s*\n?(.*)\n?\s*<\/REPLACEMENT>/m, 1] or raw
    end


    def extract_completion raw
      raw[/<COMPLETION>\s*\n?(.*)\n?\s*<\/COMPLETION>/m, 1] or raw
    end


    # Build context for proactive suggestions
    def build_proactive_context(before_context:, after_context:, cursor_line:, scope:, file_path:)
      puts "build_proactive_context1"
      # Get file structure overview
      file_structure = get_file_structure file_path

      # Get relevant notes for context
      relevant_notes = get_relevant_notes file_path
      puts "build_proactive_context2"

      # Build the proactive suggestion prompt
      {
        snippet: build_proactive_prompt(
          before_context: before_context,
          after_context: after_context,
          file_structure: file_structure,
          relevant_notes: relevant_notes,
          file_path: file_path,
          cursor_line: cursor_line
        )
      }
    end

    # Build the proactive suggestion prompt
    def build_proactive_prompt(before_context:, after_context:, file_structure:, relevant_notes:, file_path:, cursor_line:)
      <<~PROMPT
        You are a proactive pair programming assistant. Based on the current code context and cursor position, suggest what the developer might want to write next.

        **RULES:**
        - Suggest 1-2 lines of code that would naturally follow the current context
        - Focus on completing the current thought or pattern
        - Keep suggestions concise and immediately useful
        - Match the style and patterns of the surrounding code

        **CONTEXT:**
        File: #{file_path}
        Cursor Position: Line #{cursor_line}

        **FILE STRUCTURE:**
        #{file_structure}

        **RELEVANT NOTES:**
        #{relevant_notes}

        **BEFORE CURSOR:**
        ```
        #{before_context}
        ```

        **AFTER CURSOR:**
        ```
        #{after_context}
        ```

        **YOUR TASK:**
        Suggest what code should come next at the cursor position. Keep it brief and actionable.
      PROMPT
    end
    

  end
end