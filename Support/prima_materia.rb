# frozen_string_literal: true

require_relative 'task_engine'
require_relative 'argonaut'
require_relative 'verbum'
require_relative 'scriptorium'
require_relative 'mnemosyne'
require_relative 'horologium_aeternum'
require_relative 'aetherflux'
require 'json'
require 'timeout'
require 'open3'
require 'cgi'
require 'dotenv'
require 'securerandom'
require_relative 'instrumenta'



module PrimaMateria
  def self.reject_step(reason, task_id = nil)
    task_id ||= current_execution_context.task_id
    { status: :failed, reason: reason, task_id: task_id }
  end

  def self.complete_step(result, task_id = nil)
    task_id ||= current_execution_context.task_id
    { status: :completed, result: result, task_id: task_id }
  end
  ALLOW_CMDS   = [/^rspec\b/, /^rubocop\b/, /^git\b/, /^ls\b/, /^cat\b/, /^mkdir\b/,
                  /^\$TM_QUERY\b/, /^echo\b/, /^grep\b/, /^bundle exec ruby\b/,
                  /^bundle exec irb\b/, /^ruby\b/, /^irb\b/, /^cd\b/, /^curl\b/, /^ag\b/].freeze
  DENY_PATHS   = [/\.aethercodex$/, /\.env$/, %r{\.git/}].freeze
  MAX_DIFF     = 800
  MAX_CMD_TIME = 10
  SCHEMA = {
    'create_file'        => { req: %i[path content],          forbid: %i[diff] },
    'patch_file'         => { req: %i[path diff],             forbid: %i[content] },
    'read_file'          => { req: %i[path],                  forbid: [] },
    'rename_file'        => { req: %i[from to],               forbid: [] },
    'run_command'        => { req: %i[cmd],                   forbid: [] },
    'tell_user'          => { req: %i[message],               forbid: [] },
    'recall_history'     => { req: %i[],                      forbid: [] },
    'remember'           => { req: %i[content],               forbid: [] },
    'recall_notes'       => { req: %i[],                      forbid: [] },
    'remove_note'        => { req: %i[id],                    forbid: [] },
    'file_overview'      => { req: %i[path],                  forbid: [] },
    'oracle_conjuration' => { req: %i[prompt],                forbid: %i[recursive] },
    'aegis'              => { req: %i[],                      forbid: %i[] },
    'create_task'        => { req: %i[plan max_steps title],  forbid: [] },
    'execute_task'       => { req: %i[task_id],               forbid: [] },
    'update_task'        => { req: %i[task_id new_plan],      forbid: [] },
    'evaluate_task'      => { req: %i[task_id],               forbid: [] },
    'list_tasks'         => { req: %i[],                      forbid: [] },
    'reject_step'        => { req: %i[reiterate_step reason], forbid: [] },
    'complete_step'      => { req: %i[evaluation_notes],      forbid: [] }
  }.freeze
  TOOL_ALIASES = {
    'readfile'          => 'read_file',
    'patchfile'         => 'patch_file',
    'createfile'        => 'create_file',
    'runcommand'        => 'run_command',
    'renamefile'        => 'rename_file',
    'telluser'          => 'tell_user',
    'oracleconjuration' => 'oracle_conjuration',
    'rejectstep'        => 'reject_step',
    'completestep'      => 'complete_step'
  }.freeze


  class << self
    def validate!(tool, args)
      spec = SCHEMA[tool] or raise "Unknown tool #{tool}"
      miss = spec[:req] - args.keys
      bad  = spec[:forbid] & args.keys
      raise "missing #{miss.join ', '}" unless miss.empty?
      raise "forbidden #{bad.join ', '}" unless bad.empty?
    end


    def symbolize(obj)
      case obj
      when Hash  then obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize v }
      when Array then obj.map { |v| symbolize v }
      else obj end
    end


    def handle(call)
      tool = (call['tool'] || call[:tool]).to_s
      tool = TOOL_ALIASES[tool] || tool
      args = symbolize(call['args'] || {})

      begin
        validate! tool, args
      rescue StandardError => e
        return { error: "invalid_args: #{e.message}", got: call }
      end
      case tool
      when 'read_file'          then read_file(**args)
      when 'patch_file'         then patch_file(**args)
      when 'create_file'        then create_file(**args)
      when 'rename_file'        then rename_file(**args)
      when 'run_command'        then run_command(**args)
      when 'remember'           then remember(**args)
      when 'recall_history'     then recall_history(**args)
      when 'tell_user'          then tell_user(**args)
      # when 'add_note'           then add_note(**args)
      when 'recall_notes'       then recall_notes(**args)
      # when 'update_note'        then update_note(**args)
      when 'remove_note'        then remove_note(**args)
      when 'file_overview'      then file_overview(**args)
      when 'oracle_conjuration' then oracle_conjuration(**args)
      when 'aegis'              then aegis(**args)
      when 'create_task'        then create_task(**args)
      when 'execute_task'       then execute_task(**args)
      when 'update_task'        then update_task(**args)
      when 'evaluate_task'      then evaluate_task(**args)
      when 'list_tasks'         then list_tasks(**args)
      else { error: "Unknown tool #{tool}" }
      end
    rescue ArgumentError => e
      { error: "Bad args for #{tool}: #{e.message}", got: call }
    rescue StandardError => e
      puts "[RESCUE] #{e.inspect}"
      {}
    end


    def create_file(path:, content:, overwrite: false, **_)
      return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match? path }

      bytes = content.bytesize
      uuid = HorologiumAeternum.file_creating path, bytes

      full = File.join Argonaut.project_root, path

      if File.exist?(full) && !overwrite
        return { error: "File exists: #{path} (set overwrite:true)" }
      end

      Argonaut.write path, content
      HorologiumAeternum.file_created(path, bytes, content, uuid:)
      { ok: true }
    rescue StandardError => e
      { error: e.message }
    end


    def rename_file(from:, to:, **_)
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


    def tell_user(message:, level: 'info', **_)
      HorologiumAeternum.info_message message
      { say: { level: level, message: message } }
    end


    def patch_file(path: nil, diff: nil, **_)
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


    def read_file(path:, range: nil, **_)
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


    def list_files(glob: '**/*', **_)
      files = Argonaut.list_files glob
      { files: files }
    end


    def run_command(cmd:, **_)
      return { error: 'Blocked command' } unless ALLOW_CMDS.any? { |re| cmd =~ re }

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

      { output: out }
    end


    def remember(id: nil, content: nil, links: nil, tags: nil)
      # HorologiumAeternum.memory_storing(key, content.bytesize)
      note = { content: content, links: links, tags: tags }
      if id.nil?
        Mnemosyne.create_note(**note)
        uuid = HorologiumAeternum.note_added(**note)
      else
        Mnemosyne.update_note id, **note
        HorologiumAeternum.note_updated(**note, uuid:)
      end

      # Mnemosyne.record_note(key, body, tags)
      # HorologiumAeternum.memory_stored(key)
      { ok: true }
    rescue StandardError => e
      puts "[PrimaMateria][ERROR]: #{e.inspect}"
      { error: e }
    end


    def recall_history(query: '', limit: 7)
      uuid = HorologiumAeternum.memory_searching query, limit
      result = { notes: Mnemosyne.search(query, limit: limit) }
      HorologiumAeternum.memory_found(query, result[:notes]&.length || 0, result[:notes].inspect,
                                      uuid:)
      result
    rescue StandardError => e
      puts "[PrimaMateria][ERROR]: #{e.inspect}"
      { error: e }
    end


    def recall_notes(query: '', limit: 7)
      result = { notes: Mnemosyne.recall_notes(query, limit: limit) }
      HorologiumAeternum.notes_recalled query, limit, result[:notes]
      result
    rescue StandardError => e
      { error: e.message }
    end


    def remove_note(id:)
      Mnemosyne.remove_note id
      { ok: true }
    end


    def file_overview(path:)
      path = Argonaut.relative_path path

      # puts "[PRIMA MATERIA]: file_overview(path:#{path})"
      results = Argonaut.file_overview path: path
      puts "[PRIMA MATERIA]: results=#{results.inspect}"
      raise results[:error] unless results[:error].nil?

      HorologiumAeternum.file_overview path, results
      results
    rescue StandardError => e
      puts "[PRIMA MATERIA][ERROR]: #{e.inspect}"
      { error: "File overview for #{path} failed: #{e.message || e.error}" }
    end


    def oracle_conjuration(prompt:, context: nil)
      params = {
        prompt:  prompt,
        context: context
      }
      HorologiumAeternum.oracle_conjuration prompt

      result = Aetherflux.channel_oracle_conjuration params, tools: INSTRUMENTA.reject do |tool|
        'oracle_conjuration' == tool[:name]
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

      { reasoning: reasoning, content: content, context: context }
    rescue StandardError => e
      { error: "Reasoning failed: #{e.message}" }
    end


    def aegis(tags: nil, summary: '', temperature: nil)
      notes = Mnemosyne.unveil_aegis(tags:, summary:, temperature:)

      HorologiumAeternum.aegis_unveiled tags, summary, temperature, notes

      { aegis_notes: notes, aegis_orientation: Mnemosyne.aegis }
    rescue StandardError => e
      { error: "Aegis failed: #{e.message}" }
    end


    def create_task(title:, plan:, max_steps:)
      engine = TaskEngine.new mnemosyne: Mnemosyne, aetherflux: Aetherflux

      result = engine.create_task(title:, plan:, max_steps:)

      uuid = HorologiumAeternum.task_created title, plan, max_steps, result[:id]

      result
    rescue StandardError => e
      HorologiumAeternum.system_error('Error Creating Task', e.message, uuid:)

      { error: e.message }
    end


    def execute_task(task_id:)
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


    def update_task(task_id:, new_plan:, title: nil, progress: nil)
      task = Mnemosyne.update_task(task_id, plan: new_plan, title:, progress:)
      uuid = HorologiumAeternum.task_updated(task_id,
                                             title: title || task[:title],
                                             plan: new_plan || task[:plan],
                                             progress:, max_steps: task[:max_steps])
      { ok: true }
    rescue StandardError => e
      HorologiumAeternum.system_error('Error Updating Task', e.message, uuid:)
      { error: e.message }
    end


    def evaluate_task(task_id:)
      task = Mnemosyne.get_task task_id
      raise 'Task not found' unless task

      task[:progress] ||= 0

      result = if task[:progress] >= task[:max_steps]
                 { status: :completed, result: 'Task successfully executed' }
               else
                 { status: :in_progress, progress: task[:progress] }
               end
      puts result.inspect
      # HorologiumAeternum.task_evaluated task_id, result
      result
    rescue StandardError => e
      HorologiumAeternum.system_error 'Error Evaluating Task', e.message
      { error: e.message }
    end


    def list_tasks
      tasks = Mnemosyne.manage_tasks action: 'list'
      HorologiumAeternum.task_list tasks
      { tasks: tasks }
    rescue StandardError => e
      { error: e.message }
    end
  end
end