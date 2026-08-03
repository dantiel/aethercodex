# frozen_string_literal: true
require_relative '../instrumentarium/metaprogramming_utils'
using TokenExtensions



class Mnemosyne
  # TaskLedger — task ledger
  class TaskLedger
    class << self
        def create_task(title:, plan:, workflow_type: 'full', parent_task_id: nil)
          puts "CREATE TASK #{title}:#{plan} (workflow: #{workflow_type})"
          x = Mnemosyne.db.execute 'INSERT INTO tasks (title, plan, status, workflow_type, parent_task_id) VALUES (?, ?, ?, ?, ?)',
                         [title, plan, 'pending', workflow_type, parent_task_id]
          # puts "x=#{x}, id=#{Mnemosyne.db.last_insert_row_id}"
          { ok: true, id: Mnemosyne.db.last_insert_row_id }
        end


        # Get max steps based on workflow type

        def max_steps_for_workflow(workflow_type)
          case workflow_type.to_s
          when 'simple' then 3
          when 'analysis' then 5
          else 10 # full
          end
        end


        # Get step name mapping for workflow type

        def step_name(workflow_type, step_number)
          case workflow_type.to_s
          when 'simple'
            case step_number
            when 0 then 'Initium'
            when 1 then 'Solve'
            when 2 then 'Coagula'
            when 3 then 'Validatio'
            else "Step #{step_number}"
            end
          when 'analysis' # TODO: hermetical name for this workflow type
            case step_number
            when 0 then 'Initium'
            when 1 then 'Research'
            when 2 then 'Plan'
            when 3 then 'Analyze'
            when 4 then 'Synthesize'
            when 5 then 'Report'
            else "Step #{step_number}"
            end
          else # full
            case step_number
            when 0 then 'Initium'
            when 1 then 'Nigredo'
            when 2 then 'Albedo'
            when 3 then 'Citrinitas'
            when 4 then 'Rubedo'
            when 5 then 'Solve'
            when 6 then 'Coagula'
            when 7 then 'Test'
            when 8 then 'Purificatio'
            when 9 then 'Validatio'
            when 10 then 'Documentatio'
            else "Step #{step_number}"
            end
          end
        end


        # Get subtasks for a parent task

        def get_subtasks(parent_task_id)
          Mnemosyne.db.execute('SELECT * FROM tasks WHERE parent_task_id = ? ORDER BY created_at',
                     [parent_task_id])
            .map do |t|
            t.transform_keys!(&:to_sym)
          end
        end


        # Update subtask results for a parent task

        def update_subtask_results(parent_task_id, subtask_id, result)
          task = get_task parent_task_id
          return unless task

          subtask_results = JSON.parse(task[:subtask_results] || '{}')
          subtask_results[subtask_id.to_s] = result

          Mnemosyne.db.execute 'UPDATE tasks SET subtask_results = ? WHERE id = ?',
                     [subtask_results.to_json, parent_task_id]
        end


        # Update the Aegis summary dynamically

        def get_task(task_id)
          task = Mnemosyne.db.execute('SELECT * FROM tasks WHERE id = ? LIMIT 1', [task_id]).first
          task&.transform_keys!(&:to_sym)
          task[:status] ||= 'pending' if task
          task
        end


        # Update task

        def update_task(task_id, **fields)
          fields.compact!
          x = Mnemosyne.db.execute "UPDATE tasks SET #{fields.map { |key, _| "#{key} = ?" }.join ', '}, " \
                         'updated_at = CURRENT_TIMESTAMP WHERE id = ?', [*fields.values, task_id]
          puts "UPDATE_TASK=#{x.inspect}"
          get_task task_id
        end



        def remove_task(id)
          manage_tasks action: 'delete', id:
        end


        # Task ledger with states, progress, and dynamic plan updates

        def manage_tasks(params)
          params.transform_keys!(&:to_sym)
          action = params[:action].to_sym || :list
          case action
          when :create
            begin
              workflow_type = params[:workflow_type] || 'full'
              parent_task_id = params[:parent_task_id]
              x = Mnemosyne.db.execute 'INSERT INTO tasks (title, plan, updates, status, current_step, workflow_type, parent_task_id) VALUES ' \
                             '(?,?,?,?,?,?,?)', [params[:title], params[:plan], '[]', 'pending', 0, workflow_type, parent_task_id]
              { 'ok' => true,
                'id' => Mnemosyne.db.last_insert_row_id,
                title: params[:title],
                plan: params[:plan],
                workflow_type: workflow_type,
                parent_task_id: parent_task_id }
            rescue SQLite3::Exception => e
              warn "Task creation failed: #{e.message}"
              { 'ok' => false, 'error' => e.message }
            end
          when :update
            if params[:log]
              # Append to existing logs
              current_logs = Mnemosyne.db.execute('SELECT logs FROM tasks WHERE id = ?', [params[:id]]).first
              logs = if current_logs && current_logs['logs'] && !current_logs['logs'].empty?
                       JSON.parse current_logs['logs']
                     else
                       []
                     end
              logs << { timestamp: Time.now.to_f, message: params[:log] }
              Mnemosyne.db.execute 'UPDATE tasks SET logs = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                         [logs.to_json, params[:id]]
            end
            if params[:step_results]
              # Update step results
              Mnemosyne.db.execute 'UPDATE tasks SET step_results = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                         [params[:step_results], params[:id]]
            end
            if params[:status]
              Mnemosyne.db.execute 'UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                         [params[:status], params[:id]]
            end
            if params[:current_step]
              Mnemosyne.db.execute 'UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                         [params[:current_step], params[:id]]
            end
            if params[:tool_calls_json]
              Mnemosyne.db.execute 'UPDATE tasks SET tool_calls_json = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                         [params[:tool_calls_json], params[:id]]
            end
            { ok: true }
          when :activate
            Mnemosyne.db.execute 'UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                       ['active', params[:id]]
            { ok: true }
          when :update_plan
            updates = JSON.parse(Mnemosyne.db.execute('SELECT updates FROM tasks WHERE id = ?',
                                            [params[:id]]).first['updates']) || []
            updates << { step: params[:current_step], plan: params[:plan], timestamp: Time.now.to_s }
            Mnemosyne.db.execute 'UPDATE tasks SET plan = ?, updates = ?, current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                       [params[:plan], updates.to_json, params[:current_step], params[:id]]
            { ok: true }
          when :advance_step
            Mnemosyne.db.execute 'UPDATE tasks SET current_step = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
                       [params[:current_step], params[:id]]
            { ok: true }
          when :delete
            Mnemosyne.db.execute 'DELETE FROM tasks WHERE id = ?', [params[:id]]
            { ok: true }
          else # list
            rows = Mnemosyne.db.execute 'SELECT * FROM tasks ORDER BY created_at DESC'
            rows.map { |r| r.transform_keys!(&:to_sym) }

            if params[:parent_task_id]
              rows = rows.filter { |task| params[:parent_task_id] == task[:parent_task_id] }
            end

            max_tokens = 1111
            token_count = 0
            included_rows = []

            rows.each do |row|
              row_tokens = row.to_json.tok_len

              if row_tokens > max_tokens
                row[:message] = row[:message].to_s.gsub(/\n\s*```(\w*).*?\n\s*```\s*\n/m,
                                                        '```\\1[CONTENT EXPIRED]```')
                row_tokens = row.to_json.tok_len
                next if row_tokens > max_tokens
              end

              break if token_count + row_tokens > max_tokens

              included_rows << row
              token_count += row_tokens
            end

            rows = included_rows
            # puts "ROWS=#{rows}"
            rows
          end
        end


        # Recall entries by tags or prompt


        # Recall entries by tags or prompt

    end
  end
end
