# frozen_string_literal: true
require_relative 'argonaut'
require_relative 'verbum'
require_relative 'scriptorium'
require_relative 'mnemosyne'
require_relative 'horologium_aeternum'
require 'json'
require 'timeout'
require 'open3'
require 'cgi'



module PrimaMateria
  ALLOW_CMDS   = [/^rspec\b/, /^rubocop\b/, /^git\b/, /^ls\b/, /^cat\b/, /^mkdir\b/, /^\$TM_QUERY\b/, /^echo\b/, /^grep\b/, /^ruby\b/]
  DENY_PATHS   = [/\.deepseekrc$/, /\.env$/, /\.git\//]
  MAX_DIFF     = 800
  MAX_CMD_TIME = 10
  
  
  SCHEMA = {
    'create_file'    => { req: %i[path content], forbid: %i[diff] },
    'patch_file'     => { req: %i[path diff],    forbid: %i[content] },
    'read_file'      => { req: %i[path],         forbid: [] },
    'rename_file'    => { req: %i[from to],      forbid: [] },
    'run_command'    => { req: %i[cmd],          forbid: [] },
    'tell_user'      => { req: %i[message],      forbid: [] },
    'recall_history' => { req: %i[],             forbid: [] },
    'remember'       => { req: %i[],             forbid: [] },
    'add_note'       => { req: %i[],             forbid: [] },
    'recall_notes'   => { req: %i[],             forbid: [] },
    'update_note'    => { req: %i[id],           forbid: [] },
    'remove_note'    => { req: %i[id],           forbid: [] }
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
    'readfile'   => 'read_file',
    'patchfile'  => 'patch_file',
    'createfile' => 'create_file',
    'runcommand' => 'run_command',
    'renamefile' => 'rename_file',
    'telluser'   => 'tell_user'
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
    when 'read_file'      then read_file(**args)
    when 'patch_file'     then patch_file(**args)
    when 'create_file'    then create_file(**args)
    when 'rename_file'    then rename_file(**args)
    when 'run_command'    then run_command(**args)
    when 'remember'       then remember(**args)
    when 'recall_history' then recall_history(**args)
    when 'tell_user'      then tell_user(**args)
    when 'add_note'       then add_note(**args)
    when 'recall_notes'   then recall_notes(**args)
    when 'update_note'    then update_note(**args)
    when 'remove_note'    then remove_note(**args)
    when 'file_overview'  then file_overview(**args)
    else { error: "Unknown tool #{tool}" }
    end
  rescue ArgumentError => e
    { error: "Bad args for #{tool}: #{e.message}", got: call }
  rescue e
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


  def self.patch_file(path: nil, diff: nil, dry: false, **_)
    return { error: 'missing :path or :diff' } unless path && diff
    
    diff_lines = diff.lines.count
    HorologiumAeternum.file_patching(path, diff_lines)
    
    return { error: 'Diff too big' } if diff.lines.count > MAX_DIFF
    Argonaut.patch(path, diff, dry: dry)
    
    HorologiumAeternum.file_patched(path, diff)
    { ok: true }
  rescue => e
    HorologiumAeternum.file_patched_fail(path, e.message, diff)
    { error: "patch failed: #{e.message}" }
  end


  def self.read_file(path:, range: nil, **_)
    return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match?(path) }
    HorologiumAeternum.file_reading(path, range)
    
    src = Argonaut.read(path)
    result = if range && range.size == 2
      l0, l1 = range
      lines = src.lines[l0..l1] || []
      { content: lines.join, range: [l0, l1] }
    else
      { content: src }
    end
    
    bytes_read = result[:content]&.bytesize || 0
    
    HorologiumAeternum.file_read_complete(path, bytes_read, range, result[:content])
    
    result
  rescue => e
    HorologiumAeternum.file_read_fail(path, e.message, range)
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
      stdout, stderr, status = Open3.capture3(cmdOpen3.capture3, chdir: Argonaut.project_root)
      out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
      HorologiumAeternum.command_completed(cmd, out.length, out)
      
      return { error: "Command failed (exit #{status.exitstatus}): #{stderr}" } unless status.exitstatus == 0
    rescue => e
      return { error: "Command error: #{e.message}" }
    end
    
    { output: out }
  end


  def self.remember(key:, body:, tags: [])
    HorologiumAeternum.memory_storing(key, body.bytesize)
    Mnemosyne.record_note(key, body, tags)
    HorologiumAeternum.memory_stored(key)
    { ok: true }
  end
  

  def self.add_note(key:, body:, tags: [])
    HorologiumAeternum.hermetic_note_stored(key)
    Mnemosyne.create_note(key, body, tags)
    { ok: true }
  end


  def self.recall_history(query:, limit: 3)
    HorologiumAeternum.memory_searching(query, limit)
    result = { notes: Mnemosyne.search(query, limit: limit) }
    HorologiumAeternum.memory_found(query, result[:notes]&.length || 0)
    result
  rescue e
    puts "[PrimaMateria][ERROR]: #{e.inspect}"
    { error: e }
  end
  
  
  def self.recall_notes(query:, limit: 3)
    HorologiumAeternum.note_recalled(query, limit)
    result = { notes: Mnemosyne.search_notes(query, limit: limit) }
    result
  rescue => e
    { error: e.message }
  end
  
  
  def self.update_note(id:, content: nil, links: nil, tags: nil)
    Mnemosyne.update_note(id, content: content, links: links, tags: tags)
    { ok: true }
  end
  
  
  def self.remove_note(id:)
    Mnemosyne.remove_note(id)
    { ok: true }
  end
  
  
  def self.file_overview(path:)
    notes = Mnemosyne.search_notes_by_path(path)
    file_info = {
      size: File.size(path),
      last_modified: File.mtime(path)
    }
    { notes: notes, file_info: file_info }
  end
end
