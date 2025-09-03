# frozen_string_literal: true

# ChrysopoeiaDiffStrategy
# Provides surgical diff application with fuzzy matching and validation.

module DiffCrepusculum
  BUFFER_LINES = 40 # Number of extra context lines to show before and after matches

  # Calculate similarity between two strings using Levenshtein distance.
  def self.get_similarity(original, search)
    return 0.0 if search.empty?

    normalized_original = normalize_string original
    normalized_search = normalize_string search

    return 1.0 if normalized_original == normalized_search

    dist = levenshtein_distance normalized_original, normalized_search
    max_length = [normalized_original.length, normalized_search.length].max

    1.0 - (dist.to_f / max_length)
  end


  # Calculate chunk similarity as average of per-line similarities.
  def self.get_chunk_similarity(original_slice, search_lines)
    len = search_lines.size
    return 0.0 if len.zero?

    sum = 0.0
    (0...len).each do |i|
      sum += get_similarity original_slice[i], search_lines[i]
    end
    sum / len
  end


  # Perform a middle-out search for the most similar slice.
  def self.fuzzy_search(lines, search_lines, start_index, end_index)
    best_score = 0.0
    best_match_index = -1
    search_len = search_lines.length

    mid_point = ((start_index + end_index) / 2).floor
    left_index = mid_point
    right_index = mid_point + 1

    while left_index >= start_index || right_index <= (end_index - search_len)
      if left_index >= start_index
        original_slice = lines[left_index, search_len]

        if original_slice.length == search_len
          similarity = get_chunk_similarity original_slice, search_lines
          if similarity > best_score
            best_score = similarity
            best_match_index = left_index
          end
        end
        left_index -= 1
      end

      next unless right_index <= (end_index - search_len)

      original_slice = lines[right_index, search_len]

      if original_slice.length == search_len
        similarity = get_chunk_similarity original_slice, search_lines
        if similarity > best_score
          best_score = similarity
          best_match_index = right_index
        end
      end
      right_index += 1
    end

    { best_score: best_score, best_match_index: best_match_index }
  end


  # Optimized Levenshtein distance calculation using two rows.
  def self.levenshtein_distance(a, b)
    # Ensure a is the shorter string to optimize space
    a, b = b, a if a.length > b.length

    m = a.length
    n = b.length

    return n if m.zero?
    return m if n.zero?

    prev = (0..n).to_a

    (1..m).each do |i|
      curr = [i] + ([0] * n)
      (1..n).each do |j|
        cost = a[i - 1] == b[j - 1] ? 0 : 1
        curr[j] = [
          curr[j - 1] + 1,        # Insertion
          prev[j] + 1,            # Deletion
          prev[j - 1] + cost      # Substitution
        ].min
      end
      prev = curr
    end

    prev[n]
  end


  # Normalize strings for comparison (e.g., handle smart quotes).
  def self.normalize_string(str)
    str.gsub(/[‘’]/, "'").gsub(/[“”]/, '"').strip
  end


  class STATE
    START = :start
    AFTER_SEARCH = :after_search
    AFTER_SEPARATOR = :after_separator
  end


  # The main diff strategy class.
  class ChrysopoeiaDiff
    attr_accessor :fuzzy_threshold
    attr_reader :buffer_lines

    SEARCH = '<<<<<<< SEARCH'
    SEP = '======='
    REPLACE = '>>>>>>> REPLACE'

    def initialize(fuzzy_threshold = 1.0, buffer_lines = BUFFER_LINES)
      @fuzzy_threshold = fuzzy_threshold
      @buffer_lines = buffer_lines
    end


    def name
      'MultiSearchReplace'
    end


    # Validate and apply the diff with fuzzy matching and marker sequencing.
    def apply_diff(original_content, diff_content, _param_start_line = nil, _param_end_line = nil)
      # Validate marker sequencing
      valid_seq = validate_marker_sequencing diff_content
      return { success: false, error: valid_seq[:error] } unless valid_seq[:success]

      # Split content into lines
      result_lines = original_content.split(/\r?\n/)
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

          search_content = strip_line_numbers search_content
          replace_content = strip_line_numbers replace_content
        end

        # Skip if search and replace are identical
        if search_content == replace_content
          diff_results << { success: false, error: 'Search and replace content are identical' }
          next
        end

        # Split into lines
        search_lines = search_content.empty? ? [] : search_content.split(/\r?\n/)
        replace_lines = replace_content.empty? ? [] : replace_content.split(/\r?\n/)

        # Validate search content
        if search_lines.empty?
          diff_results << { success: false, error: 'Empty search content is not allowed' }
          next
        end

        # Perform fuzzy search
        match_result = perform_fuzzy_search \
          result_lines, search_lines, start_line, no_position

        # Try again search without position
        unless match_result[:success] or no_position
          match_result = perform_fuzzy_search(
            result_lines, search_lines, start_line, true
          )
        end
        unless match_result[:success]
          diff_results << match_result
          next
        end

        # Apply replacement
        result_lines = apply_replacement result_lines, match_result[:match_index], search_lines,
                                         replace_lines

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
      lines = diff_content.split(/\r?\n/)

      lines.each do |line|
        line_num += 1
        marker = line.strip
        case state
        when STATE::START
          case marker
          when SEP
            return { success: false,
                     error:   "Unexpected '=======' at line #{line_num}. Expected '<<<<<<< SEARCH'." }
          when REPLACE
            return { success: false,
                     error:   "Unexpected '>>>>>>> REPLACE' at line #{line_num}. Expected '<<<<<<< SEARCH'." }
          when SEARCH
            state = STATE::AFTER_SEARCH
          end

        when STATE::AFTER_SEARCH
          if SEARCH == marker
            return { success: false,
                     error:   "Unexpected '<<<<<<< SEARCH' at line #{line_num}. Expected '======='." }
          elsif REPLACE == marker
            return { success: false,
                     error:   "Unexpected '>>>>>>> REPLACE' at line #{line_num}. Expected '======='." }
          elsif SEP == marker && STATE::AFTER_SEPARATOR != state
            state = STATE::AFTER_SEPARATOR
          end

        when STATE::AFTER_SEPARATOR
          if SEARCH == marker
            return { success: false,
                     error:   "Unexpected '<<<<<<< SEARCH' at line #{line_num}. Expected '>>>>>>> REPLACE'." }
          elsif SEP == marker && STATE::AFTER_SEPARATOR != state
            return { success: false,
                     error:   "Unexpected '=======' at line #{line_num}. Expected '>>>>>>> REPLACE'." }
          elsif REPLACE == marker
            state = STATE::START
          end
        end
      end

      if STATE::START != state && STATE::AFTER_SEPARATOR != state
        case state
        when STATE::AFTER_SEARCH
          { success: false, error: "Unexpected end of sequence: Expected '=======' was not found." }
        when STATE::AFTER_SEPARATOR
          { success: false,
            error:   "Unexpected end of sequence: Expected '>>>>>>> REPLACE' was not found." }
        else
          { success: false, error: 'Unexpected end of sequence.' }
        end
      else
        { success: true }
      end
    end


    # Parse replacements from the diff content.
    def parse_replacements(diff_content)
      replacements = []
      lines = diff_content.split(/\r?\n/)

      i = 0
      n = lines.length

      while i < n
        line = lines[i].strip

        if '<<<<<<< SEARCH' == line
          search_start = i + 1
          start_line = nil
          end_line = nil

          # Parse optional :start_line: and :end_line:
          while i + 1 < n
            next_line = lines[i + 1].strip
            if next_line.start_with? ':start_line:'
              start_line = next_line.split(':').last.to_i
              i += 1
            elsif next_line.start_with? ':end_line:'
              end_line = next_line.split(':').last.to_i
              i += 1
            else
              break
            end
          end

          # Skip the "-------" separator if present
          i += 1 if i + 1 < n && '-------' == lines[i + 1].strip

          # Extract search content until "======="
          search_end = i + 1
          search_end += 1 while search_end < n && '=======' != lines[search_end].strip

          search_content = lines[(i + 1)...search_end].join "\n"
          i = search_end + 1

          # Extract replace content until ">>>>>>> REPLACE"
          replace_end = i
          replace_end += 1 while replace_end < n && '>>>>>>> REPLACE' != lines[replace_end].strip

          replace_content = lines[i...replace_end].join "\n"
          i = replace_end + 1

          replacements << { start_line:      start_line,
                            search_content:  search_content,
                            replace_content: replace_content }
        else
          i += 1
        end
      end

      replacements
    end


    # Unescape markers in the content.
    def unescape_markers(content)
      content.gsub(/^\\<<<<<<</, '<<<<<<<').gsub(/^\\=======/, '=======').gsub(/^\\>>>>>>>/,
                                                                               '>>>>>>>')
    end


    # Check if every line has line numbers.
    def every_line_has_line_numbers?(content)
      content.split(/\r?\n/).all? { |line| line.match(/^\d+\|/) }
    end


    # Strip line numbers from content.
    def strip_line_numbers(content)
      content.split(/\r?\n/).map { |line| line.sub(/^\d+\|/, '').strip }.join("\n")
    end


    # Perform fuzzy search for the best match.
    def perform_fuzzy_search(lines, search_lines, start_line, no_position = false)
      search_len = search_lines.length
      search_start_index = start_line
      search_end_index = lines.length

      unless no_position
        exact_start_index = start_line - 1

        exact_end_index = exact_start_index + search_len - 1

        # Try exact match first
        original_slice = lines[exact_start_index, search_len]
        if original_slice.length == search_len
          similarity = DiffCrepusculum.get_chunk_similarity original_slice, search_lines
          if similarity >= @fuzzy_threshold
            return { success: true, match_index: exact_start_index, similarity_score: similarity }
          end
        end

        # Set bounds for buffered search
        search_start_index = [0, exact_start_index - @buffer_lines].max
        search_end_index = [lines.length, exact_end_index + @buffer_lines].min
      end

      # Perform middle-out fuzzy search
      result = DiffCrepusculum.fuzzy_search \
        lines, search_lines, search_start_index, search_end_index

      { success:          -1 != result[:best_match_index] && 0.5 <= result[:best_score],
        match_index:      result[:best_match_index],
        similarity_score: result[:best_score] }
    end


    # Apply the replacement to the result lines.
    def apply_replacement(result_lines, match_index, search_lines, replace_lines)
      matched_lines = result_lines[match_index, search_lines.length]

      # Extract indentation from matched lines
      original_indents = matched_lines.map { |line| line.match(/^[ \t]*/)[0] }

      # Extract indentation from search lines (for relative adjustment)
      search_indents = search_lines.map { |line| line.match(/^[ \t]*/)[0] }
      search_base_indent = search_indents.first || ''

      # Apply indentation to replace lines
      indented_replace_lines = replace_lines.map.with_index do |line, _idx|
        current_indent = line.match(/^[ \t]*/)[0]
        relative_level = current_indent.length - search_base_indent.length

        # Adjust indentation relative to the matched line
        adjusted_indent = if 0 >= relative_level
                            original_indents[0][0...(original_indents[0].length + relative_level)]
                          else
                            original_indents[0] + current_indent[search_base_indent.length..]
                          end
        adjusted_indent + line.strip
      end

      result_lines[0...match_index] + indented_replace_lines + result_lines[(match_index + search_lines.length)..]
    end
  end
end
