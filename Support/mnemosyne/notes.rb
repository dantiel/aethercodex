# frozen_string_literal: true

class Mnemosyne
  # Notes — notes
  class Notes
    class << self
        def get_note(note_id)
          note = Mnemosyne.db.execute('SELECT * FROM project_notes WHERE id = ? LIMIT 1', [note_id]).first
          note&.transform_keys!(&:to_sym)
          note
        end


        # Retrieve a note by ID

        def recall_notes(query, limit: 5, max_content_length: nil)
          query_tokens = Mnemosyne.tokenize(query)

          sql_query = if query_tokens.empty?
                        ''
                      else
                        'WHERE ' + (%w[content tags links].map do |field|
                          query_tokens&.map { |keyword| "#{field} LIKE '%#{keyword}%'" }&.join ' OR '
                        end.join ' OR ')
                      end

          notes = Mnemosyne.db.execute \
            "SELECT id, content, tags, links, created_at FROM project_notes #{sql_query}"

          notes.map do |note|
            note.transform_keys!(&:to_sym)

            score = 0

            if query_tokens.empty?
              score = 1
            else
              # Enhanced scoring with path matching for better file relevance
              score += 4 * (query_tokens & Mnemosyne.tokenize(note[:content])).size
              score += 3 * (query_tokens & Mnemosyne.tokenize(note[:tags])).size
              score += 2 * (query_tokens & Mnemosyne.tokenize(note[:links])).size

              # Boost score for exact path matches in links
              score += 5 if note[:links] && query_tokens.any? { |token| note[:links].include?(token) }
            end

            { **note, score: }
          end
          .select { |note| note[:score].positive? }
               .sort_by { |note| -note[:score] }
               .take(limit)
               .map do |note|
            # Apply content length limit if specified
            # puts "RECALL NOTES: #{note}"
            if max_content_length && note[:content] && note[:content].length > max_content_length
              note[:content] =
                Mnemosyne.truncate_note_content(note[:content], max_length: max_content_length)
            end
            # puts "RECALL NOTES: #{note[:links]}"
            if note[:links]
              note[:links] = note[:links].split(',').map do |link|
                if Argonaut.file_exists? link
                  link
                else
                  "~~#{link}~~ (path not found)"
                end
              end.join ','
            end
            note # Ensure we return the note hash, not the links string
          end
        end

        def create_note(content:, links: nil, tags: nil)
          truncated_content = Mnemosyne.truncate_note_content(content)
          Mnemosyne.db.execute "
            INSERT INTO project_notes (content, links, tags, created_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)",
                     [truncated_content, links&.join(','), tags&.join(',')]
          Mnemosyne.db.last_insert_row_id
        end


        # Alias for create_note for backward compatibility

        def remember(content:, links: nil, tags: nil)
          create_note content: content, links: links, tags: tags
        end


        # Fetch notes by links (for Argonaut file overview)

        def fetch_notes_by_links(links)
          links = [links] unless links.is_a? Array

          result = Mnemosyne.db.execute("SELECT * FROM project_notes WHERE #{(['links LIKE ?'] * links.count).join ' OR '}",
                              links.map { |link| "%#{link}%" })

          # Handle nil result gracefully
          return [] unless result

          result.each do |note|
            note.transform_keys!(&:to_sym)
          end
        end



        def update_note(id, content: nil, links: nil, tags: nil)
          truncated_content = Mnemosyne.truncate_note_content(content) if content
          Mnemosyne.db.execute \
            'UPDATE project_notes SET content = ?, links = ?, tags = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [
              truncated_content || content, links&.join(','), tags&.join(','), id
            ]
        end


        # Remove note by id

        def remove_note(id)
          Mnemosyne.db.execute 'DELETE FROM project_notes WHERE id = ?', [id]
        end



    end
  end
end
