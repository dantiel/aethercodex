# frozen_string_literal: true

class Mnemosyne
  # MetempsychosisRouter — metempsychosis router
  class MetempsychosisRouter
    class << self
        require_relative '../aether_link'



    # Metempsychosis — the transmigration of memory between contexts.
    # Queries another task's notes (or global memory) as if recalling a past life.
    # +from_task+ : integer task ID whose memory to consult; nil for global notes only.
    # +from_context+ : remote context name — queries peer via ÆtherLink instead of local DB.
    # +to_context+ : remote context name — pushes matching notes into peer's memory.
    # +create_task_in+ : remote context name — spawns a task on peer, using +query+ as title.
    # Returns matching notes plus a summary of the target task's state (plan, status, phase results).
    def metempsychosis(query:, from_task: nil, limit: 3, subscribe: false, unsubscribe: false,
                       from_context: nil, to_context: nil, create_task_in: nil)
      # Cross-context: query remote context's memory
      if from_context
        result = AetherLink.query(from_context, '/aether/metempsychosis',
                                  { query: query, from_task: from_task, limit: limit,
                                    subscribe: subscribe, unsubscribe: unsubscribe })
        return result || { error: "Context '#{from_context}' unreachable" }
      end

      # Cross-context: push local notes into remote context
      if to_context
        local_result = metempsychosis(query: query, from_task: from_task, limit: limit)
        notes = local_result[:notes] || []
        notes.each do |note|
          AetherLink.query(to_context, '/aether/transmigrate',
                           { content: note[:content], tags: note[:tags], links: note[:links],
                             source_context: AetherLink.own_name })
        end
        return local_result.merge(transmigrated_to: to_context, transmigrated_count: notes.size)
      end

      # Cross-context: spawn a task on remote context
      if create_task_in
        result = AetherLink.query(create_task_in, '/aether/create_task',
                                  { title: query, plan: query, source_context: AetherLink.own_name })
        return result || { error: "Context '#{create_task_in}' unreachable" }
      end

      query_tokens = Mnemosyne.tokenize(query.to_s)

      sql = if from_task
              task_tag = "task_#{from_task}"
              'WHERE tags LIKE ?'
            else
              'WHERE tags NOT LIKE ?'
            end

      params = from_task ? ["%task_#{from_task}%"] : ['%task_%']
      if query_tokens.any?
        clauses = %w[content tags links].map { |f| query_tokens.map { |kw| "#{f} LIKE ?" }.join(' OR ') }.join(' OR ')
        sql += " AND (#{clauses})"
        params += query_tokens.flat_map { |kw| ["%#{kw}%"] * 3 }
      end

      notes = Mnemosyne.db.execute("SELECT id, content, tags, links, created_at FROM project_notes #{sql} ORDER BY created_at DESC", params)
        .map { |n| n.transform_keys!(&:to_sym) }

      scored = notes.map do |note|
        score = 0
        if query_tokens.any?
          score += 4 * (query_tokens & Mnemosyne.tokenize(note[:content])).size
          score += 3 * (query_tokens & Mnemosyne.tokenize(note[:tags])).size
          score += 2 * (query_tokens & Mnemosyne.tokenize(note[:links])).size
        else
          score = note[:created_at] ? Time.parse(note[:created_at]).to_f % 100 : 1
        end
        { **note, score: }
      end
        .select { |n| n[:score].positive? }
        .sort_by { |n| -n[:score] }
        .take(limit)

      task_summary = if from_task
                       task = Mnemosyne.get_task(from_task)
                       if task
                         results = JSON.parse(task[:step_results] || '{}') rescue {}
                         { id: task[:id], title: task[:title], status: task[:status],
                           current_step: task[:current_step],
                           plan: task[:plan].to_s.truncate(300),
                           phase_results: results.map { |s, r| [s, r.to_s.truncate(150)] }.to_h }
                       end
                     end

      # Aegis subscription — merge the other task's tag into current Aegis orientation
      raw_tags = Mnemosyne.aegis[:tags] || []
      aegis_tags = raw_tags.is_a?(String) ? raw_tags.split(',').map(&:strip) : raw_tags.dup
      task_tag = "task_#{from_task}"
      if subscribe && from_task
        aegis_tags |= [task_tag]
        Mnemosyne.unveil_aegis(tags: aegis_tags)
      elsif unsubscribe && from_task
        aegis_tags -= [task_tag]
        Mnemosyne.unveil_aegis(tags: aegis_tags)
      end
      subscribed = aegis_tags.include?(task_tag) if from_task

      { notes: scored, task_summary: task_summary, subscribed: subscribed }.compact
    end

    end
  end
end
