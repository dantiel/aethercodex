# frozen_string_literal: true

class Mnemosyne
  # Chronicle — chronicle
  class Chronicle
    class << self
        def fetch_history(limit: 7, max_tokens: nil, include_tool_calls: false)
          # Select all fields including tool_calls_json
          fields_sql = %w[prompt answer tool_call_count execution_time timestamp tool_calls_json
                          created_at].join ','
          entries = Mnemosyne.db.execute(
            "SELECT #{fields_sql} FROM entries ORDER BY id DESC LIMIT ?", [limit]
          ).map { |entry| entry.transform_keys!(&:to_sym) }

          # Process tool calls with priority-based filtering if requested
          if include_tool_calls
            entries = entries.map do |entry|
              if entry[:tool_calls_json] && !entry[:tool_calls_json].empty?
                tool_calls_hash = Mnemosyne.safe_parse_json(entry[:tool_calls_json], {})
                tool_calls = tool_calls_hash.map(&:deep_symbolize_keys)
                # Apply priority-based filtering to tool calls
                filtered_tool_calls = tool_calls
                entry[:tool_calls] = filtered_tool_calls
              else
                entry[:tool_calls] = []
              end
              entry
            end
          end

          unless max_tokens.nil?
            tokens = 0
            included_entries = []
            entries.each do |entry|
              entry_tokens = (entry[:prompt] + entry[:answer]).tok_len

              if entry_tokens > max_tokens
                entry[:answer] = entry[:answer].gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                     '```\\1[CONTENT EXPIRED]```')
                entry_tokens = (entry[:prompt] + entry[:answer]).tok_len
                next if entry_tokens > max_tokens
              end
              break unless tokens + entry_tokens <= max_tokens

              included_entries << entry
              tokens += entry_tokens
            end

            entries = included_entries
          end

          entries.reverse
        end



        def record(prompt: '',
                   attachments: [],
                   tags: nil,
                   file: nil,
                   execution_time: 0,
                   tool_call_count: 0,
                   timestamp: nil,
                   answer: '',
                   tool_calls: [],
                   task_id: nil,
                   step_id: nil,
                   mode: nil)
          # Set operational mode if specified
          set_operational_mode mode if mode

          puts '[MNEMOSYNE][RECORD]: recording ' \
               "#{((prompt.to_json.inspect || '') + (answer || '')).tok_len} " \
               "tokens: #{answer.truncate 200}"
          puts "[MNEMOSYNE][RECORD]: tool_calls=#{tool_calls.inspect}"

          # Apply priority-based truncation to tool calls before storage
          truncated_tool_calls = truncate_tool_calls_by_priority tool_calls

          # TODO: filter content
          # Calculate tool call count
          actual_tool_call_count = truncated_tool_calls.is_a?(Array) ? truncated_tool_calls.size : 0

          # Store prompt, answer, and tool_calls in their respective fields
          entry_id = Mnemosyne.db.execute \
            'INSERT INTO entries (prompt, answer, tags, file, selection, execution_time, ' \
            'tool_call_count, tool_calls_json, created_at) VALUES (?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)',
            [prompt, answer, Array(tags).join(','), file,
             attachments.to_json, execution_time, actual_tool_call_count, truncated_tool_calls.to_json]
          entry_id = Mnemosyne.db.last_insert_row_id
          entry_id
        end


        # TODO: apply this also to tool calls stored in tasks
        # Apply priority-based truncation to tool calls before storage with security filtering

        def truncate_tool_calls_by_priority(tool_calls)
          return [] unless tool_calls.is_a? Array

          puts "truncate_tool_calls_by_priority=#{tool_calls.inspect}"

          tool_calls.map do |tool_call|
            tool_name = tool_call[:name]
            tool_priority = Instrumenta.tools[tool_name&.to_sym]&.history_priority || 1

            # Calculate base truncation limit based on tool priority
            base_limit = case tool_priority
                         when 0..1 then 300   # Standard tools (priority 1)
                         when 2..4 then 600   # Medium priority tools
                         when 5..9 then 1200  # High priority tools
                         else 3000 # Critical priority tools (10+)
                         end

            # Apply truncation to request and result fields with security filtering
            truncated_tool_call = tool_call.dup
            truncated_tool_call[:args] =
              truncate_hash_by_priority truncated_tool_call[:args], base_limit
            truncated_tool_call[:result] =
              truncate_hash_by_priority truncated_tool_call[:result], base_limit

            truncated_tool_call
          end
        end


        # Helper method to truncate hash values based on priority limit

        def truncate_hash_by_priority(hash, base_limit)
          return hash unless hash.is_a? Hash

          hash.transform_values do |value|
            case value
            when String
              value.truncate base_limit
            when Hash
              truncate_hash_by_priority(value, base_limit / 2) # Recursively truncate nested hashes
            when Array
              value.map { |v| v.is_a?(String) ? v.truncate(base_limit / 3) : v }
            else
              value
            end
          end
        end


        # Get entry by ID

        def get_entry(entry_id)
          entry = Mnemosyne.db.execute('SELECT * FROM entries WHERE id = ? LIMIT 1', [entry_id]).first
          entry&.transform_keys!(&:to_sym)
        end


        # Alias for create_note for backward compatibility

        def search(query, limit: 5)
          entries = Mnemosyne.db.execute \
            'SELECT prompt, answer, tool_calls_json, created_at FROM entries WHERE ' \
            'tags LIKE ? OR prompt LIKE ? OR file LIKE ? ORDER BY id DESC LIMIT ?',
            ["%#{query}%", "%#{query}%", "%#{query}%", limit]


          entries.map do |entry|
            entry = entry.deep_symbolize_keys
            if entry[:tool_calls_json].present?
              tool_calls_hash = Mnemosyne.safe_parse_json(entry[:tool_calls_json], {})
              tool_calls_hash = tool_calls_hash.map(&:deep_symbolize_keys)
              entry[:tool_calls] = format_history_tool_calls tool_calls_hash, 0
            end
            entry.delete :tool_calls_json
            entry
          end
        end



        def format_history_tool_calls(tool_calls, index = 0)
          # Enhanced base_priority calculation with exponential decay
          base_priority = Math.exp(-index.to_f / 1.0) * 3

          # Calculate tool call density factor
          total_tool_calls = tool_calls.size
          density_factor = [1.0, total_tool_calls.to_f / 5.0].max

          isLastCommand = true
          isFirstCommand = false

          tool_calls_strs = tool_calls.map.with_index do |tcall, tool_index|
            tool_name = tcall[:name] || ''
            next nil if tool_name.empty? && tcall[:content].nil?

            isFirst = tool_index.zero?
            isLast = tool_calls.size - 1 == tool_index

            tool_priority = Instrumenta.tools[tool_name.to_sym]&.history_priority || 0

            # Calculate position factor for current history entry (index == 0)
            position_factor = if index.zero?
                                # In most recent entry, later tools get more detail
                                1.0 + ((tool_index.to_f / total_tool_calls) * 0.5)
                              else
                                # In older entries, all tools get reduced detail
                                1.0
                              end

            # Combined priority calculation
            combined_priority = (base_priority + tool_priority) * position_factor / density_factor

            # Scalable transient priority system with progressive truncation
            # Standard tools have priority 1, higher priorities get more generous limits
            case tool_priority
            when 1 # Standard tools
              args_truncate = [50, (combined_priority * 25).to_i].max
              result_truncate = [0, (combined_priority * 50).to_i].max
              content_truncate = [50, (combined_priority * 25).to_i].max
            when 2..4  # Medium priority tools
              args_truncate = [100, (combined_priority * 50).to_i].max
              result_truncate = [200, (combined_priority * 100).to_i].max
              content_truncate = [100, (combined_priority * 50).to_i].max
            when 5..9  # High priority tools
              args_truncate = [200, (combined_priority * 100).to_i].max
              result_truncate = [400, (combined_priority * 200).to_i].max
              content_truncate = [200, (combined_priority * 100).to_i].max
            when 10..Float::INFINITY # Critical priority tools (like oracle_conjuration)
              args_truncate = [500, (combined_priority * 200).to_i].max
              result_truncate = [1000, (combined_priority * 400).to_i].max
              content_truncate = [500, (combined_priority * 200).to_i].max
            else # Fallback for unknown priorities
              args_truncate = 50
              result_truncate = 0
              content_truncate = 100
            end

            # Apply additional scaling for most recent entry
            if index.zero?
              args_truncate = (args_truncate * 1.5).to_i
              result_truncate = (result_truncate * 1.5).to_i
              content_truncate = (content_truncate * 1.5).to_i
            end

            tool_name = "• #{tool_name}" if tool_name.present?
            args = if 20 < args_truncate && tcall[:args]
                     (tcall[:args] || {}).to_s_no_quotes.truncate(args_truncate, :middle).to_s
                   else
                     ''
                   end
            result = if 30 < result_truncate && tcall[:result]
                       " → #{tcall[:result].to_s_no_quotes.truncate result_truncate, :middle}"
                     elsif args.present?
                       ' # result omitted'
                     else
                       ''
                     end
            isFirstCommand = true if isFirst && args.present?

            # Include content field if present in tool call
            content = if tcall[:content]
                        isLastCommand = false if isLast
                        (isFirst ? '' : "=== END TOOL HISTORY ===\n\n") +
                          "#{tcall[:content].truncate content_truncate}\n\n" +
                          (isLast ? '' : '=== BEGIN TOOL HISTORY ===')
                      else
                        ''
                      end

            "#{tool_name}#{args}#{result}#{content}"
          end.compact

          if tool_calls_strs.length.positive?
            (isFirstCommand ? '=== BEGIN TOOL HISTORY ===' : '') +
              tool_calls_strs.join("\n").to_s +
              (isLastCommand ? '=== END TOOL HISTORY ===' : '')
          else
            ''
          end
        end


        # Helper method for safe JSON parsing

    end
  end
end
