require_relative 'aether_scopes'

# Prefer the current buffer’s top-level scope (e.g., "source.ruby")
top_scope = (ENV['TM_SCOPE'] || '').split.first || 'source.ruby'

puts "ENV['TM_SCOPE']=#{ENV['TM_SCOPE']}"

grammar_path = AetherScopes::Finder.find_by_scope(top_scope)
engine = AetherScopes::Engine.new(grammar_path: grammar_path, fallback_scope: top_scope)

text = File.read './aether_scopes.rb'
# text = STDIN.read
# root = engine.parse(text)

# Example: collect all function-like regions
# funcs = root.find_all('entity.name.function')
#
# funcs.each do |n|
#   puts n.inspect
#   puts "#{n.scope}  L#{n.start_line+1}:#{n.start_col}–L#{n.end_line+1}:#{n.end_col}"
# end


text = <<~RUBY
  class Greeter
    def hello(name)
      puts "Hello, \#{name}"
    end

    def self.wave; end
  end
RUBY

names = AetherScopes.function_names(text, top_scope: 'source.ruby')
names.each do |h|
  puts "#{h[:name]}  @#{h[:range][:start].join(':')}  container=#{h[:container]&.dig(:scope)}"
end
