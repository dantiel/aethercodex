# frozen_string_literal: true

# A Ruby implementation of the ChrysopoeiaDiffStrategy from TypeScript.
# Provides surgical diff application with fuzzy matching and validation.

module DiffCrepusculum
  BUFFER_LINES = 40 # Number of extra context lines to show before and after matches

  # Calculate similarity between two strings using Levenshtein distance.
  def self.get_similarity(original, search)
    return 0.0 if search.empty?
    
    normalized_original = normalize_string(original)
    normalized_search = normalize_string(search)

    return 1.0 if normalized_original == normalized_search

    dist = levenshtein_distance(normalized_original, normalized_search)
    max_length = [normalized_original.length, normalized_search.length].max
        
    1.0 - dist.to_f / max_length
  end


  # Perform a middle-out search for the most similar slice.
  def self.fuzzy_search(lines, search_chunk, start_index, end_index)
    best_score = 0.0
    best_match_index = -1
    best_match_content = ""
    search_len = search_chunk.split(/\r?\n/).length

    mid_point = ((start_index + end_index) / 2).floor
    left_index = mid_point
    right_index = mid_point + 1

    while left_index >= start_index || right_index <= (end_index - search_len)
      if left_index >= start_index
        original_chunk = lines[left_index, search_len].join "\n"

        similarity = get_similarity original_chunk, search_chunk
        if similarity > best_score
          best_score = similarity
          best_match_index = left_index
          best_match_content = original_chunk
        end
        left_index -= 1
      end

      if right_index <= (end_index - search_len)
        original_chunk = lines[right_index, search_len].join "\n"
        similarity = get_similarity original_chunk, search_chunk
        if similarity > best_score
          best_score = similarity
          best_match_index = right_index
          best_match_content = original_chunk
        end
        right_index += 1
      end
    end

    { best_score: best_score, best_match_index: best_match_index, best_match_content: best_match_content }
  end

  # Levenshtein distance calculation.
  def self.levenshtein_distance(a, b)
    a_len = a.length
    b_len = b.length

    return b_len if a_len.zero?
    return a_len if b_len.zero?

    matrix = Array.new(a_len + 1) { Array.new(b_len + 1, 0) }

    (0..a_len).each { |i| matrix[i][0] = i }
    (0..b_len).each { |j| matrix[0][j] = j }

    (1..a_len).each do |i|
      (1..b_len).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      # Deletion
          matrix[i][j - 1] + 1,      # Insertion
          matrix[i - 1][j - 1] + cost # Substitution
        ].min
      end
    end

    matrix[a_len][b_len]
  end

  # Normalize strings for comparison (e.g., handle smart quotes).
  def self.normalize_string(str)
    str.gsub(/[‘’]/, "'").gsub(/[“”]/, "\"").strip
  end
  
  class STATE
    START = :start
    AFTER_SEARCH = :after_search
    AFTER_SEPARATOR = :after_separator
  end

  # The main diff strategy class.
  class ChrysopoeiaDiff
    attr_reader :fuzzy_threshold, :buffer_lines
    attr_writer :fuzzy_threshold

    SEARCH = '<<<<<<< SEARCH'
    SEP = '======='
    REPLACE = '>>>>>>> REPLACE'


    def initialize(fuzzy_threshold = 1.0, buffer_lines = BUFFER_LINES)
      @fuzzy_threshold = fuzzy_threshold
      @buffer_lines = buffer_lines
    end


    def name
      "MultiSearchReplace"
    end


    # Validate and apply the diff with fuzzy matching and marker sequencing.
    def apply_diff(original_content, diff_content, _param_start_line = nil, _param_end_line = nil)
      # Validate marker sequencing
      valid_seq = validate_marker_sequencing(diff_content)
      return { success: false, error: valid_seq[:error] } unless valid_seq[:success]

      # Split content into lines
      result_lines = original_content.split /\r?\n/
      delta = 0
      diff_results = []
      applied_count = 0

      # Parse and sort replacements
      replacements = parse_replacements diff_content
      replacements.each do |replacement|
        search_content = replacement[:search_content]
        replace_content = replacement[:replace_content]
        
        start_line = (replacement[:start_line] || 0) + delta
        no_position = replacement[:start_line].nil?

        # Unescape markers
        search_content = unescape_markers search_content
        replace_content = unescape_markers replace_content

        # Strip line numbers if present
        if every_line_has_line_numbers?(search_content) &&
           every_line_has_line_numbers?(replace_content)
          search_content = strip_line_numbers(search_content)
          replace_content = strip_line_numbers(replace_content)
        end

        # Skip if search and replace are identical
        if search_content == replace_content
          diff_results << { success: false, error: "Search and replace content are identical" }
          next
        end

        # Split into lines
        search_lines = search_content.empty? ? [] : search_content.split(/\r?\n/)
        replace_lines = replace_content.empty? ? [] : replace_content.split(/\r?\n/)

        # Validate search content
        if search_lines.empty?
          diff_results << { success: false, error: "Empty search content is not allowed" }
          next
        end

        # Perform fuzzy search
        match_result = perform_fuzzy_search(
          result_lines, search_lines.join("\n"), start_line, no_position)
        # Try again search without position
        unless match_result[:success] or no_position
          match_result = perform_fuzzy_search(
            result_lines, search_lines.join("\n"), start_line, true)
        end
        unless match_result[:success]
          diff_results << match_result
          next
        end

        # Apply replacement
        result_lines = apply_replacement(result_lines, match_result[:match_index], search_lines, 
          replace_lines)

        delta += replace_lines.length - search_lines.length
        applied_count += 1
      end

      # Return results
      if applied_count.zero?
        { success: false, fail_parts: diff_results }
      else
        { success: true, content: result_lines.join("\n"), fail_parts: diff_results }
      end
    end

    # private


    # Validate marker sequencing in the diff content.
    def validate_marker_sequencing(diff_content)
      state = STATE::START
      line_num = 0
      lines = diff_content.split /\r?\n/
      
      lines.each do |line|
        line_num += 1
        marker = line.strip
        case state
        when STATE::START
          if marker == SEP
            return { success: false, error: "Unexpected '=======' at line #{line_num}. Expected '<<<<<<< SEARCH'." }
          elsif marker == REPLACE
            return { success: false, error: "Unexpected '>>>>>>> REPLACE' at line #{line_num}. Expected '<<<<<<< SEARCH'." }
          elsif marker == SEARCH
            state = STATE::AFTER_SEARCH
          end

        when STATE::AFTER_SEARCH
          if marker == SEARCH
            return { success: false, error: "Unexpected '<<<<<<< SEARCH' at line #{line_num}. Expected '======='." }
          elsif marker == REPLACE
            return { success: false, error: "Unexpected '>>>>>>> REPLACE' at line #{line_num}. Expected '======='." }
          elsif marker == SEP && state != STATE::AFTER_SEPARATOR
            state = STATE::AFTER_SEPARATOR
          end

        when STATE::AFTER_SEPARATOR
          if marker == SEARCH
            return { success: false, error: "Unexpected '<<<<<<< SEARCH' at line #{line_num}. Expected '>>>>>>> REPLACE'." }
          elsif marker == SEP && state != STATE::AFTER_SEPARATOR
            return { success: false, error: "Unexpected '=======' at line #{line_num}. Expected '>>>>>>> REPLACE'." }
          elsif marker == REPLACE
            state = STATE::START
          end 
        end
      end

      if state != STATE::START && state != STATE::AFTER_SEPARATOR
        case state
        when STATE::AFTER_SEARCH
          { success: false, error: "Unexpected end of sequence: Expected '=======' was not found." }
        when STATE::AFTER_SEPARATOR
          { success: false, error: "Unexpected end of sequence: Expected '>>>>>>> REPLACE' was not found." }
        else
          { success: false, error: "Unexpected end of sequence." }
        end
      else
        { success: true }
      end
    end


    # Parse replacements from the diff content.
    def parse_replacements(diff_content)
      replacements = []
      lines = diff_content.split /\r?\n/
      
      i = 0
      n = lines.length

      while i < n
        line = lines[i].strip

        if line == '<<<<<<< SEARCH'
          search_start = i + 1
          start_line = nil
          end_line = nil

          # Parse optional :start_line: and :end_line:
          while i + 1 < n
            next_line = lines[i + 1].strip
            if next_line.start_with?(":start_line:")
              start_line = next_line.split(":").last.to_i
              i += 1
            elsif next_line.start_with?(":end_line:")
              end_line = next_line.split(":").last.to_i
              i += 1
            else
              break
            end
          end

          # Skip the "-------" separator if present
          if i + 1 < n && lines[i + 1].strip == "-------"
            i += 1
          end

          # Extract search content until "======="
          search_end = i + 1
          while search_end < n && lines[search_end].strip != "======="
            search_end += 1
          end

          search_content = lines[(i + 1)...search_end].join("\n")
          i = search_end + 1

          # Extract replace content until ">>>>>>> REPLACE"
          replace_end = i
          while replace_end < n && lines[replace_end].strip != ">>>>>>> REPLACE"
            replace_end += 1
          end

          replace_content = lines[i...replace_end].join("\n")
          i = replace_end + 1

          replacements << { start_line: start_line, search_content: search_content, replace_content: replace_content }
        else
          i += 1
        end
      end

      replacements
    end


    # Unescape markers in the content.
    def unescape_markers(content)
      content.gsub(/^\\<<<<<<</, "<<<<<<<").gsub(/^\\=======/, "=======").gsub(/^\\>>>>>>>/, ">>>>>>>")
    end


    # Check if every line has line numbers.
    def every_line_has_line_numbers?(content)
      content.split(/\r?\n/).all? { |line| line.match(/^\d+\|/) }
    end


    # Strip line numbers from content.
    def strip_line_numbers(content)
      content.split(/\r?\n/).map { |line| line.sub(/^\d+\|/, "").strip }.join("\n")
    end


    # Perform fuzzy search for the best match.
    def perform_fuzzy_search(lines, search_chunk, start_line, no_position = false)
      search_lines = search_chunk.split /\r?\n/
      search_len = search_lines.length
      search_start_index = start_line
      search_end_index = lines.length
      normalized_search_chunk = search_lines.join "\n"
      
      unless no_position
        exact_start_index = start_line - 1
        
        exact_end_index = exact_start_index + search_len - 1

        # Try exact match first
        original_chunk = lines[exact_start_index..exact_end_index].join "\n"

        similarity = DiffCrepusculum.get_similarity original_chunk, normalized_search_chunk
        if similarity >= @fuzzy_threshold
          return { success: true, match_index: exact_start_index, similarity_score: similarity }
        end

        # Set bounds for buffered search
        search_start_index = [0, exact_start_index - @buffer_lines].max

        search_end_index = [lines.length, exact_end_index + @buffer_lines].min
      end
      
      # Perform middle-out fuzzy search
      result = DiffCrepusculum.fuzzy_search(
        lines, search_chunk, search_start_index, search_end_index)
      { success: result[:best_match_index] != -1 && result[:best_score] >= 0.5, 
        match_index: result[:best_match_index], similarity_score: result[:best_score] }
    end


    # Apply the replacement to the result lines.
    def apply_replacement(result_lines, match_index, search_lines, replace_lines)
      matched_lines = result_lines[match_index, search_lines.length]

      # Extract indentation from matched lines
      original_indents = matched_lines.map { |line| line.match(/^[ \t]*/)[0] }

      # Extract indentation from search lines (for relative adjustment)
      search_indents = search_lines.map { |line| line.match(/^[ \t]*/)[0] }
      search_base_indent = search_indents.first || ""

      # Apply indentation to replace lines
      indented_replace_lines = replace_lines.map.with_index do |line, idx|
        current_indent = line.match(/^[ \t]*/)[0]
        relative_level = current_indent.length - search_base_indent.length

        # Adjust indentation relative to the matched line

        adjusted_indent = if relative_level <= 0
                            original_indents[0][0...(original_indents[0].length + relative_level)]
                          else
                            original_indents[0] + current_indent[search_base_indent.length..-1]
                          end
        adjusted_indent + line.strip
      end

      result_lines[0...match_index] + indented_replace_lines + result_lines[(match_index + search_lines.length)..-1]

    end
  end
end
