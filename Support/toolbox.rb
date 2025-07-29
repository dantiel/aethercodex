# frozen_string_literal: true
require_relative 'file_manager'
require_relative 'command_executor'
require_relative 'markdown_renderer'
require_relative 'mnemosyne'
require_relative 'live_status'
require 'json'
require 'timeout'
require 'open3'
require 'cgi'



module Toolbox
  ALLOW_CMDS   = [/^rspec\b/, /^rubocop\b/, /^git\b/, /^ls\b/, /^cat\b/, /^mkdir\b/, /^\$TM_QUERY\b/, /^echo\b/, /^grep\b/]
  DENY_PATHS   = [/\.deepseekrc$/, /\.env$/, /\.git\//]
  MAX_DIFF     = 800
  MAX_CMD_TIME = 10
  
  SCHEMA = {
    'create_file' => { req: %i[path content], forbid: %i[diff] },
    'patch_file'  => { req: %i[path diff],    forbid: %i[content] },
    'read_file'   => { req: %i[path],         forbid: [] },
    'rename_file' => { req: %i[from to],      forbid: [] },
    'run_command' => { req: %i[cmd],          forbid: [] },
    'tell_user'   => { req: %i[message],      forbid: [] }
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
    'runcommand' => 'run_command'
  }
  
  
  TOOL_ALIASES.merge!(
    'renamefile' => 'rename_file',
    'telluser'   => 'tell_user'
  )
  
  
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
    when 'read_file'    then read_file(**args)
    when 'patch_file'   then patch_file(**args)
    when 'create_file'  then create_file(**args)
    when 'rename_file'  then rename_file(**args)
    when 'run_command'  then run_command(**args)
    when 'remember'     then remember(**args)
    when 'recall'       then recall(**args)
    when 'tell_user'    then tell_user(**args)
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
    LiveStatus.file_creating(path, bytes)
    
    full = File.join(FileManager.project_root, path)
    
    if File.exist?(full) && !overwrite
      puts "error file exists path=#{full}, overwrite=#{overwrite}"    
      return { error: "File exists: #{path} (set overwrite:true)" }
    end
    
    FileManager.write(path, content)
    LiveStatus.file_created(path, bytes, content)
    { ok: true }
  rescue => e
    puts "#{e.inspect}"    
    { error: e.message }
  end
  

  def self.rename_file(from:, to:, **_)
    return { error: 'Denied path' } if [from, to].any? { |p| DENY_PATHS.any? { |re| re.match?(p) } }
    
    LiveStatus.file_renaming(from, to)
    FileManager.rename(from, to)
    LiveStatus.file_renamed(from, to)
    { ok: true }
  rescue => e
    { error: e.message }
  end
  

  def self.tell_user(message:, level: 'info', **_)
    LiveStatus.info_message(message)
    { say: { level: level, message: message } }
  end


  def self.patch_file(path: nil, diff: nil, dry: false, **_)
    return { error: 'missing :path or :diff' } unless path && diff
    
    diff_lines = diff.lines.count
    LiveStatus.file_patching(path, diff_lines)
    
    return { error: 'Diff too big' } if diff.lines.count > MAX_DIFF
    FileManager.patch(path, diff, dry: dry)
    
    LiveStatus.file_patched(path, diff)
    { ok: true }
  rescue => e
    LiveStatus.file_patched_fail(path, e.message, diff)
    { error: "patch failed: #{e.message}" }
  end


  def self.read_file(path:, range: nil, **_)
    return { error: 'Denied path' } if DENY_PATHS.any? { |re| re.match?(path) }
    LiveStatus.file_reading(path, range)
    
    src = FileManager.read(path)
    result = if range && range.size == 2
      l0, l1 = range
      lines = src.lines[l0..l1] || []
      { content: lines.join, range: [l0, l1] }
    else
      { content: src }
    end
    
    bytes_read = result[:content]&.bytesize || 0
    
    LiveStatus.file_read_complete(path, bytes_read, range, result[:content])
    
    result
  rescue => e
    LiveStatus.file_read_fail(path, e.message, range)
    { error: "#{e.message}" }
  end


  def self.list_files(glob: '**/*', **_)
    files = FileManager.list_files glob
    { files: files }
  end


  def self.run_command(cmd:, **_)
    return { error: 'Blocked command' } unless ALLOW_CMDS.any? { |re| cmd =~ re }
    
    LiveStatus.command_executing(cmd)
    
    begin
      stdout, stderr, status = Open3.capture3(cmdOpen3.capture3, chdir: FileManager.project_root)
      out = (stdout + stderr + "\n(exit #{status.exitstatus})").strip
      LiveStatus.command_completed(cmd, out.length, out)
      
      return { error: "Command failed (exit #{status.exitstatus}): #{stderr}" } unless status.exitstatus == 0
    rescue => e
      return { error: "Command error: #{e.message}" }
    end
    
    { output: out }
  end


  def self.remember(key:, body:, tags: [])
    LiveStatus.memory_storing(key, body.bytesize)
    Mnemosyne.record_note(key, body, tags)
    LiveStatus.memory_stored(key)
    { ok: true }
  end


  def self.recall(query:, limit: 3)
    LiveStatus.memory_searching(query, limit)
    result = { notes: Mnemosyne.search(query, limit: limit) }
    LiveStatus.memory_found(query, result[:notes]&.length || 0)
    result
  rescue e
    { error: e }
  end
end
