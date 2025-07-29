# Real-time streaming handler for WebSocket responses
# This ensures status updates appear immediately during AI tool execution

module StreamingHandler
  def self.handle_askAI_streaming(params, websocket)
    # Ensure LiveStatus is connected to this WebSocket
    LiveStatus.set_websocket(websocket)
    
    # Start status updates immediately
    LiveStatus.divination("Initializing astral connection...")
    
    # Build context
    ctx = ContextBuilder.build(params)
    # LiveStatus.thinking("🧠 Consulting the hermetic oracle...")
    
    # Process with real-time streaming
    answer, arts, tool_results = 
      AIClient.ask_with_tools(params['prompt'], ctx) do |name, args|
        # These status updates now flow immediately to WebSocket
        # LiveStatus.tool_starting(name, args)
        # LiveStatus.processing("⚙️ Executing #{name}...")
        
        result = Toolbox.handle({ 'tool' => name, 'args' => args })
        
        # LiveStatus.tool_completed(name, result)
        
        # Small delay to ensure UI updates are processed
        sleep(0.1)
        
        result
      end
        
    # Process final artifacts
    # LiveStatus.processing(MarkdownRenderer.html("📋 Processing response artifacts..."))
    
    logs = []
    # (arts[:prelude] || []).each { |t|
    #   logs << { type: 'prelude', data: MarkdownRenderer.html_with_syntax_highlight(t.to_s) }
    # }
    #
    # tool_results.each do |r|
    #   if r[:result].is_a?(Hash) && r[:result][:say]
    #     logs << { type: 'say', data: r[:result][:say] }
    #   end
    # end
    
    html = MarkdownRenderer.html_with_syntax_highlight(answer.to_s)
    Mnemosyne.record(params, answer) if params['record']

    LiveStatus.ai_response(answer.to_s) unless answer.to_s.strip.empty?

    tool_count = tool_results.length
    
    LiveStatus.completed(MarkdownRenderer.html("🎯 Response ready with **#{tool_count}** tools executed"))
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
    puts e.inspect
    { method: 'answer', result: 'error' }
  end
end
