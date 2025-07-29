# Support/ai_client.rb
require 'faraday'
require 'json'
require 'time'
require 'fileutils'
# frozen_string_literal: true
require 'faraday'
require 'json'
require 'time'
require 'fileutils'
require_relative 'mnemosyne'
require_relative 'tools'
require_relative 'live_status'
require_relative 'markdown_renderer'



# Enhanced AI Client with Hermetic Debugging
# This module provides advanced debugging capabilities for the Atlantean Oracle
# Includes patch expansion, error tracking, and astral plane monitoring
# Version: 2.1.0-hermetic


class AIClient
  ENDPOINT = 'https://api.deepseek.com/v1/chat/completions'
  SYSTEM_PROMPT = File.read "#{__dir__}/aether_codex.system_instructions"
  

  def self.deep_symbolize(obj)
    case obj
    when Hash  then obj.each_with_object({}) { |(k,v),h| h[k.to_sym] = deep_symbolize(v) }
    when Array then obj.map { |v| deep_symbolize(v) }
    else obj end
  end


  TOOL_ALIASES = { 'readfile'   => 'read_file',
                   'patchfile'  => 'patch_file',
                   'createfile' => 'create_file',
                   'runcommand' => 'run_command',
                   'renamefile' => 'rename_file',
                   'telluser'   => 'tell_user' }


  def self.normalize_tool_name(n)
    TOOL_ALIASES[n.to_s.downcase.gsub(/[^a-z_]/,'')] || n
  end
  
  
  def self.ask(prompt, ctx)
    a, arts, _ = ask_with_tools(prompt, ctx){|name,args| Toolbox.handle({'tool'=>name,'args'=>args})}
    [a, arts]
  end


  def self.ask_with_tools(prompt, ctx, max_depth: 50, &exec)
    puts "=========================================="
    # puts "Ask AI with Context=#{ctx.inspect}"
    msgs = base_messages(prompt, ctx)
    tool_results = []
    arts   = { prelude: [] }
    answer = nil
    depth = 0

    # Stream initial status
    if defined?(LiveStatus)
      sleep(0.1) # Brief pause for UI responsiveness
      LiveStatus.thinking("Consulting the hermetic oracle...")
    end

    loop do
      depth += 1
      
      body = build_body_from_messages(msgs, want_json: false)
      raw  = post(body)
      json = ensure_json(raw)
      log_json(json: json)#, project_dir: ENV['TM_PROJECT_DIRECTORY'])

      choice = json.dig('choices', 0) || {}
      msg    = choice['message'] || {}
      content = msg['content'].to_s
      tcalls = msg['tool_calls'] || []
      arts[:reasoning_content] = msg['reasoning_content'].to_s if msg['reasoning_content']
      # arts[:next_step] = msg['reasoning_content'].to_s if msg['reasoning_content']

      assistant_msg = { role: 'assistant', content: content }
      assistant_msg[:tool_calls] = tcalls if tcalls.any?
      msgs << assistant_msg
      
      arts[:prelude] << content unless content.strip.empty?
      
      # Hermetic debugging: Track patch operations for expandable display
      #if tcalls.any? && tcalls.any? { |tc| tc.dig('function', 'name') == 'patch_file' }
      #  LiveStatus.thinking("🔮 Applying ethereal patches to the code plane...")
      #end
      LiveStatus.thinking(arts[:reasoning_content]) if arts[:reasoning_content]
      
      if tcalls.any?
        if defined?(LiveStatus) && !content.strip.empty?
          LiveStatus.ai_response(content)
        end
        
        tcalls.each do |tc|
          name = normalize_tool_name(tc.dig('function', 'name'))
          args = deep_symbolize(safe_parse(tc.dig('function', 'arguments')))
          
          res  = exec.call(name, args)
          sleep(0.05) if defined?(LiveStatus)
          tool_results << { id: tc['id'], name: name, result: res }
          msgs << { role: 'tool', tool_call_id: tc['id'], content: res.to_json }          
        end
        break if depth >= max_depth
        next
      end

      # Fallback: JSON in content
      parsed  = safe_parse(msg['content'])
      tools_from_content = extract_tools_from_content(parsed)
      arts[:plan] = parsed['plan'] if parsed.is_a?(Hash) && parsed['plan']

      if tools_from_content.any?
        arts[:tools]     = tools_from_content
        arts[:next_step] = parsed['next_step'] || parsed['nextstep']
        answer           = parsed['answer'] || ''

        # Stream plan if available
        if defined?(LiveStatus) && arts[:plan]
          LiveStatus.thinking("Plan: #{arts[:plan].join(' → ')}")
        end
        tools_from_content.each do |call|
          res = exec.call(call['tool'], deep_symbolize(call['args'] || {}))
          tool_results << { name: call['tool'], result: res }
        end

        break if depth >= max_depth
        msgs << { role: 'user', content: "Tool results:\n#{tool_results.last[:result].to_json}\nContinue." }
        next
      else
        answer = content
        arts.merge!(extract_artifacts(answer.to_s))
        break
      end
    end

    [answer || '<<empty>>', arts, tool_results]
  rescue => e
    log_json(error: e.message, backtrace: e.backtrace)
    LiveStatus.server_error e.message
    ["<error> #{e.message}", { patch: nil, tasks: nil, tools: [], prelude: [] }, tool_results]
  end


  def self.extract_tools_from_content(parsed)
    return [] unless parsed.is_a?(Hash) && parsed['tools'].is_a?(Array)
    parsed['tools'].map do |t|  
      { 'tool' => normalize_tool_name(t['tool'] || t[:tool]),
        'args' => deep_symbolize(t['args'] || {}) }
    end
  end


  def self.base_messages(prompt, ctx)
    [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user',   content: "Context: #{ctx.to_json}" },
      { role: 'user',   content: prompt },
    ]
  end
  
  
  def self.build_body_from_messages(messages, want_json: false)
    cfg = load_cfg
    body = {
      model: cfg['model'] || 'deepseek-chat',
      messages: messages,
      max_tokens: 2048
    }
    unless want_json
      body[:tools] = TOOLS
    else
      # body[:response_format] = { type: 'json_object' }
      body[:response_format] = { type: 'text' }
    end
    body
  end


  def self.complete(ctx)
    prompt = "Provide a code completion for the cursor based on context:\n#{ctx[:snippet]}"
    body = build_body(prompt, ctx)
    raw  = post(body)
    json = ensure_json(raw)
    log_json(json: json)
    msg = json.dig('choices',0,'message','content') || ''
    msg
  rescue => e
    log_json(error: e.message, backtrace: e.backtrace)
    ''
  end
  

  def self.build_body(prompt, ctx)
    cfg = load_cfg
    {
      model:  cfg['model'] || 'reasoning-1',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user',   content: prompt },
        { role: 'user',   content: "Context: #{ctx.to_json}" }
      ],
      response_format: { type: 'json_object' },
      tools: TOOLS,
      max_tokens: 2048
    }
  end


  def self.post(body)
    cfg = load_cfg
    key = cfg['api_key'] || ENV['DEEPSEEK_API_KEY']
    raise 'Missing DeepSeek API key' if key.to_s.strip.empty?

    conn = Faraday.new do |f|
      f.request :json
      f.response :raise_error
      f.adapter Faraday.default_adapter
    end

    resp = conn.post(ENDPOINT) do |req|
      req.headers['Authorization'] = "Bearer #{key}"
      req.headers['Content-Type']  = 'application/json'
      # req.headers['Content-Type']  = 'application/json'
      req.body = body.to_json
      req.options.timeout = 120
      
      # log_json(post: req)
    end
    resp.body
  rescue Faraday::Error => e
    (e.response && e.response[:body]) || e.message
  end


  def self.ensure_json(raw)
    return raw if raw.is_a?(Hash)
    JSON.parse(raw)
  rescue JSON::ParserError
    { 'error' => raw.to_s }
  end
  
  
  def self.extract_artifacts(text)
    patch      = text[/```patch\n(.*?)```/m, 1]
    tasks_json = text[/```tasks\n(.*?)```/m, 1]
    tools_json = text[/```aether\.tools\n(.*?)```/m, 1]
    tools = tools_json ? JSON.parse(tools_json)['tools'] : nil
    tasks = tasks_json ? JSON.parse(tasks_json) : nil
    { patch: patch, tasks: tasks, tools: tools }
  rescue
    { patch: nil, tasks: nil, tools: nil }
  end


  def self.safe_parse(str)
    JSON.parse(str)
  rescue
    {}
  end


  def self.log_json(obj)
    logf = File.expand_path('../../.tm-ai/gatekeeper.log', __FILE__)
    FileUtils.mkdir_p(File.dirname(logf))
    File.open(logf, 'a') { |f| f.puts("#{Time.now.iso8601} #{obj.to_json}") }
  rescue => e
    warn "log_json failed: #{e.message}"
  end


  def self.load_cfg
    path = File.expand_path('../.deepseekrc', __FILE__)
    File.exist?(path) ? YAML.load_file(path) : {}
  end
end
