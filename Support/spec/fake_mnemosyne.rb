class FakeMnemosyne
  VALID_STATUSES = %w[pending active failed completed paused cancelled invalid].freeze

  def initialize
    @tasks = {}
    @logs = {}
    # Initialize a default task with max_loops
    @tasks[1] = { 'id' => 1, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
  end

  # Retrieve task state with max_loops tracking
  def task_state(task_id)
    @tasks[task_id] || { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
  end

  # Retrieve task logs
  def task_logs(task_id)
    @logs[task_id] || []
  end

  # Get current max_loops for a task
  def max_loops(task_id)
    (@tasks[task_id] || { 'max_loops' => 10 })['max_loops']
  end

  def manage_tasks(params)
    params = params.transform_keys(&:to_s)

    case params['action']
    when 'list'
      tasks = @tasks.values
      tasks = tasks.select { |t| t['parent_task_id'] == params['parent_task_id'] } if params['parent_task_id']
      tasks.map { |t| t.transform_keys(&:to_sym) }
    when 'update'
      task_id = params['id']
      @tasks[task_id] ||= { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }

      # Update status with validation
      if params['status']
        raise "Invalid state: #{params['status']}" unless VALID_STATUSES.include?(params['status'])
        @tasks[task_id]['status'] = params['status']
      end

      # Update progress
      @tasks[task_id]['progress'] = params['progress'] if params['progress']

      # Update max_loops
      @tasks[task_id]['max_loops'] = params['max_loops'] if params['max_loops']

      # Log handling
      if params['log']
        @logs[task_id] ||= []
        @logs[task_id] << params['log']
        @tasks[task_id]['logs'] ||= []
        @tasks[task_id]['logs'] << params['log']
      end

      { 'ok' => true }
    when 'create'
      task_id = rand(1000)
      @tasks[task_id] = {
        'id' => task_id,
        'status' => 'pending',
        'progress' => 0,
        'max_loops' => params['max_loops'] || 10,
        'parent_task_id' => params['parent_task_id'],
        'title' => params['title'],
        'plan' => params['plan'],
        'max_steps' => params['max_steps']
      }
      { 'ok' => true, 'id' => task_id }
    else
      []
    end
  end

  def task_state(task_id)
    @tasks[task_id] || {}
  end

  def task_logs(task_id)
    @logs[task_id] || []
  end

  def max_loops(task_id)
    @tasks[task_id]['max_loops'] || 10
  end
  
  def get_task(task_id)
    task = @tasks[task_id]
    return nil unless task
    
    # Convert to symbol keys for consistent access
    task.transform_keys(&:to_sym)
  end

  def recall_notes(query, limit: 10)
    [
      { id: 1, content: "Test note for #{query}", tags: ["test"], links: [], created_at: Time.now }
    ].first(limit)
  end

  def remember(content, tags: nil, links: nil, meta: nil)
    task_id = rand(1000)
    @tasks[task_id] = {
      'id' => task_id,
      'status' => 'pending',
      'progress' => 0,
      'max_loops' => 10,
      'description' => content
    }
    task_id
  end
end