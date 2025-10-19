# frozen_string_literal: true

require_relative 'oracle'



# Continuum Weaver - Hermetic Code Completion System
# Weaves the fabric of code continuum through revelation and inscription
# Provides context-aware code generation without tool access
class ContinuumWeaver
  class << self
    # Generate FIM completion for given context
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
      if result.is_a?(String) && result.include?('"content"=>')
        # Parse JSON response to extract content
        content_match = result.match(/"content"=>"([^"]+)"/)
        content_match ? content_match[1] : result
      else
        result
      end
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
  end
end