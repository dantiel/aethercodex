# Hermetic Context Extractor
# Unified context extraction for continuum commands and proactive suggestions

class ContextExtractor
  # Extract context around cursor position
  # Uses the same pattern as continuum commands
  def self.extract_context_around_cursor(content, line_num, column_num, max_chars: 2000, context_lines: 20)
    lines = content.split("\n")
    
    # Convert to 0-based indexing
    line_idx = line_num - 1
    col_idx = column_num - 1
    
    before_context = extract_before_context(lines, line_idx, col_idx, max_chars, context_lines)
    after_context = extract_after_context(lines, line_idx, col_idx, max_chars, context_lines)
    
    { before: before_context, after: after_context }
  end
  
  # Extract context around selection
  def self.extract_context_around_selection(content, selection_range, selected_text, max_chars: 2000, context_lines: 20)
    lines = content.split("\n")
    
    # Parse selection range format: 36:20-37:4 or 36-37 or 36:20-37 or 36-37:4 or 36:20
    if selection_range =~ /^(\d+)(?::(\d+))?(-(\d+)(?::(\d+))?)?$/
      start_line = $1.to_i - 1  # Convert to 0-based
      start_col = $2 ? $2.to_i - 1 : 0
      end_line = $4 ? $4.to_i - 1 : start_line
      end_col = $5 ? $5.to_i : -1
      
      before_context = extract_before_context_selection(lines, start_line, start_col, max_chars, context_lines)
      after_context = extract_after_context_selection(lines, end_line, end_col, max_chars, context_lines)
      
      { before: before_context, after: after_context }
    else
      # Fallback to cursor mode if selection parsing fails
      { before: "", after: "" }
    end
  end
  
  private
  
  # Extract before context for cursor mode
  def self.extract_before_context(lines, line_idx, col_idx, max_chars, context_lines)
    before_start_line = [0, line_idx - context_lines].max
    before_lines = lines[before_start_line...line_idx] || []
    
    collected_lines = []
    current_chars = 0
    
    # Add lines before cursor (most recent first)
    before_lines.reverse_each do |line|
      line_length = line.length + 1
      if current_chars + line_length <= max_chars
        collected_lines.unshift(line)
        current_chars += line_length
      else
        break
      end
    end
    
    # Add current line up to cursor
    current_line_before = lines[line_idx] ? lines[line_idx][0...col_idx] : ""
    if current_line_before && current_chars + current_line_before.length <= max_chars
      collected_lines << current_line_before
    end
    
    collected_lines.join("\n")
  end
  
  # Extract after context for cursor mode
  def self.extract_after_context(lines, line_idx, col_idx, max_chars, context_lines)
    collected_lines = []
    current_chars = 0
    
    # Add current line after cursor
    current_line_after = lines[line_idx] ? lines[line_idx][col_idx..-1] : ""
    if current_line_after && current_chars + current_line_after.length <= max_chars
      collected_lines << current_line_after
      current_chars += current_line_after.length
    end
    
    # Add lines after cursor
    after_start_line = line_idx + 1
    after_end_line = [lines.length, after_start_line + context_lines].min
    after_lines = lines[after_start_line...after_end_line] || []
    
    after_lines.each do |line|
      line_length = line.length + 1
      if current_chars + line_length <= max_chars
        collected_lines << line
        current_chars += line_length
      else
        break
      end
    end
    
    collected_lines.join("\n")
  end
  
  # Extract before context for selection mode
  def self.extract_before_context_selection(lines, start_line, start_col, max_chars, context_lines)
    collected_lines = []
    current_chars = 0
    
    # Add lines before selection
    before_start_line = [0, start_line - context_lines].max
    before_lines = lines[before_start_line...start_line] || []
    
    before_lines.reverse_each do |line|
      line_length = line.length + 1
      if current_chars + line_length <= max_chars
        collected_lines.unshift(line)
        current_chars += line_length
      else
        break
      end
    end
    
    # Add start line up to selection
    if lines[start_line]
      start_line_before = lines[start_line][0...start_col]
      if start_line_before && current_chars + start_line_before.length <= max_chars
        collected_lines << start_line_before
      end
    end
    
    collected_lines.join("\n")
  end
  
  # Extract after context for selection mode
  def self.extract_after_context_selection(lines, end_line, end_col, max_chars, context_lines)
    collected_lines = []
    current_chars = 0
    
    # Add end line after selection
    if lines[end_line] && end_col >= 0
      end_line_after = lines[end_line][end_col..-1]
      if end_line_after && current_chars + end_line_after.length <= max_chars
        collected_lines << end_line_after
        current_chars += end_line_after.length
      end
    end
    
    # Add lines after selection
    after_start_line = end_line + 1
    after_end_line = [lines.length, after_start_line + context_lines].min
    after_lines = lines[after_start_line...after_end_line] || []
    
    after_lines.each do |line|
      line_length = line.length + 1
      if current_chars + line_length <= max_chars
        collected_lines << line
        current_chars += line_length
      else
        break
      end
    end
    
    collected_lines.join("\n")
  end
end