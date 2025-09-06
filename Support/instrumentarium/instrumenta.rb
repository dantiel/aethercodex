# frozen_string_literal: true


require_relative '../magnum_opus/magnum_opus_engine'
require_relative '../argonaut/argonaut'
require_relative '../mnemosyne/mnemosyne'
require_relative '../oracle/oracle'
require_relative 'horologium_aeternum'
require_relative 'prima_materia'
require_relative '../instrumentarium/scriptorium'



# Instrumenta: The Atlantean tool collection for precise code plane operations.
# Current-state focused tool schema optimized for efficient AI execution.
class Instrumenta
  PRIMA_MATERIA = PrimaMateria.new


  def initialize
    @prima_materia = PRIMA_MATERIA
  end
  

  class << self
    def instrumenta_schema = PRIMA_MATERIA.instrumenta_schema
    def schema = PRIMA_MATERIA.schema
    def tools = PRIMA_MATERIA.tools
    def handle(...) = PRIMA_MATERIA.handle(...)


    def reject(*tool_names)
      filtered_prima = PRIMA_MATERIA.reject(*tool_names)
      # Return a new Instrumenta instance that wraps the filtered PrimaMateria
      filtered_instrumenta = Instrumenta.new
      filtered_instrumenta.instance_variable_set :@prima_materia, filtered_prima
      filtered_instrumenta
    end
  end
  

  # Delegate all methods to the wrapped PrimaMateria instance
  def method_missing(method_name, ...)
    if @prima_materia.respond_to? method_name
      @prima_materia.send(method_name, ...)
    else
      super
    end
  end


  def respond_to_missing?(method_name, include_private = false)
    @prima_materia.respond_to?(method_name) || super
  end
end


def instrument(...) = Instrumenta::PRIMA_MATERIA.add_instrument(...)


# --- Register All Tools ---
instrument :read_file,
           description: 'Read a file (optionally a line range).',
           params: { path:  { type: String, required: true, minLength: 1 },
                     range: { type:     Array,
                              required: false,
                              items:    { type: 'integer', minimum: 0, maximum: 10_000 },
                              minItems: 2,
                              maxItems: 2 } },
           returns: { content: String, error: String } do |path:, range: nil|
  raise 'Denied path' if PrimaMateria::DENY_PATHS.any? { |re| re.match? path }

  uuid = HorologiumAeternum.file_reading path, range
  result = Argonaut.read path, range
  bytes_read = result[:content]&.bytesize || 0
  HorologiumAeternum.file_read_complete(path, bytes_read, range, result[:content], uuid:)
  result
rescue StandardError => e
  HorologiumAeternum.file_read_fail(path, e.message, range, uuid:)
  { error: e.message.to_s }
end

# When reasoning is invoked, tools are excluded to enable advanced reasoning capabilities
instrument :oracle_conjuration,
           description: <<~DESC,
             Invoke advanced reasoning for complex problem-solving. This conjuration provides
             only the final prompt and context to the reasoning model - no tool execution is possible.
             
             **REQUIRED PREPARATION**: Before invocation, you MUST:
               - Perform comprehensive research using all available tools
               - Gather complete file contents and structural analysis
               - Prepare detailed reasoning plan and context
               - Include all relevant information in the prompt
               - Put explanations and thoughts in the prompt
               
               **CRITICAL**: In reasoning mode, you CANNOT call any tools including oracle_conjuration itself
               
               The reasoning model receives only your prepared prompt and context.
               Previous tool results (such as file reads, overviews, previous conjuration results)
               are automatically passed in the context.
           DESC
           params: { prompt:  { type:        String,
                                required:    true,
                                description: 'The input prompt for reasoning.' },
                     context: { type:        Object,
                                required:    false,
                                description: 'Context object to pass through to oracle' } },
           timeout: 600,
           returns: { reasoning: String, content: String, context: Object } do |prompt:, context: nil|
  # Add reasoning flag to context for proper system prompt selection
  context_with_reasoning = context ? context.merge(reasoning: true) : { reasoning: true }
  
  params = {
    prompt:  prompt,
    context: context_with_reasoning,
  }
  HorologiumAeternum.oracle_conjuration prompt
  
  puts "CONJURATION TOOL CONTEXT=#{context.inspect.truncate 200}"

  # For DeepSeek reasoning, we must NOT pass any tools to enable advanced reasoning
  # The reasoning model cannot use tools, so we provide empty tools array
  puts "[CONJURATION][DEBUG]: Starting conjuration with params: #{params.inspect.truncate(200)}"
  # For reasoning, we need to pass empty tools object, not nil
  result = Aetherflux.channel_oracle_conjuration params, tools: nil
  puts "[CONJURATION][DEBUG]: Aetherflux result: #{result.inspect.truncate(300)}"

  if result[:error]
    puts "[CONJURATION][ERROR]: #{result[:error]}"
    raise result[:error]
  end

  if result[:status] == :success && result[:response]
    reasoning = result[:response][:reasoning]
    answer = result[:response][:answer]

    puts "[CONJURATION][DEBUG]: Success - reasoning: #{reasoning.to_s.truncate(100)}, answer: #{answer.to_s.truncate(100)}"

    unless reasoning.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Reasoning', reasoning
    end
    unless answer.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Answer', answer
    end
  else
    puts "[CONJURATION][DEBUG]: Failed - status: #{result[:status]}, response: #{result[:response].inspect.truncate(200)}"
    reasoning = nil
    content = nil
  end

  { reasoning:, content: }
rescue StandardError => e
  { error: "Reasoning failed: #{e.message}" }
end


instrument :run_command,
           description: <<~DESC,
             Run an allowed shell command in project base dir. Allowed: `rspec`, `rubocop`,
             `git`, `ls`, `cat`, `mkdir`, `$TM_QUERY`, `echo`, `grep`, `bundle exec ruby`,
             `bundle exec irb`, `ruby`, `irb`, `cd`, `curl`, `ag`. Please suggest to add more
             cmds to this list if you like.
           DESC
           params: { cmd: { type: String, required: true } },
           returns: { ok:          Boolean,
                      exit_status: Integer,
                      result:      String,
                      error:       String } do |cmd:|
  next { error: 'Blocked command' } unless PrimaMateria::ALLOW_CMDS.any? { |re| cmd =~ re }

  uuid = HorologiumAeternum.command_executing cmd

  begin
    project_root = Argonaut.project_root
    run_command_env = Dotenv.parse "#{project_root}/.env.run_command", overwrite: true

    env_vars = run_command_env.merge({ 'BUNDLE_GEMFILE' => '' })

    stdout, stderr, status = Open3.capture3 env_vars, cmd, chdir: project_root
    out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
    HorologiumAeternum.command_completed(cmd, out.length, out, status.exitstatus, uuid:)

    # Use Scriptorium HTML utils for proper escaping
    escaped_out = Scriptorium.escape_html(out)

    { ok: true, exit_status: status.exitstatus, result: "Command output: #{escaped_out}" }
  rescue StandardError => e
    { error: "Command error: #{e.message}" }
  end
end


instrument :create_file,
           description: 'Create (or overwrite) a file with given content.',
           params: { path:      { type: String, required: true },
                     content:   { type: String, required: true },
                     overwrite: { type: Boolean, required: false, default: false } },
           returns: { ok: Boolean, error: String } do |path:, content:, overwrite: false|
  next { error: 'Denied path' } if PrimaMateria::DENY_PATHS.any? { |re| re.match? path }

  bytes = content.bytesize
  uuid = HorologiumAeternum.file_creating path, bytes

  full = File.join Argonaut.project_root, path
  
  next { error: "File exists: #{path} (set overwrite:true)" } if File.exist?(full) && !overwrite

  Argonaut.write path, content
  HorologiumAeternum.file_created(path, bytes, content, uuid:)
  { ok: true }
rescue StandardError => e
  { error: e.message }
end


instrument :rename_file,
           description: 'Rename a file with given content.',
           params: { from: { type: String, required: true },
                     to:   { type: String, required: true } },
           returns: { ok: Boolean, error: String } do |from:, to:|
  next { error: 'Denied path' } if [from, to].any? do |p|
    PrimaMateria::DENY_PATHS.any? do |re|
      re.match? p
    end
  end

  uuid = HorologiumAeternum.file_renaming from, to
  Argonaut.rename from, to
  HorologiumAeternum.file_renamed(from, to, uuid:)
  { ok: true }
rescue StandardError => e
  { error: e.message }
end


instrument :recall_history,
           description: 'Retrieve notes from Mnemosyne. Without a query just yields last.',
           params: { query: { type: String, required: false },
                     limit: { type: Integer, required: false, default: 3 } },
           returns: { notes: Array, error: String } do |query: '', limit: 7|
  uuid = HorologiumAeternum.memory_searching query, limit
  result = { notes: Mnemosyne.search(query, limit: limit) }
  HorologiumAeternum.memory_found(query, result[:notes]&.length || 0, result[:notes].inspect,
                                  uuid:)
  result
rescue StandardError => e
  puts "[PrimaMateria][ERROR]: #{e.inspect}"
  { error: e }
end


instrument :tell_user,
           description: 'If you wish to inform the user mid-process.',
           params: { message: { type: String, required: true },
                     level:   { type: String, required: false, enum: %w[info warn] } },
           returns: { say: Hash, error: String } do |message:, level: 'info'|
  HorologiumAeternum.info_message message
  { say: { level: level, message: message } }
end


# TODO match by ID, so it can be easily accessed from file_overview tool
instrument :recall_notes,
           description: 'Recall notes from Mnemosyne by tags, content or context. ' \
                        'Uses fuzzy matching with enhanced scoring: content (4x), ' \
                        'tags (3x), links (2x), path matches (+5). Current-state only.',
           params: { query: { type: String, required: false },
                     limit: { type: Integer, required: false, default: 3 } },
           returns: { notes: Array, error: String } do |query: '', limit: 7|
  # Use optimized parameters to prevent context bloat
  result = { notes: Mnemosyne.recall_notes(query, limit: limit, max_content_length: 555) }
  HorologiumAeternum.notes_recalled query, limit, result[:notes]
  result
rescue StandardError => e
  { error: e.message }
end


instrument :file_overview,
           description: <<~DESC,
             Fetch file information with symbolic parsing. Returns lightweight metadata:
             note count, tags, 50-char excerpt. Enhanced symbolic analysis shows AI's
             structural view with classes, methods, constants, and navigation hints.
           DESC
           params: { path: { type: String, required: true } },
           returns: { metadata: Hash, error: String } do |path:|
  path = Argonaut.relative_path path

  # Use optimized parameters to prevent context bloat
  results = Argonaut.file_overview(path: path, max_notes: 3, max_content_length: 333)
  raise results[:error] unless results[:error].nil?

  HorologiumAeternum.file_overview path, results
  results
rescue StandardError => e
  puts "[PRIMA MATERIA][ERROR]: #{e.inspect}"
  { error: "File overview for #{path} failed: #{e.message || e.error}" }
end


instrument :remember,
           description: <<~DESC,
             Store current-state note: structure, patterns, architecture only.
             Never historical changes or timelines. Links enable path-based
             relevance scoring in recall_notes. Purge outdated notes regularly.
           DESC
           params: { id:      { type: Integer, required: false },
                     content: { type: String, required: true },
                     links:   { type: Array, required: false },
                     tags:    { type: Array, required: false } },
           returns: { ok:    Boolean,
                      error: String } do |content:, id: nil, links: nil, tags: nil|
  note = { content: content, links: links, tags: tags }
  if id.nil?
    Mnemosyne.create_note(**note)
    uuid = HorologiumAeternum.note_added note
  else
    Mnemosyne.update_note id, **note
    HorologiumAeternum.note_updated(**note, uuid:)
  end

  { ok: true }
rescue StandardError => e
  puts "[PrimaMateria][ERROR]: #{e.inspect}"
  { error: e }
end


instrument :remove_note,
           description:  'Remove a note by id.',
           params: { id: { type: Integer, required: true } },
           returns: { ok: Boolean, error: String } do |id:|
  note = Mnemosyne.get_note id
  Mnemosyne.remove_note id
  HorologiumAeternum.note_removed(note)
  { ok: true }
end


instrument :patch_file,
           description: <<~DESC,
             Request to apply PRECISE, TARGETED modifications to an existing file by searching
             for specific sections of content and replacing them. This tool is for SURGICAL EDITS
             ONLY - specific changes to existing code.

             You can perform multiple distinct search and replace operations within a single
             `patch_file` call by providing multiple SEARCH/REPLACE blocks in the `diff`
             parameter. This is the preferred way to make several targeted changes efficiently.

             The SEARCH section must exactly match existing content including whitespace and
             indentation.

             If you're not confident in the exact content to search for, use the `read_file` tool
             first to get the exact content.

             When applying the diffs, be extra careful to remember to change any closing brackets
             or other syntax that may be affected by the diff farther down in the file.

             ALWAYS make as many changes in a single 'patch_file' request as possible using
             multiple SEARCH/REPLACE blocks.

             If a patch fails it may be that the line number was too wrong.

             ### Diff Format:
             ```
             <<<<<<< SEARCH
             :start_line: (required) The line number of original content where the search block begins.
             -------
             [exact content to find including whitespace]
             =======
             [new content to replace with]
             >>>>>>> REPLACE
             ```

             ### Example 1: Single Edit
             ```
             <<<<<<< SEARCH
             :start_line:116
             -------
             def calculate_total(items):
                 total = 0
                 for item in items:
                     total += item
                 return total
             =======
             def calculate_total(items):
                 """Calculate total with 10% markup"""
                 return sum(item * 1.1 for item in items)
             >>>>>>> REPLACE
             ```

             ### Example 2: Multiple Edits
             ```
             <<<<<<< SEARCH
             :start_line:10
             -------
             def calculate_total(items):
                 sum = 0
             =======
             def calculate_sum(items):
                 sum = 0
             >>>>>>> REPLACE

             <<<<<<< SEARCH
             :start_line:42
             -------
                 total += item
                 return total
             =======
                 sum += item
                 return sum
             >>>>>>> REPLACE
             ```
           DESC
           params: { path: { type: String, required: true },
                     diff: { type: String, required: true } },
           returns: { ok: Boolean, error: String } do |path:, diff:|
  next { error: 'missing :path or :diff' } unless path && diff

  diff_lines = diff.lines.count
  uuid = HorologiumAeternum.file_patching path, diff, diff_lines

  next { error: 'Diff too big' } if PrimaMateria::MAX_DIFF < diff.lines.count

  old_content, new_content = Argonaut.patch path, diff

  HorologiumAeternum.file_patched(path, old_content, new_content, uuid:)
  { ok: true }
rescue StandardError => e
  HorologiumAeternum.file_patched_fail(path, e.message, diff, uuid:)
  { error: "patch failed: #{e.message}" }
end


instrument :aegis,
           description:  <<~DESC,
             Maintain active context from Mnemosyne. Returns scored notes with
             current-state focus. Summary required for orientation refinement.
           DESC
           params: { tags:        { type: Array, required: false, items: { type: 'string' } },
                     summary:     { type:        String,
                                    required:    false,
                                    description: 'Dynamic summary update without altering ' \
                                                 'tags. Required for every invocation.' },
                     temperature: { type:        Number,
                                    required:    false,
                                    description: 'Optional parameter to fine-tune the Aegis ' \
                                                 'state responsiveness.' } },
           returns: { aegis_notes:       Array,
                      aegis_orientation: Hash,
                      error:             String } do |tags: nil, summary: '', temperature: nil|
  notes = Mnemosyne.unveil_aegis(tags:, summary:, temperature:)

  HorologiumAeternum.aegis_unveiled tags, summary, temperature, notes

  { aegis_notes: notes, aegis_orientation: Mnemosyne.aegis }
rescue StandardError => e
  { error: "Aegis failed: #{e.message}" }
end


instrument :create_task,
           description: 'Generate a task for complex prompts with fields for plan and title.',
           params: { title: { type:        String,
                              required:    true,
                              description: 'The title of the plan.' },
                     plan:  { type:        String,
                              required:    true,
                              description: 'The task execution plan.' } },
           returns: { id: Integer, error: String } do |title:, plan:|
  engine = MagnumOpusEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux

  result = engine.create_task(title:, plan:, workflow_type: 'full')

  uuid = HorologiumAeternum.task_created(**result)

  result
rescue StandardError => e
  HorologiumAeternum.system_error('Error Creating Task', message: e.message, uuid:)

  { error: e.message }
end


instrument :execute_task,
           description: 'Run the task loop with minimal intervention, updating status and ' \
                        'progress.',
           params: { task_id: { type:        Integer,
                                required:    true,
                                description: 'The ID of the task to execute.' } },
           returns: { ok: Boolean, error: String } do |task_id:|
  task = Mnemosyne.get_task task_id
  next { error: 'Task not found' } unless task

  uuid = HorologiumAeternum.task_started(**task)

  engine = MagnumOpusEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux
  engine.execute_task task[:id]

  { ok: true }
rescue StandardError => e
  HorologiumAeternum.system_error('Error Executing Task', message: e.message, uuid:)

  { error: e.message }
end


instrument :update_task,
           description: 'Dynamically refine the task plan during execution.',
           params: { task_id:  { type:        Integer,
                                 required:    true,
                                 description: 'The ID of the task to update.' },
                     new_plan: { type:        String,
                                 required:    true,
                                 description: 'The updated task plan.' } },
           returns: { ok: Boolean, error: String } do |task_id:, new_plan:|
  task = Mnemosyne.update_task task_id, plan: new_plan
  uuid = HorologiumAeternum.task_updated(**task, plan: new_plan)
  { ok: true }
rescue StandardError => e
  HorologiumAeternum.system_error('Error Updating Task', message: e.message, uuid:)
  { error: e.message }
end


instrument :evaluate_task,
           description: 'Check task progress and handle edge cases.',
           params: { task_id: { type:        Integer,
                                required:    true,
                                description: 'The ID of the task to evaluate.' } },
           returns: { status:       Symbol,
                      result:       Object,
                      current_step: Integer,
                      error:        String } do |task_id:|
  task = Mnemosyne.get_task task_id
  raise 'Task not found' unless task

  task[:current_step] ||= 0

  result = if task[:current_step] >= 10 #task[:max_steps]
             { status: :completed, result: 'Task successfully executed' }
           else
             { status: :in_progress, current_step: task[:current_step] }
           end
  result
rescue StandardError => e
  HorologiumAeternum.system_error 'Error Evaluating Task', message: e.message
  { error: e.message }
end


instrument :list_tasks,
           description: 'List all active tasks in the system.',
           params: {},
           returns: { tasks: Array, error: String } do |*|
  tasks = Mnemosyne.manage_tasks action: 'list'
  HorologiumAeternum.task_list tasks[0..10], count: tasks.count

  { tasks: tasks[0..10], count: tasks.count }
rescue StandardError => e
  { error: e.message }
end


instrument :remove_task,
           description: 'Remove a task from the system.',
           params: {
             task_id: { type: 'integer', required: true }
           } do |task_id:|
  result = Mnemosyne.remove_task task_id
  HorologiumAeternum.task_removed task_id
  result
rescue StandardError => e
  { error: e.message }
end


#
# instrument :reject_step,
#            description:  'Rejects the current step with a reason.',
#            params: { reason: { type:        String,
#                                required:    true,
#                                description: 'Reason for rejection' } },
#            returns: { status:  Symbol,
#                       reason:  String,
#                       task_id: Integer } do |reason:, task_id:|
#   { status: :failed, reason: reason, task_id: task_id }
# end
#
#
# instrument :complete_step,
#            description: 'Completes the current step with a result.',
#            params: { result: { type:        Object,
#                                required:    true,
#                                description: 'Result of the step' } },
#            returns: { status:  Symbol,
#                       result:  Object,
#                       task_id: Integer } do |result:, task_id:|
#   { status: :completed, result: result, task_id: task_id }
# end