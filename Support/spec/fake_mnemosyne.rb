class FakeMnemosyne
  VALID_STATUSES = %w[pending active failed completed paused cancelled invalid].freeze

  def initialize
    @tasks = {}
    @logs = {}
    # Initialize a default task with max_loops
    @tasks[1] = { 'id' => 1, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
  end

  # Class methods to match real Mnemosyne interface
  class << self
    attr_accessor :tasks, :logs
  end

  # Initialize class variables
  self.tasks = {}
  self.logs = {}

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
    task_state(task_id)['max_loops'] || 10
  end

  # Stub method for temperature setting
  def set_aegis_temperature(temperature)
    # No-op for fake implementation
  end

  def manage_tasks(params)
    params = params.transform_keys(&:to_sym)
    action = params[:action].to_sym || :list

    case action
    when :list
      tasks = @tasks.values
      tasks = tasks.select { |t| t['parent_task_id'] == params[:parent_task_id] } if params[:parent_task_id]
      tasks.map { |t| t.transform_keys(&:to_sym) }
    when :update
      task_id = params[:id]
      @tasks[task_id] ||= { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }

      # Update status with validation
      if params[:status]
        raise "Invalid state: #{params[:status]}" unless VALID_STATUSES.include?(params[:status])
        @tasks[task_id]['status'] = params[:status]
        # Also update class-level storage for real interface
        self.class.tasks[task_id] = @tasks[task_id].dup
      end

      # Update progress
      if params[:progress]
        @tasks[task_id][:progress] = params[:progress]
        self.class.tasks[task_id] = @tasks[task_id].dup if self.class.tasks[task_id]
      end

      # Update max_loops
      if params[:max_loops]
        @tasks[task_id][max_loops] = params[max_loops]
        self.class.tasks[task_id] = @tasks[task_id].dup if self.class.tasks[task_id]
      end

      # Update current_step
      if params[:current_step]
        @tasks[task_id]['current_step'] = params[:current_step]
        self.class.tasks[task_id] = @tasks[task_id].dup if self.class.tasks[task_id]
      end

      # Update step_results
      if params[:step_results]
        @tasks[task_id]['step_results'] = params[:step_results]
        self.class.tasks[task_id] = @tasks[task_id].dup if self.class.tasks[task_id]
      end

      # Log handling
      if params[:log]
        @logs[task_id] ||= []
        @logs[task_id] << params[:log]
        @tasks[task_id]['logs'] ||= []
        @tasks[task_id]['logs'] << params[:log]
        self.class.logs[task_id] = @logs[task_id].dup if self.class.logs[task_id]
      end

      { 'ok' => true }
    when :create
      task_id = rand(1000)
      @tasks[task_id] = {
        'id' => task_id,
        'status' => 'pending',
        'progress' => 0,
        'max_loops' => params[:max_loops] || 10,
        'parent_task_id' => params[:parent_task_id],
        'title' => params[:title],
        'plan' => params[:plan],
        'max_steps' => params[:max_steps]
      }
      self.class.tasks[task_id] = @tasks[task_id].dup
      # Return symbol-keyed hash for consistency with real Mnemosyne
      { ok: true, id: task_id }
    else
      []
    end
  end

  # Real Mnemosyne interface compatibility
  def self.get_task(task_id)
    task = @tasks[task_id] || { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
    task.transform_keys(&:to_sym)
  end

  def self.update_task(task_id, **fields)
    @tasks[task_id] ||= { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
    fields.each { |key, value| @tasks[task_id][key.to_s] = value }
    get_task(task_id)
  end

  # Backward compatibility for tests
  def task_state(task_id)
    self.class.get_task(task_id).transform_keys(&:to_s)
  end

  def task_logs(task_id)
    @logs[task_id] || []
  end

  def max_loops(task_id = nil)
    return 10 if task_id.nil?
    @tasks[task_id]['max_loops'] || 10
  end
  
  def get_task(task_id)
    task = @tasks[task_id]
    return nil unless task
    
    # Convert to symbol keys for consistent access
    task.transform_keys(&:to_s).transform_keys(&:to_sym)
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