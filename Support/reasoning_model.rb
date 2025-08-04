module ReasoningModel
  def self.ask_with_filtered_tools(prompt, tools)
    # Filter out the reasoning model tool to prevent recursive calls
    filtered_tools = tools.reject { |tool| tool[:name] == "reasoning_model" || tool[:name] == "ask_with_filtered_tools" }
    
    # Reuse the existing `divination` function with the filtered tools
    AetherFlux.divination(prompt, filtered_tools)
  end
end