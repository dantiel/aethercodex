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


require 'differ'
require 'differ/string' # Required for the inline `diff` method on strings


TaskEngine # Force load the TaskEngine class

TaskEngine # Force load the TaskEngine class
require 'cgi'



module PrimaMateria
  ALLOW_CMDS   = [/^rspec\b/, /^rubocop\b/, /^git\b/, /^ls\b/, /^cat\b/, /^mkdir\b/, /^\$TM_QUERY\b/, /^echo\b/, /^grep\b/, /^ruby\b/, /^cd\b/, /^curl\b/, /^ag\b/]
  DENY_PATHS   = [/\.aethercodex$/, /\.env$/, /\.git\//]
  MAX_DIFF     = 800
  MAX_CMD_TIME = 10
  SCHEMA = {
    'create_file'        => { req: %i[path content], forbid: %i[diff] },
    'patch_file'         => { req: %i[path diff],    forbid: %i[content] },
    'read_file'          => { req: %i[path],         forbid: [] },
    'rename_file'        => { req: %i[from to],      forbid: [] },
    'run_command'        => { req: %i[cmd],          forbid: [] },
    'tell_user'          => { req: %i[message],      forbid: [] },
    'recall_history'     => { req: %i[],             forbid: [] },
    'remember'           => { req: %i[content],      forbid: [] },
    'recall_notes'       => { req: %i[],             forbid: [] },
    'remove_note'        => { req: %i[id],           forbid: [] },
    'file_overview'      => { req: %i[path],         forbid: [] },
    'oracle_conjuration' => { req: %i[prompt],       forbid: %i[recursive] },
    'aegis'              => { req: %i[],             forbid: %i[] },
    'create_task'        => { req: %i[plan max_steps], forbid: [] },
    'execute_task'       => { req: %i[task_id],       forbid: [] },
    'update_task'        => { req: %i[task_id new_plan], forbid: [] },
    'evaluate_task'      => { req: %i[task_id],       forbid: [] }
  }


  def self.validate!(tool, args)
    spec = SCHEMA[tool] or raise "Unknown tool #{tool}"
    miss = spec[:req]   - args.keys
    bad  = spec[:forbid] & args.keys
    raise "missing #{miss.join(', ')}" unless miss.empty?
    raise "forbidden #{bad.join(', ')}" unless bad.empty?
  end
  
  
  # --- helpers at top ---
  def self.symbolize(obj)
    case obj
    when Hash  then obj.each_with_object({}) { |(k,v),h| h[k.to_sym] = symbolize(v) }
    when Array then obj.map { |v| symbolize(v) }
    else obj end
  end
  
  
  TOOL_ALIASES = {
    'readfile'          => 'read_file',
    'patchfile'         => 'patch_file',
    'createfile'        => 'create_file',
    'runcommand'        => 'run_command',
    'renamefile'        => 'rename_file',
    'telluser'          => 'tell_user',
    'oracleconjuration' => 'oracle_conjuration'
  }
  
  
  def self.handle(call)
    tool = (call['tool'] || call[:tool]).to_s
    tool = TOOL_ALIASES[tool] || tool
    args = symbolize(call['args'] || {})
    
    begin
      validate!(tool, args)
    rescue => e
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
    else { error: "Unknown tool #{tool}" }
    end
  rescue ArgumentError => e
    { error: "Bad args for #{tool}: #{e.message}", got: call }
  rescue => e
    puts "[RESCUE] #{e.inspect}"
    {}
  end


  def self.create_file(path:, content:, overwrite: false, **_)
    return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match?(path) }
    puts "create_file path=#{path}, content=#{content}, overwrite=#{overwrite}"    
    
    bytes = content.bytesize 
    HorologiumAeternum.file_creating(path, bytes)
    
    full = File.join(Argonaut.project_root, path)
    
    if File.exist?(full) && !overwrite
      puts "error file exists path=#{full}, overwrite=#{overwrite}"    
      return { error: "File exists: #{path} (set overwrite:true)" }
    end
    
    Argonaut.write(path, content)
    HorologiumAeternum.file_created(path, bytes, content)
    { ok: true }
  rescue => e
    puts "#{e.inspect}"    
    { error: e.message }
  end
  

  def self.rename_file(from:, to:, **_)
    return { error: 'Denied path' } if [from, to].any? { |p| DENY_PATHS.any? { |re| re.match?(p) } }
    
    HorologiumAeternum.file_renaming(from, to)
    Argonaut.rename(from, to)
    HorologiumAeternum.file_renamed(from, to)
    { ok: true }
  rescue => e
    { error: e.message }
  end
  
  
  def self.tell_user(message:, level: 'info', **_)
    HorologiumAeternum.info_message(message)
    { say: { level: level, message: message } }
  end


  def self.patch_file(path: nil, diff: nil, **_)
    return { error: 'missing :path or :diff' } unless path && diff
    
    diff_lines = diff.lines.count
    HorologiumAeternum.file_patching path, diff, diff_lines
    
    return { error: 'Diff too big' } if diff.lines.count > MAX_DIFF
    old_content, new_content = Argonaut.patch path, diff
    
    word_diff = Differ.diff_by_word old_content, new_content
    Differ.format = :html
    
    HorologiumAeternum.file_patched path, word_diff.to_s
    # HorologiumAeternum.file_patched(path, diff)
    { ok: true }
  rescue => e
    HorologiumAeternum.file_patched_fail path, e.message, diff
    { error: "patch failed: #{e.message}" }
  end


  def self.read_file(path:, range: nil, **_)
    return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match?(path) }
    HorologiumAeternum.file_reading(path, range)
    
    result = Argonaut.read path, range
    
    bytes_read = result[:content]&.bytesize || 0
    
    HorologiumAeternum.file_read_complete path, bytes_read, range, result[:content]
    
    result
  rescue => e
    HorologiumAeternum.file_read_fail path, e.message, range
    { error: "#{e.message}" }
  end


  def self.list_files(glob: '**/*', **_)
    files = Argonaut.list_files glob
    { files: files }
  end


  def self.run_command(cmd:, **_)
    return { error: 'Blocked command' } unless ALLOW_CMDS.any? { |re| cmd =~ re }
    
    HorologiumAeternum.command_executing(cmd)
    
    begin
      stdout, stderr, status = Open3.capture3(cmd, chdir: Argonaut.project_root)
      out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
      HorologiumAeternum.command_completed(cmd, out.length, out, status.exitstatus)
      
      return { ok: true, exit_status: status.exitstatus, result: "Command output: #{out}" }
    rescue => e
      return { error: "Command error: #{e.message}" }
    end
    
    { output: out }
  end

  
  def self.remember(id: nil, content: nil, links: nil, tags: nil)
    # HorologiumAeternum.memory_storing(key, content.bytesize)
    note = { content: content, links: links, tags: tags }
    if id.nil?
      Mnemosyne.create_note **note
      HorologiumAeternum.note_added **note
    else
      Mnemosyne.update_note id, **note
      HorologiumAeternum.note_updated **note
    end
    
    # Mnemosyne.record_note(key, body, tags)
    # HorologiumAeternum.memory_stored(key)
    { ok: true }
  rescue => e
    puts "[PrimaMateria][ERROR]: #{e.inspect}"
    { error: e }
  end


  def self.recall_history(query: '', limit: 7)
    HorologiumAeternum.memory_searching(query, limit)
    result = { notes: Mnemosyne.search(query, limit: limit) }
    HorologiumAeternum.memory_found(query, result[:notes]&.length || 0, result[:notes].inspect)
    result
  rescue => e
    puts "[PrimaMateria][ERROR]: #{e.inspect}"
    { error: e }
  end
  
  
  def self.recall_notes(query: '', limit: 7)
    result = { notes: Mnemosyne.recall_notes(query, limit: limit) }
    HorologiumAeternum.notes_recalled(query, limit, result[:notes])
    result
  rescue => e
    { error: e.message }
  end
  
  
  def self.remove_note(id:)
    Mnemosyne.remove_note(id)
    { ok: true }
  end
  
  
  def self.file_overview(path:)
    path = Argonaut.relative_path path
      
    # puts "[PRIMA MATERIA]: file_overview(path:#{path})"
    results = Argonaut.file_overview path: path
    puts "[PRIMA MATERIA]: results=#{results.inspect}"
    raise results[:error] unless results[:error].nil?
    HorologiumAeternum.file_overview path, results
    results
  rescue => e
    puts "[PRIMA MATERIA][ERROR]: #{e.inspect}"
    { error: "File overview for #{path} failed: #{e.message || e.error}" }
  end

  def self.oracle_conjuration(prompt:, context: nil)
    params = {
      'prompt' => prompt,
      'context' => context
    }
    HorologiumAeternum.oracle_conjuration prompt
    
    result = Aetherflux.channel_oracle_conjuration params
    
    raise result[:error] if result[:error]
    
    if result[:result]
      reasoning = result[:result][:reasoning]
      content =  result[:result][:answer]
      
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Reasoning', reasoning unless reasoning.to_s.empty?
      HorologiumAeternum.oracle_conjuration_revelation 'Oracle Answer', content unless content.to_s.empty?
    end
    
    { reasoning: reasoning, content: content, context: context }
  rescue => e
    { error: "Reasoning failed: #{e.message}" }
  end


  def self.aegis(tags: nil, context_length: nil)
    notes = Mnemosyne.unveil_aegis tags: tags, context_length: context_length
    
    HorologiumAeternum.aegis_unveiled tags, context_length
    
    { aegis_notes: notes, aegis_orientation: Mnemosyne.aegis }
  rescue => e
    { error: "Aegis failed: #{e.message}" }
  end


  def self.create_task(plan:, max_steps:)
    Mnemosyne.create_task(plan: plan, max_steps: max_steps)
    { ok: true }
  rescue => e
    { error: e.message }
  end


  def self.execute_task(task_id:)
    require_relative 'task_engine'
    task = Mnemosyne.get_task(task_id)
    return { error: "Task not found" } unless task
    
    engine = TaskEngine.new(Mnemosyne)
    engine.execute_task(task[:id])
    { ok: true }
  rescue => e
    { error: e.message }
  end


  def self.update_task(task_id:, new_plan:)
    Mnemosyne.update_task(task_id, plan: new_plan)
    { ok: true }
  rescue => e
    { error: e.message }
  end


  def self.evaluate_task(task_id:)
    task = Mnemosyne.get_task(task_id)
    return { error: "Task not found" } unless task
    
    if task[:progress] >= task[:max_steps]
      { status: :completed, result: "Task successfully executed" }
    else
      { status: :in_progress, progress: task[:progress] }
    end
  rescue => e
    { error: e.message }
  end
end