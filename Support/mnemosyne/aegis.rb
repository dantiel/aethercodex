# frozen_string_literal: true
require_relative '../instrumentarium/metaprogramming_utils'
using TokenExtensions

class Mnemosyne
  # Aegis — aegis
  class Aegis
    class << self
        def update_aegis_summary(summary)
          Mnemosyne.aegis[:summary] = summary
          Mnemosyne.save_aegis_state(**Mnemosyne.aegis)
        end


        # Dynamically adjust the Aegis temperature

        def set_aegis_temperature(temperature)
          Mnemosyne.aegis[:temperature] = temperature
          Mnemosyne.save_aegis_state(**Mnemosyne.aegis)
        end



        def fetch_aegis_summaries(before:, max_tokens:)
          before_str = before.respond_to?(:iso8601) ? before.iso8601 : before.to_s
          summaries = Mnemosyne.db.execute('
            SELECT summary, tags, created_at FROM aegis_state
            WHERE created_at <= ? ORDER BY created_at DESC
            ', [before_str]).map { |el| el.transform_keys!(&:to_sym) }

          tokens = 0
          included_summaries = []

          summaries.each do |summary|
            summary_tokens = summary.to_s.tok_len
            break unless tokens + summary_tokens <= max_tokens

            included_summaries << summary
            tokens += summary_tokens
          end

          included_summaries
        end


        # Retrieve a note by ID

        def save_aegis_state(tags: [], summary: nil, temperature: 1.0, working_dir: nil,
                             thinking: nil, **)
          tags = Array tags
          tags_json = tags.join ','
          Mnemosyne.db.execute \
            'INSERT INTO aegis_state ' \
            '(tags, summary, temperature, working_dir, thinking_str, created_at) VALUES ' \
            '(?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
            [tags_json, summary, temperature, working_dir, thinking]
        end



        def load_aegis(db: nil, limit: 3)
          db ||= Mnemosyne.db
          db.execute 'SELECT tags, summary, temperature, working_dir, thinking_str AS thinking FROM aegis_state ' \
                     'ORDER BY created_at DESC LIMIT ?', [limit]
        end



        def restore_aegis(db = nil)
          db ||= Mnemosyne.db
          aegis = (load_aegis db:, limit: 1)&.first
          Mnemosyne.aegis = if aegis.nil? || aegis.empty?
                     { tags: [], summary: '', temperature: 1.0, working_dir: nil, thinking: nil }
                   else
                     aegis.transform_keys(&:to_sym)
                   end
        end



        def unveil_aegis(**aegis)
          aegis.compact!
          aegis[:working_dir] ||= Mnemosyne.aegis[:working_dir] # Preserve existing working_dir
          Mnemosyne.aegis.merge! aegis
          Mnemosyne.save_aegis_state(**aegis)

          recall_aegis_notes
        end



        def working_dir
          Mnemosyne.aegis[:working_dir] unless Mnemosyne.aegis.nil?
        end



        def set_working_dir(dir)
          old = Mnemosyne.aegis[:working_dir]
          Mnemosyne.aegis[:working_dir] = dir
          save_aegis_state working_dir: dir
          dir
        end



        def recall_aegis_notes(max_tokens: nil, max_content_length: nil)
          tags = []
          unless Mnemosyne.aegis.nil?
            tags = Mnemosyne.aegis[:tags] unless Mnemosyne.aegis[:tags].nil?
            tags = Mnemosyne.aegis[:summary]&.gsub(' ', ',') if tags.empty?
          end
          tags = tags.split ',' if tags.is_a? String
          notes = Mnemosyne.recall_notes(tags&.join(' '), limit: 8, max_content_length: max_content_length)

          # Apply token limit if provided
          unless max_tokens.nil?
            token_count = 0
            included_notes = []

            notes.each do |note|
              note_tokens = note.to_json.tok_len
              break if token_count + note_tokens > max_tokens

              included_notes << note
              token_count += note_tokens
            end

            notes = included_notes
          end

          notes
        end



    end
  end
end