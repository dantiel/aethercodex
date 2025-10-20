# frozen_string_literal: true

require 'json'
require_relative 'continuum_weaver'

# Hermetic Live Observer for real-time pair programming
class LiveObserver
  def self.process_live_update(payload)
    log_json(json: {
      type: 'live_update_received',
      path: payload['path'],
      cursor_line: payload['cursor'],
      content_length: payload['content']&.length || 0,
      timestamp: payload['timestamp']
    })

    # Store current document state in memory
    store_document_snapshot(payload)
    
    # Generate proactive suggestions if conditions are met
    generate_proactive_suggestions(payload)
    
    # Return acknowledgment
    { status: 'observed', timestamp: Time.now.to_f }
  end

  def self.store_document_snapshot(payload)
    # Store in temporary memory for context tracking
    # This could be enhanced with Mnemosyne integration later
    @last_document_state ||= {}
    @last_document_state[payload['path']] = {
      content: payload['content'],
      cursor_line: payload['cursor'],
      timestamp: payload['timestamp']
    }
  end

  def self.generate_proactive_suggestions(payload)
    # Only generate suggestions if we have previous state for comparison
    return unless @last_document_state && @last_document_state[payload['path']]
    
    previous_state = @last_document_state[payload['path']]
    current_content = payload['content']
    
    # Simple change detection - compare content
    if previous_state[:content] != current_content
      # Calculate context around cursor for proactive suggestions
      cursor_line = payload['cursor']
      
  def self.process_hermetic_live_update(payload)
    log_json(json: {
      type: 'hermetic_live_update_received',
      path: payload['path'],
      cursor_line: payload['cursor'],
      content_length: payload['content']&.length || 0,
      scope: payload['scope'],
      language: payload['language'],
      timestamp: payload['timestamp']
    })

    # Store current document state with enhanced context
    store_hermetic_document_snapshot(payload)
    
    # Generate proactive suggestions using ContinuumWeaver
    suggestions = generate_hermetic_proactive_suggestions(payload)
    
    # Return suggestions for frontend display
    {
      status: 'hermetic_observed',
      timestamp: Time.now.to_f,
      suggestions: suggestions,
      context: {
        path: payload['path'],
        cursor_line: payload['cursor'],
        language: payload['language']
      }
    }
  end

  def self.store_hermetic_document_snapshot(payload)
    # Enhanced storage with language and scope context
    @hermetic_document_states ||= {}
    @hermetic_document_states[payload['path']] = {
      content: payload['content'],
      cursor_line: payload['cursor'],
      scope: payload['scope'],
      language: payload['language'],
      timestamp: payload['timestamp']
    }
  end

  def self.generate_hermetic_proactive_suggestions(payload)
    # Use ContinuumWeaver for intelligent proactive suggestions
    begin
      weaver = ContinuumWeaver.new
      
      # Generate proactive suggestion based on current context
      suggestion = weaver.generate_proactive_suggestion(
        content: payload['content'],
        cursor_line: payload['cursor'],
        file_path: payload['path'],
        language: payload['language']
      )
      
      return [suggestion].compact
    rescue => e
      log_json(error: e, info: "Failed to generate hermetic proactive suggestions")
      return []
    end
  end

      # Extract context around cursor (similar to ContinuumWeaver but proactive)
      before_context, after_context = extract_context_around_cursor(current_content, cursor_line)
      
      # Generate suggestion using ContinuumWeaver
      suggestion = ContinuumWeaver.generate_proactive_suggestion(
        before_context: before_context,
        after_context: after_context,
        cursor_line: cursor_line,
        file_path: payload['path']
      )
      
      if suggestion
        log_json(json: {
          type: 'proactive_suggestion_generated',
          path: payload['path'],
          cursor_line: cursor_line,
          suggestion: suggestion.truncate(100)
        })
        
        # Send suggestion to frontend via WebSocket
        send_suggestion_to_frontend(payload['path'], cursor_line, suggestion)
      end
    end
  end

  def self.extract_context_around_cursor(content, cursor_line, max_chars: 2000)
    lines = content.lines
    cursor_index = cursor_line - 1
    
    # Collect lines before cursor
    before_lines = []
    before_chars = 0
    (cursor_index - 1).downto(0) do |i|
      line = lines[i]
      break if before_chars + line.length > max_chars / 2
      before_lines.unshift(line)
      before_chars += line.length
    end
    
    # Collect lines after cursor
    after_lines = []
    after_chars = 0
    cursor_index.upto(lines.length - 1) do |i|
      line = lines[i]
      break if after_chars + line.length > max_chars / 2
      after_lines << line
      after_chars += line.length
    end
    
    [before_lines.join, after_lines.join]
  end

  def self.send_suggestion_to_frontend(path, cursor_line, suggestion)
    # This would send the suggestion via WebSocket to the frontend
    # For now, we'll log it and the frontend can poll or we'll implement proper WebSocket push
    log_json(json: {
      type: 'suggestion_available',
      path: path,
      cursor_line: cursor_line,
      suggestion: suggestion
    })
  end

  def self.log_json(**kwargs)
    if kwargs.key?(:json)
      puts "[LIVE_OBSERVER][INFO]: #{kwargs[:json].transform_values { |v| v.to_s.truncate(500) }.inspect}"
    else
      message = '[LIVE_OBSERVER][ERROR]: '
      message += "error: #{kwargs[:error].to_s.truncate(600)}" if kwargs[:error]
      puts message
    end
  end
end