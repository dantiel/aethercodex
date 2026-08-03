# frozen_string_literal: true

# Fake Mnemosyne for testing MagnumOpusEngine — mirrors the real interface
class FakeMnemosyne
  VALID_STATUSES = %w[pending active failed completed paused cancelled invalid].freeze

  # Class-level storage for backward compatibility with older tests
  class << self
    attr_accessor :tasks, :logs
  end
  self.tasks = {}
  self.logs = {}

  attr_reader :tasks, :logs, :notes, :aegis_temperature

  def initialize
    @tasks = {}
    @logs = {}
    @notes = []
    @aegis_temperature = 1.0
    # Initialize a default task
    @tasks[1] = task_template(1, status: 'pending')
    # Sync to class storage for backward compatibility
    self.class.tasks[1] = @tasks[1].dup
  end

  # ── Task CRUD ──────────────────────────────────────────────

  def get_task(task_id)
    task = @tasks[task_id]
    return nil unless task
    task.transform_keys(&:to_s).transform_keys(&:to_sym)
  end

  def manage_tasks(params)
    params = params.transform_keys(&:to_sym)
    action = (params[:action] || 'list').to_sym

    case action
    when :create
      task_id = params[:id] || next_id
      @tasks[task_id] = task_template(
        task_id,
        title:          params[:title] || 'Untitled',
        plan:           params[:plan] || '',
        status:         'pending',
        workflow_type:  params[:workflow_type] || 'full',
        parent_task_id: params[:parent_task_id]
      )
      { ok: true, id: task_id, title: params[:title], plan: params[:plan] }

    when :update
      task_id = params[:id]
      @tasks[task_id] ||= task_template(task_id)
      t = @tasks[task_id]

      t['status']       = params[:status]       if params[:status]
      t['current_step'] = params[:current_step] if params.key?(:current_step)
      t['step_results'] = params[:step_results] if params[:step_results]
      t['title']        = params[:title]        if params[:title]
      t['plan']         = params[:plan]         if params[:plan]
      t['description']  = params[:description]  if params.key?(:description)
      t['tool_calls_json'] = params[:tool_calls_json] if params[:tool_calls_json]
      t['parent_task_id'] = params[:parent_task_id] if params.key?(:parent_task_id)
      t['workflow_type'] = params[:workflow_type] if params[:workflow_type]
      t['progress']      = params[:progress]      if params.key?(:progress)
      t['max_loops']     = params[:max_loops]     if params.key?(:max_loops)

      # Sync to class storage for backward compatibility
      self.class.tasks[task_id] = t.dup

      if params[:log]
        @logs[task_id] ||= []
        @logs[task_id] << { timestamp: Time.now.to_f, message: params[:log] }
        t['log'] ||= []
        t['log'] << { timestamp: Time.now.to_f, message: params[:log] }
      end

      { ok: true }

    when :list
      tasks = @tasks.values
      if params[:parent_task_id]
        tasks = tasks.select { |t| t['parent_task_id'] == params[:parent_task_id] }
      end
      tasks.map { |t| t.transform_keys(&:to_sym) }

    when :delete
      @tasks.delete(params[:id])
      { ok: true }

    else
      []
    end
  end

  # ── Notes ──────────────────────────────────────────────────

  def create_note(content:, links: [], tags: [])
    id = @notes.size + 1
    @notes << { id: id, content: content, links: links, tags: tags, created_at: Time.now }
    { ok: true, id: id }
  end

  def recall_notes(query = '', limit: 10)
    @notes.select { |n| n[:content].to_s.include?(query.to_s) }.first(limit)
  end

  # ── Aegis ──────────────────────────────────────────────────

  def set_aegis_temperature(temp)
    @aegis_temperature = temp
  end

  def aegis_summary
    ''
  end

  # ── Metempsychosis stub ────────────────────────────────────

  def metempsychosis(query:, from_task: nil, limit: 5, subscribe: false, unsubscribe: false,
                     from_context: nil, to_context: nil, create_task_in: nil)
    notes = if from_task
              @notes.select { |n| n[:tags]&.include?("task_#{from_task}") }.first(limit)
            else
              @notes.first(limit)
            end
    { notes: notes, task_summary: from_task ? get_task(from_task) : nil }
  end

  # ── Tool call helpers ──────────────────────────────────────

  def format_history_tool_calls(tool_calls, _indent = 0)
    "Tool calls: #{tool_calls.inspect}"
  end

  def safe_parse_json(json_string, default = {})
    return default if json_string.nil? || json_string.empty?
    JSON.parse(json_string)
  rescue JSON::ParserError
    default
  end

  def truncate_tool_calls_by_priority(tool_calls)
    tool_calls
  end

  # ── Backward compatibility for existing tests ──────────────

  def task_state(task_id)
    t = @tasks[task_id] || task_template(task_id)
    t.transform_keys(&:to_s)
  end

  # Class method for backward compatibility
  def self.get_task(task_id)
    task = @tasks[task_id] || { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10, 'current_step' => 0 }
    task.transform_keys(&:to_sym)
  end

  def self.update_task(task_id, **fields)
    @tasks[task_id] ||= { 'id' => task_id, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10 }
    fields.each { |key, value| @tasks[task_id][key.to_s] = value }
    get_task(task_id)
  end

  def task_logs(task_id)
    (@logs[task_id] || []).map { |e| e[:message] || e['message'] }
  end

  def max_loops(task_id = nil)
    return 10 if task_id.nil?
    (@tasks[task_id] && @tasks[task_id]['max_loops']) || 10
  end

  def remember(content, tags: nil, links: nil, meta: nil)
    create_note(content: content, tags: tags, links: links)[:id]
  end

  private

  def next_id
    (@tasks.keys.max || 0) + 1
  end

  def task_template(id, title: 'Test Task', plan: '', status: 'pending', workflow_type: 'full', parent_task_id: nil)
    {
      'id'             => id,
      'title'          => title,
      'plan'           => plan,
      'status'         => status,
      'workflow_type'  => workflow_type,
      'parent_task_id' => parent_task_id,
      'current_step'   => 0,
      'step_results'   => '{}',
      'description'    => nil,
      'log'            => [],
      'tool_calls_json' => nil,
      'created_at'     => Time.now.to_s,
      'updated_at'     => Time.now.to_s,
      'max_loops'      => 10
    }
  end
end