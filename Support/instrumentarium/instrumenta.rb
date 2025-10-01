# frozen_string_literal: true


require_relative '../magnum_opus/magnum_opus_engine'
require_relative '../argonaut/argonaut'
require_relative '../mnemosyne/mnemosyne'
require_relative '../oracle/oracle'
require_relative 'horologium_aeternum'
require_relative 'prima_materia'
require_relative 'verbum'
require_relative '../instrumentarium/scriptorium'
require_relative '../argonaut/temp_create_file'
require_relative 'symbolic_patch_file'




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
  raise result[:error] unless result[:error].nil?

  bytes_read = result[:content]&.bytesize || 0
  HorologiumAeternum.file_read_complete(path, bytes_read, range, result[:content], uuid:)
  result
rescue StandardError => e
  # TODO: when a file path could not be found make some suggestions about similar paths...
  # TODO likewise when a directory is tried to read then output its contents.
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
             #{'  '}
               **CRITICAL**: In reasoning mode, you CANNOT call any tools including oracle_conjuration itself
             #{'  '}
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
           timeout: 6600,
           returns: { reasoning: String,
                      content:   String,
                      context:   Object } do |prompt:, context: nil|
  # Add reasoning flag to context for proper system prompt selection
  context_with_reasoning = context ? context.merge(reasoning: true) : { reasoning: true }

  params = {
    prompt:  prompt,
    context: context_with_reasoning
  }
  HorologiumAeternum.oracle_conjuration prompt

  puts "CONJURATION TOOL CONTEXT=#{context.inspect.truncate 200}"

  # For DeepSeek reasoning, we must NOT pass any tools to enable advanced reasoning
  # The reasoning model cannot use tools, so we provide empty tools array
  puts "[CONJURATION][DEBUG]: Starting conjuration with params: #{params.inspect.truncate 200}"
  # For reasoning, we need to pass empty tools object, not nil
  result = Aetherflux.channel_oracle_conjuration params, tools: nil
  puts "[CONJURATION][DEBUG]: Aetherflux result: #{result.inspect.truncate 300}"

  if result[:error]
    puts "[CONJURATION][ERROR]: #{result[:error]}"
    raise result[:error]
  end

  if :success == result[:status] && result[:response]
    reasoning = result[:response][:reasoning]
    answer = result[:response][:answer]

    puts "[CONJURATION][DEBUG]: Success - reasoning: #{reasoning.to_s.truncate 100}, answer: #{answer.to_s.truncate 100}"

    unless reasoning.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Reasoning', reasoning
    end
    unless answer.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Answer', answer
    end
  else
    puts "[CONJURATION][DEBUG]: Failed - status: #{result[:status]}, response: #{result[:response].inspect.truncate 200}"
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
             `bundle exec irb`, `ruby`, `irb`, `cd`, `curl`, `ag`, `ast-grep`. Please suggest to#{' '}
             add more cmds to this list if you like. To have more execution time u
           DESC
           params: { cmd:     { type: String, required: true },
                     timeout: { type: Integer, default: 30 } },
           timeout: 30_000,
           returns: { ok:          Boolean,
                      exit_status: Integer,
                      result:      String,
                      error:       String } do |cmd:, timeout:|
  # TODO: instead of blocked command, make a button to accept or decline execution...
  # Get merged allowed commands (default + custom from .aethercodex)
  allowed_commands = PrimaMateria.allowed_commands

  # Allow all commands if wildcard is present
  unless allowed_commands.any? { |re| // == re } || allowed_commands.any? { |re| cmd =~ re }
    raise "🚫 Blocked command: `#{cmd}`"
  end

  uuid = HorologiumAeternum.command_executing cmd

  begin
    project_root = Argonaut.project_root
    run_command_env = Dotenv.parse "#{project_root}/.env.run_command", overwrite: true

    env_vars = run_command_env.merge({ 'BUNDLE_GEMFILE' => '' })

    stdout, stderr, status = Verbum.run_command_in_real_time env_vars, cmd,
                                                             chdir: project_root, timeout_seconds: timeout
    # Open3.capture3 env_vars, cmd, chdir: project_root
    exitstatus = if status.respond_to? :exitstatus then status.exitstatus else 'undefined' end
    out = (stdout + stderr + "\n(exit #{exitstatus})").strip
    HorologiumAeternum.command_completed(cmd, out.length, out, exitstatus, uuid:)

    # Use Scriptorium HTML utils for proper escaping
    escaped_out = Scriptorium.escape_html out

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
           description: 'Rename a file with given content. May also be used to move files.',
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


instrument :temp_create_file,
           description: <<~DESC,
             Create a temporary file with automatic context-based cleanup. The file will be
             automatically removed when the oracle context terminates. Supports both system
             temp files and project-relative paths with nested context management. Use this for#{' '}
             local script, and test files for example.
           DESC
           params: { content: { type:        String,
                                required:    true,
                                description: 'The content to write to the temporary file.' },
                     path:    { type:        String,
                                required:    false,
                                description: 'Optional relative path within project (nil for system temp files)' } },
           returns: { path:    String,
                      success: Boolean,
                      error:   String } do |content:, path: nil|
  # Debug: check what parameters are received
  puts "[INSTRUMENTA] temp_create_file called with path: #{path.inspect}"

  result = Argonaut::TempFile.create content, path: path

  puts "[INSTRUMENTA] Argonaut::TempFile.create result: #{result.inspect}"

  if result[:success]
    uuid = HorologiumAeternum.temp_file_created path, content, content.bytesize
    result
  else
    { error: result[:error] }
  end
rescue StandardError => e
  puts "[INSTRUMENTA] Error: #{e.message}"
  { error: "Temporary file creation failed: #{e.message}" }
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


# TODO: match by ID, so it can be easily accessed from file_overview tool
# TODO: match by task ID
instrument :recall_notes,
           description: 'Recall notes from Mnemosyne by tags, content or context. ' \
                        'Uses fuzzy matching with enhanced scoring: content (4x), ' \
                        'tags (3x), links (2x), path matches (+5). Current-state only. ' \
                        'Max. content length will be reduced by higher limit.',
           params: { query: { type: String, required: false },
                     limit: { type: Integer, required: false, default: 3 } },
           returns: { notes: Array, error: String } do |query: '', limit: 2|
  # Use optimized parameters to prevent context bloat
  result = { notes: Mnemosyne.recall_notes(query, limit: limit, max_content_length: 1111 / limit) }
  HorologiumAeternum.notes_recalled query, limit, result[:notes]
  result
rescue StandardError => e
  { error: e.message }
end


instrument :file_overview,
           description: <<~DESC,
             Fetch file information with symbolic parsing. Returns lightweight metadata:
             note count, and note relations of tags to files. Enhanced symbolic analysis shows
             structural view with classes, methods, constants, and navigation hints. Use this in
             combination with read_file range to fetch minimal parts of a file and have an overview
             about its relations. The hermetic overview shows the number of notes per associated file,
             use `recall_notes` to see note content.
           DESC
           params: { path: { type: String, required: true } },
           returns: { metadata: Hash, error: String } do |path:|
  path = Argonaut.relative_path path

  # Use optimized parameters to prevent context bloat
  results = Argonaut.file_overview path: path, max_notes: 3, max_content_length: 333
  raise results[:error] unless results[:error].nil?

  HorologiumAeternum.file_overview path, results

  result = {
    notes_count:        results[:notes_count],
    notes_preview:      results[:notes_preview],
    file_info:          results[:file_info],
    structural_summary: results[:symbolic_overview][:structural_summary],
    symbolic_overview:  results[:symbolic_overview][:symbolic_overview_text],
    tag_cloud:          results[:symbolic_overview][:tag_cloud_text],
    file_cloud:         results[:symbolic_overview][:file_cloud_text],
    hermetic_overview:  results[:hermetic_overview]
  }
  # puts results.inspect
  # puts '==================================================='
  puts result.inspect
  result
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
                     links:   { type: Array, items: { type: :string }, required: false },
                     tags:    { type: Array, items: { type: :string }, required: false } },
           returns: { ok:    Boolean,
                      error: String } do |content:, id: nil, links: nil, tags: nil|
  # links = if links.is_a? String

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
  HorologiumAeternum.note_removed note unless note.nil?
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

  raise 'Diff too big' if PrimaMateria::MAX_DIFF < diff.lines.count

  result = Argonaut.patch path, diff
  if result[:ok]
    old_content, new_content = result[:result]
    HorologiumAeternum.file_patched(path, old_content, new_content, uuid:)
    { ok: true }
  else
    HorologiumAeternum.file_patched_fail(path, result[:error], diff, uuid:)
    { error: "patch failed: #{result[:error].to_json}" }
  end
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
           description:  <<~DESC,
             Generate a task for complex prompts with fields for plan and title. During Task
             execution no other history context is given to the AI (you). Make sure that plan is very
             descriptive.
           DESC
           params: { title: { type:        String,
                              required:    true,
                              description: 'The title of the plan.' },
                     plan:  { type:        String,
                              required:    true,
                              description: 'The task execution plan.' } },
           returns: { id: Integer, error: String } do |title:, plan:, quiet: false|
  engine = MagnumOpusEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux

  result = engine.create_task title:, plan:, workflow_type: 'full', quiet: quiet

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
           timeout: 86_400,
           returns: { ok: Boolean, error: String } do |task_id:|
  task = Mnemosyne.get_task task_id
  next { error: 'Task not found' } unless task

  uuid = HorologiumAeternum.task_started(**task)

  engine = MagnumOpusEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux
  result = engine.execute_task task[:id]

  { ok: true, result: }
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
           description: 'Check task progress and handle edge cases. Returns comprehensive task information including step results, execution logs, and alchemical progression stages.',
           params: { task_id: { type:        Integer,
                                required:    true,
                                description: 'The ID of the task to evaluate.' } },
           returns: { status:                 Symbol,
                      current_step:           Integer,
                      task:                   Object,
                      step_results:           Object,
                      execution_logs:         Array,
                      alchemical_progression: Array,
                      error:                  String } do |task_id:|
  # Use the enhanced MagnumOpusEngine evaluate_task method for comprehensive evaluation
  engine = MagnumOpusEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux
  evaluation = engine.evaluate_task task_id

  if :success == evaluation[:status]
    # Maintain backward compatibility with original format while adding enhanced data
    {
      status:                 evaluation[:task][:status].to_sym,
      current_step:           evaluation[:task][:current_step],
      task:                   evaluation[:task],
      step_results:           evaluation[:step_results],
      execution_logs:         evaluation[:execution_logs],
      alchemical_progression: evaluation[:alchemical_progression]
    }
  else
    { error: evaluation[:message] || 'Task evaluation failed' }
  end
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


instrument :symbolic_patch_file,
           description: <<~DESC,
             Apply semantic patches using AST-GREP for pattern-based transformations.
             This tool uses semantic patterns instead of line numbers, enabling multi-file
             operations and language-agnostic transformations.

             Supports:
             - Method/class renaming across files
             - Documentation addition
             - Pattern-based search and replace
             - Multi-language support (Ruby, JavaScript, Python, etc.)

             Use for semantic transformations where line-based patching is impractical.
           DESC
           params: { path:            { type:        String,
                                        required:    true,
                                        description: 'File path or pattern to patch' },
                     operation:       { type:        String,
                                        required:    true,
                                        enum:        %w[transform_method transform_class
                                                        document_method find_and_replace apply],
                                        description: 'Type of semantic operation to perform' },
                     search_pattern:  { type:        String,
                                        required:    false,
                                        description: 'Search pattern for AST-GREP' },
                     replace_pattern: { type:        String,
                                        required:    false,
                                        description: 'Replace pattern for AST-GREP' },
                     method_name:     { type:        String,
                                        required:    false,
                                        description: 'Method name for transformation' },
                     class_name:      { type:        String,
                                        required:    false,
                                        description: 'Class name for transformation' },
                     new_method_name: { type:        String,
                                        required:    false,
                                        description: 'New method name for renaming' },
                     new_class_name:  { type:        String,
                                        required:    false,
                                        description: 'New class name for renaming' },
                     documentation:   { type:        String,
                                        required:    false,
                                        description: 'Documentation text to add' },
                     lang:            { type:        String,
                                        required:    false,
                                        description: 'Language hint (auto-detected if nil)' } },
           returns: { success: Boolean,
                      result:  Hash,
                      error:   String } do |path:, operation:, search_pattern: nil, replace_pattern: nil,
                                               method_name: nil, class_name: nil, new_method_name: nil,
                                               new_class_name: nil, documentation: nil, lang: nil|
  uuid = HorologiumAeternum.symbolic_patch_start path, operation

  begin
    result = case operation
             when 'transform_method'
               SymbolicPatchFile.transform_method path, method_name,
                                                  new_method_name: new_method_name
             when 'transform_class'
               SymbolicPatchFile.transform_class path, class_name, new_class_name: new_class_name
             when 'document_method'
               SymbolicPatchFile.document_method path, method_name, documentation
             when 'find_and_replace'
               SymbolicPatchFile.find_and_replace path, search_pattern, replace_pattern
             when 'apply'
               SymbolicPatchFile.apply path, search_pattern, replace_pattern, lang: lang
             else
               raise "Unknown operation: #{operation}"
             end

    # Add debugging output to see what result contains
    puts "[DEBUG] symbolic_patch_file result: #{result.inspect.truncate 500}"

    # Enrich result with pattern information for better display
    enriched_result = if result.is_a?(Hash) && result[:success]
                        # Ensure result[:result] is properly formatted for display
                        formatted_result = if result[:result].is_a? Array
                                             result[:result]
                                           else
                                             # Convert to array for consistent display
                                             result[:result] ? [result[:result]] : []
                                           end

                        result.merge \
                          result: formatted_result,
                          patterns: {
                            operation:       operation,
                            search_pattern:  search_pattern,
                            replace_pattern: replace_pattern,
                            method_name:     method_name,
                            class_name:      class_name,
                            documentation:   documentation
                          }

                      else
                        result
                      end

    puts "[DEBUG] enriched_result: #{enriched_result.inspect.truncate 500}"
    raise result[:error] unless true == result[:success]

    HorologiumAeternum.symbolic_patch_complete(path, operation, enriched_result, uuid:)
    enriched_result
  rescue StandardError => e
    HorologiumAeternum.symbolic_patch_fail(path, operation, e.message, uuid:)
    { error: "Symbolic patch failed: #{e.message}" }
  end
end
