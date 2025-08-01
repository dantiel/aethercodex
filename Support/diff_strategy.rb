# frozen_string_literal: true

# A Ruby implementation of the MultiSearchReplaceDiffStrategy from TypeScript.
# Provides surgical diff application with fuzzy matching and validation.

module DiffStrategies
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
        original_chunk = lines[left_index, search_len].join("\n")
        similarity = get_similarity(original_chunk, search_chunk)
        if similarity > best_score
          best_score = similarity
          best_match_index = left_index
          best_match_content = original_chunk
        end
        left_index -= 1
      end

      if right_index <= (end_index - search_len)
        original_chunk = lines[right_index, search_len].join("\n")
        similarity = get_similarity(original_chunk, search_chunk)
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

  # The main diff strategy class.
  class MultiSearchReplaceDiffStrategy
    attr_reader :fuzzy_threshold, :buffer_lines

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
      result_lines = original_content.split(/\r?\n/)
      delta = 0
      diff_results = []
      applied_count = 0

      # Parse and sort replacements
      replacements = parse_replacements(diff_content)
      replacements.each do |replacement|
        search_content = replacement[:search_content]
        replace_content = replacement[:replace_content]
        start_line = replacement[:start_line] + delta

        # Unescape markers
        search_content = unescape_markers(search_content)
        replace_content = unescape_markers(replace_content)

        # Strip line numbers if present
        if every_line_has_line_numbers?(search_content) && every_line_has_line_numbers?(replace_content)
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
        match_result = perform_fuzzy_search(result_lines, search_lines.join("\n"), start_line)
        unless match_result[:success]
          diff_results << match_result
          next
        end

        # Apply replacement
        result_lines = apply_replacement(result_lines, match_result[:match_index], search_lines, replace_lines)
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

    private

    # Validate marker sequencing in the diff content.
    def validate_marker_sequencing(diff_content)
      # TODO: Implement marker sequencing validation logic.
      { success: true }
    end

    # Parse replacements from the diff content.
    def parse_replacements(diff_content)
      # TODO: Implement parsing logic for replacements.
      []
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
    def perform_fuzzy_search(lines, search_chunk, start_line)
      # TODO: Implement fuzzy search logic.
      { success: true, match_index: 0 }
    end

    # Apply the replacement to the result lines.
    def apply_replacement(result_lines, match_index, search_lines, replace_lines)
      # TODO: Implement replacement logic with indentation preservation.
      result_lines
    end
  end
end