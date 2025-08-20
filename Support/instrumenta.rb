# frozen_string_literal: true


require_relative 'prima_materia'



# This is the collection of all available tools but may be filtered later however.
# The following serves as Schema for AI API and will be converted to JSON.
class Instrumenta
  PRIMA_MATERIA = PrimaMateria.new

  class << self
    def instrumenta_schema = PRIMA_MATERIA.instrumenta_schema
    def schema = PRIMA_MATERIA.schema
    def tools = PRIMA_MATERIA.tools
    def handle(...) = PRIMA_MATERIA.handle(...)
  end
end


def instrument(...) = Instrumenta::PRIMA_MATERIA.add_instrument(...)


# --- Register All Instruments ---
instrument :read_file,
           description: 'Read a file (optionally a line range).',
           params: { path:  { type: String, required: true, minLength: 1 },
                     range: { type:     Array,
                              required: false,
                              items:    { type: 'integer', minimum: 0, maximum: 10_000 },
                              minItems: 2,
                              maxItems: 2 } },
           returns: { content: String, error: String } do |path:, range: nil|
  return { error: 'Denied path' } if PrimaMateria::DENY_PATHS.any? { |re| re.match? path }

  uuid = HorologiumAeternum.file_reading path, range
  result = Argonaut.read path, range
  bytes_read = result[:content]&.bytesize || 0
  HorologiumAeternum.file_read_complete(path, bytes_read, range, result[:content], uuid:)
  result
rescue StandardError => e
  HorologiumAeternum.file_read_fail(path, e.message, range, uuid:)
  { error: e.message.to_s }
end

instrument :oracle_conjuration,
           description: <<~DESC,
             Invoke the reasoning model to generate responses and actions based on advanced
             reasoning. Make sure to provide a meaningful and profound prompt as invocation to
             the high oracle and give a rich context as sacred offerings like files and other
             tools output, this higher oracle will call tools on its own, too. Whenever a task
             is difficult or you're asked to reason or meditate or something similar, use this
             function to have a higher intelligence.
           DESC
           params: { prompt: { type:        String,
                               required:    true,
                               description: 'The input prompt for reasoning.' } },
           returns: { reasoning: String, content: String, context: Object } do |prompt:|
  params = {
    prompt:  prompt,
    context: nil
  }
  HorologiumAeternum.oracle_conjuration prompt

  result = Aetherflux.channel_oracle_conjuration params,
                                                 tools: prima.instrumenta_schema.reject do |tool|
    'oracle_conjuration' == tool[:function][:name]
  end

  raise result[:error] if result[:error]

  if result[:result]
    reasoning = result[:result][:reasoning]
    content = result[:result][:answer]

    unless reasoning.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Reasoning', reasoning
    end
    unless content.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Answer', content
    end
  end

  { reasoning: reasoning, content: content, context: nil }
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
  return { error: 'Blocked command' } unless PrimaMateria::ALLOW_CMDS.any? { |re| cmd =~ re }

  uuid = HorologiumAeternum.command_executing cmd

  begin
    project_root = Argonaut.project_root
    run_command_env = Dotenv.parse "#{project_root}/.env.run_command", overwrite: true

    env_vars = run_command_env.merge({ 'BUNDLE_GEMFILE' => '' })

    stdout, stderr, status = Open3.capture3 env_vars, cmd, chdir: project_root
    out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
    HorologiumAeternum.command_completed(cmd, out.length, out, status.exitstatus, uuid:)

    { ok: true, exit_status: status.exitstatus, result: "Command output: #{out}" }
  rescue StandardError => e
    { error: "Command error: #{e.message}" }
  end
end








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
  return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match? path }

  uuid = HorologiumAeternum.file_reading path, range
  result = Argonaut.read path, range
  bytes_read = result[:content]&.bytesize || 0
  HorologiumAeternum.file_read_complete(path, bytes_read, range, result[:content], uuid:)
  result
rescue StandardError => e
  HorologiumAeternum.file_read_fail(path, e.message, range, uuid:)
  { error: e.message.to_s }
end


instrument :oracle_conjuration,
           description: <<~DESC,
             Invoke the reasoning model to generate responses and actions based on advanced
             reasoning. Make sure to provide a meaningful and profound prompt as invocation to
             the high oracle and give a rich context as sacred offerings like files and other
             tools output, this higher oracle will call tools on its own, too. Whenever a task
             is difficult or you're asked to reason or meditate or something similar, use this
             function to have a higher intelligence.
           DESC
           params: { prompt: { type:        String,
                               required:    true,
                               description: 'The input prompt for reasoning.' } },
           returns: { reasoning: String, content: String, context: Object } do |prompt:|
  params = {
    prompt:  prompt,
    context: nil
  }
  HorologiumAeternum.oracle_conjuration prompt

  result = Aetherflux.channel_oracle_conjuration params,
                                                 tools: instrumenta_schema.reject do |tool|
    'oracle_conjuration' == tool[:function][:name]
  end

  raise result[:error] if result[:error]

  if result[:result]
    reasoning = result[:result][:reasoning]
    content = result[:result][:answer]

    unless reasoning.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Reasoning', reasoning
    end
    unless content.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Answer', content
    end
  end

  { reasoning: reasoning, content: content, context: nil }
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
  return { error: 'Blocked command' } unless PrimaMateria::ALLOW_CMDS.any? { |re| cmd =~ re }

  uuid = HorologiumAeternum.command_executing cmd

  begin
    project_root = Argonaut.project_root
    run_command_env = Dotenv.parse "#{project_root}/.env.run_command", overwrite: true

    env_vars = run_command_env.merge({ 'BUNDLE_GEMFILE' => '' })

    stdout, stderr, status = Open3.capture3 env_vars, cmd, chdir: project_root
    out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
    HorologiumAeternum.command_completed(cmd, out.length, out, status.exitstatus, uuid:)

    { ok: true, exit_status: status.exitstatus, result: "Command output: #{out}" }
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
  return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match? path }

  bytes = content.bytesize
  uuid = HorologiumAeternum.file_creating path, bytes

  full = File.join Argonaut.project_root, path

  return { error: "File exists: #{path} (set overwrite:true)" } if File.exist?(full) && !overwrite

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
  return { error: 'Denied path' } if [from, to].any? do |p|
    DENY_PATHS.any? do |re|
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


instrument :recall_notes,
           description: 'Recall notes from Mnemosyne by tags, content or context ' \
                        '(internal use only).',
           params: { query: { type: String, required: false },
                     limit: { type: Integer, required: false, default: 3 } },
           returns: { notes: Array, error: String } do |query: '', limit: 7|
  result = { notes: Mnemosyne.recall_notes(query, limit: limit) }
  HorologiumAeternum.notes_recalled query, limit, result[:notes]
  result
rescue StandardError => e
  { error: e.message }
end


instrument :file_overview,
           description: <<~DESC,
             Fetch all information associated with a file (e.eof_part1
             Fetch all information associated with a file (e.g., ai notes metadata and related
             file metadata, size, number of line, last modified).
           DESC
           params: { path: { type: String, required: true } },
           returns: { metadata: Hash, error: String } do |path:|
  path = Argonaut.relative_path path

  results = Argonaut.file_overview path: path
  raise results[:error] unless results[:error].nil?

  HorologiumAeternum.file_overview path, results
  results
rescue StandardError => e
  puts "[PRIMA MATERIA][ERROR]: #{e.inspect}"
  { error: "File overview for #{path} failed: #{e.message || e.error}" }
end


instrument :remember,
           description: <<~DESC,
             Store a note in Mnemosyne memory. To overwrite existing note use id, otherwise a
             new note will be created. Remove redundant notes with remove_note. links is an
             array of linked paths, these are used by file_overview tool. These can be many or
             only one file, thus reflecting on multifile relations and significatives. When
             links are empty or null the note will be stored in a global context and always be
             present.
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
    uuid = HorologiumAeternum.note_added(**note)
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
  Mnemosyne.remove_note id
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
           DESC
           params: { path: { type: String, required: true },
                     diff: { type: String, required: true } },
           returns: { ok: Boolean, error: String } do |path:, diff:|
  return { error: 'missing :path or :diff' } unless path && diff

  diff_lines = diff.lines.count
  uuid = HorologiumAeternum.file_patching path, diff, diff_lines

  return { error: 'Diff too big' } if MAX_DIFF < diff.lines.count

  old_content, new_content = Argonaut.patch path, diff

  HorologiumAeternum.file_patched(path, old_content, new_content, uuid:)
  { ok: true }
rescue StandardError => e
  HorologiumAeternum.file_patched_fail(path, e.message, diff, uuid:)
  { error: "patch failed: #{e.message}" }
end


instrument :aegis,
           description:  <<~DESC,
             The Aegis tool is for enabling an active context from Mnemosyne during
             conversations. When topic in current conversation changes you have to change or
             refine its state, ensuring relevance and precision in context note recall. Use it
             to refine the oracle's focus. The Aegis tool will immediately return notes like
             `recall_notes` and keep them in context unlike `recall_notes` which only retrieves
             note for current interaction.
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
           description: 'Generate a task for complex prompts with fields for plan, progress, ' \
                        'and max_steps.',
           params: { title:     { type:        String,
                                  required:    true,
                                  description: 'The title of the plan.' },
                     plan:      { type:        String,
                                  required:    true,
                                  description: 'The task execution plan.' },
                     max_steps: { type:        Integer,
                                  required:    true,
                                  description: 'Total steps in the task.' } },
           returns: { id: Integer, error: String } do |title:, plan:, max_steps:|
  engine = TaskEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux

  result = engine.create_task(title:, plan:, max_steps:)

  uuid = HorologiumAeternum.task_created title, plan, max_steps, result[:id]

  result
rescue StandardError => e
  HorologiumAeternum.system_error('Error Creating Task', e.message, uuid:)

  { error: e.message }
end


instrument :execute_task,
           description: 'Run the task loop with minimal intervention, updating status and ' \
                        'progress.',
           params: { task_id:     { type: Integer, required: true },
                     description: 'The ID of the task to execute.' },
           returns: { ok: Boolean, error: String } do |task_id:|
  require_relative 'task_engine'
  task = Mnemosyne.get_task task_id
  return { error: 'Task not found' } unless task

  engine = TaskEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux
  engine.execute_task task[:id]

  uuid = HorologiumAeternum.task_started task_id, task[:title], task[:max_steps]

  { ok: true }
rescue StandardError => e
  HorologiumAeternum.system_error('Error Executing Task', e.message, uuid:)

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
  uuid = HorologiumAeternum.task_updated task_id,
                                         title: task[:title],
                                         plan: new_plan,
                                         progress: task[:progress], max_steps: task[:max_steps]
  { ok: true }
rescue StandardError => e
  HorologiumAeternum.system_error('Error Updating Task', e.message, uuid:)
  { error: e.message }
end


instrument :evaluate_task,
           description: 'Check task progress and handle edge cases.',
           params: { task_id:     { type: Integer, required: true },
                     description: 'The ID of the task to evaluate.' },
           returns: { status:   Symbol,
                      result:   Object,
                      progress: Integer,
                      error:    String } do |task_id:|
  task = Mnemosyne.get_task task_id
  raise 'Task not found' unless task

  task[:progress] ||= 0

  result = if task[:progress] >= task[:max_steps]
             { status: :completed, result: 'Task successfully executed' }
           else
             { status: :in_progress, progress: task[:progress] }
           end
  result
rescue StandardError => e
  HorologiumAeternum.system_error 'Error Evaluating Task', e.message
  { error: e.message }
end


instrument :list_tasks,
           description: 'List all active tasks in the system.',
           params: {},
           returns: { tasks: Array, error: String } do |*|
  tasks = Mnemosyne.manage_tasks action: 'list'
  HorologiumAeternum.task_list tasks
  { tasks: tasks }
rescue StandardError => e
  { error: e.message }
end


instrument :reject_step,
           description:  'Rejects the current step with a reason.',
           params: { reason: { type:        String,
                               required:    true,
                               description: 'Reason for rejection' } },
           returns: { status:  Symbol,
                      reason:  String,
                      task_id: Integer } do |reason:, task_id:|
  { status: :failed, reason: reason, task_id: task_id }
end


instrument :complete_step,
           description: 'Completes the current step with a result.',
           params: { result: { type:        Object,
                               required:    true,
                               description: 'Result of the step' } },
           returns: { status:  Symbol,
                      result:  Object,
                      task_id: Integer } do |result:, task_id:|
  { status: :completed, result: result, task_id: task_id }
end
