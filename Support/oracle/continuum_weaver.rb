# frozen_string_literal: true

require_relative 'oracle'



# Continuum Weaver - Hermetic Code Completion System
# Weaves the fabric of code continuum through revelation and inscription
# Provides context-aware code generation without tool access
class ContinuumWeaver
  class << self
    # Generate FIM completion for given context (cursor mode)
    def complete(before_context:, after_context:, file_path:, cursor_line:, cursor_column:)
      # Build comprehensive context including file structure and notes
      context = build_completion_context \
        before_context: before_context,
        after_context: after_context,
        file_path: file_path,
        cursor_line: cursor_line,
        cursor_column: cursor_column

      # Use Oracle completion with specialized FIM prompt
      result = Oracle.complete context
      puts "FIM Debug: Oracle result = #{result.inspect}" if defined?(Rails)
      
      # Extract just the completion content from the result
      extract_completion_content(result)
    end

    # Generate refactoring for selected text (selection mode)
    def refactor(before_context:, after_context:, selected_text:, selection_range:, file_path:)
      # Build comprehensive context for refactoring
      context = build_refactoring_context \
        before_context: before_context,
        after_context: after_context,
        selected_text: selected_text,
        selection_range: selection_range,
        file_path: file_path

      # Use Oracle completion with specialized refactoring prompt
      result = Oracle.complete context
      puts "Refactor Debug: Oracle result = #{result.inspect}" if defined?(Rails)
      
      # Extract just the refactoring content from the result
      extract_completion_content(result)
    end


    # Generate proactive suggestions for real-time pair programming
    def self.generate_proactive_suggestion(before_context:, after_context:, cursor_line:, file_path:)
      # Build context for proactive suggestion
      context = build_proactive_context \
        before_context: before_context,
        after_context: after_context,
        cursor_line: cursor_line,
        file_path: file_path

      # Use Oracle completion with proactive suggestion prompt
      result = Oracle.complete context
      
      # Extract suggestion content
      extract_completion_content(result)
    end

    private


    # Build completion context with file structure and notes
    def build_completion_context(before_context:,
                                 after_context:,
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
                         file_path:,
                         cursor_line:,
                         cursor_column:)
      <<~PROMPT
        You are a FIM (Fill-In-Middle) completion assistant. Your ONLY task is to generate the code that should appear between the provided context.

        **RULES:**
        - Generate ONLY the code that belongs between the contexts
        - Do NOT include the before or after context in your response
        - Do NOT add explanations, comments about what you're doing, or any extra text
        - Match the style, indentation, and patterns of the surrounding code
        - Generate clean, idiomatic code that fits naturally

        **CONTEXT:**
        File: #{file_path}
        Position: Line #{cursor_line}, Column #{cursor_column}

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
        Generate ONLY the code that should appear between these contexts. Return nothing else.
      PROMPT
    end

    # Build refactoring context with file structure and notes
    def build_refactoring_context(before_context:,
                                  after_context:,
                                  selected_text:,
                                  selection_range:,
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
                                 file_path:)
      <<~PROMPT
        You are a code refactoring assistant. Your task is to replace the selected text with improved, refactored code.

        **RULES:**
        - Replace the selected text with better, cleaner, or more efficient code
        - Maintain the same functionality but improve the implementation
        - Match the style, indentation, and patterns of the surrounding code
        - Do NOT include the before or after context in your response
        - Do NOT add explanations, comments about what you're doing, or any extra text
        - Generate clean, idiomatic code that fits naturally

        **CONTEXT:**
        File: #{file_path}
        Selection Range: #{selection_range}

        **FILE STRUCTURE:**
        #{file_structure}

        **RELEVANT NOTES:**
        #{relevant_notes}

        **BEFORE SELECTION:**
        ```
        #{before_context}
        ```

        **SELECTED TEXT (to be replaced):**
        ```
        #{selected_text}
        ```

        **AFTER SELECTION:**
        ```
        #{after_context}
        ```

        **YOUR TASK:**
        Generate ONLY the refactored code that should replace the selected text. Return nothing else.
      PROMPT
    end

    # Extract completion content from Oracle response
    def extract_completion_content(result)
      if result.is_a?(String) && result.include?('"content"=>')
        # Parse JSON response to extract content
        content_match = result.match(/"content"=>"([^"]+)"/)
        content_match ? content_match[1] : result
      else
        result
      end
    end

    # Build context for proactive suggestions
    def build_proactive_context(before_context:, after_context:, cursor_line:, file_path:)
      # Get file structure overview
      file_structure = get_file_structure file_path

      # Get relevant notes for context
      relevant_notes = get_relevant_notes file_path

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