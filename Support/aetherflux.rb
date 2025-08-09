# Real-time streaming handler for WebSocket responses
# This ensures status updates appear immediately during AI tool execution
class Aetherflux
  def self.channel_oracle_divination(params, websocket)
    # Ensure HorologiumAeternum is connected to this WebSocket
    HorologiumAeternum.set_websocket websocket
    
    # Start status updates immediately
    HorologiumAeternum.divination "Initializing astral connection..."
    
    # Build context
    ctx = Arcanum.build params
    # HorologiumAeternum.thinking("🧠 Consulting the hermetic oracle...")
    
    # TODO rename answer to revelation
    # Process with real-time streaming
    answer, arts, tool_results = 
      Oracle.divination(params['prompt'], ctx) do |name, args|
        # These status updates now flow immediately to WebSocket
        # HorologiumAeternum.tool_starting(name, args)
        # HorologiumAeternum.processing("⚙️ Executing #{name}...")
        puts "TRY HANDLE TOOL=#{name}, ARGS=#{args.inspect}"
        result = PrimaMateria.handle({ 'tool' => name, 'args' => args })
        puts "TOOL RESULT=#{result}"
        
        # HorologiumAeternum.tool_completed(name, result)
        
        # Small delay to ensure UI updates are processed
        sleep 0.1
        
        result
      end
      
    raise answer unless answer.is_a? String
    
    # Process final artifacts
    # HorologiumAeternum.processing(Scriptorium.html("📋 Processing response artifacts..."))
    
    logs = []
    # (arts[:prelude] || []).each { |t|
    #   logs << { type: 'prelude', data: Scriptorium.html_with_syntax_highlight(t.to_s) }
    # }
    #
    # tool_results.each do |r|
    #   if r[:result].is_a?(Hash) && r[:result][:say]
    #     logs << { type: 'say', data: r[:result][:say] }
    #   end
    # end
    
    html = Scriptorium.html_with_syntax_highlight(answer.to_s)
    Mnemosyne.record(params, answer) if params['record']

    HorologiumAeternum.oracle_revelation(answer.to_s) unless answer.to_s.strip.empty?

    tool_count = tool_results.length
    
    HorologiumAeternum.completed(Scriptorium.html("🎯 Response ready with **#{tool_count}** tools executed"))

    {
      method: 'answer',
      result: {
        answer: answer,
        html: html,
        patch: arts[:patch],
        tasks: arts[:tasks],
        tools: arts[:tools],
        tool_results: tool_results,
        logs: logs,
        next_step: arts[:next_step]
      }
    }
  rescue => e
    { method: 'answer', result: 'error', error: e.error }
  end


  def self.channel_oracle_conjuration(params, context: nil, &exec)
    HorologiumAeternum.divination "Initializing astral connection..."
    
    # Log the invocation
    # HorologiumAeternum.divination "Oracle reasoning stream invoked for prompt: #{prompt}"

    # Delegate tool calls to Oracle.reason with the provided block
    # reasoning_output = Oracle.conjuration(prompt, context, &exec)
    ctx = Arcanum.build params
    # HorologiumAeternum.thinking("🧠 Consulting the hermetic oracle...")
    
    answer, arts, tool_results = 
      Oracle.conjuration(params['prompt'], ctx) do |name, args|
        puts "TRY HANDLE TOOL=#{name}"
        puts "ARGS=#{args.inspect}"
        result = PrimaMateria.handle({ 'tool' => name, 'args' => args })
        puts "TOOL RESULT=#{result}"
        sleep 0.1
        result
      end
        
    logs = []
    arts ||= []
    tool_results ||= []
    
    html = Scriptorium.html_with_syntax_highlight(answer.to_s)
    # Mnemosyne.record(params, answer) if params['record']

    HorologiumAeternum.oracle_revelation(answer.to_s) unless answer.to_s.strip.empty?

    tool_count = tool_results.length
    
    HorologiumAeternum.completed("🎯 Response ready with **#{tool_count}** tools executed")
    
    {
      method: 'answer',
      result: {
        reasoning: arts[:reasoning],
        answer: answer,
        html: html,
        patch: arts[:patch],
        tasks: arts[:tasks],
        tools: arts[:tools],
        tool_results: tool_results, 
        logs: logs,
        next_step: arts[:next_step]
      }
    }
  rescue => e
    puts "#{e.inspect}"
    HorologiumAeternum.server_error("Oracle reasoning stream failed: #{e.message}")
    { error: "Oracle reasoning stream failed: #{e.message}" }
  end
end
