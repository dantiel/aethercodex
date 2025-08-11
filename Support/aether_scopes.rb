# gem install textpow
require 'textpow'
require 'plist'
require 'yaml'

module AetherScopes
  NAME_SCOPE_PREFIXES = [
    'entity.name.function',
    'entity.name.method',
    'entity.name.function.definition',
    'entity.name.method.definition'
  ].freeze

  CONTAINER_SCOPE_PREFIXES = [
    'meta.function',
    'meta.method'
  ].freeze

  class Node
    attr_accessor :scope, :children, :start_byte, :end_byte,
                  :start_line, :start_col, :end_line, :end_col, :parent
    def initialize(scope:, start_byte:, start_line:, start_col:, parent:)
      @scope, @children, @parent = scope, [], parent
      @start_byte, @start_line, @start_col = start_byte, start_line, start_col
      @end_byte = @end_line = @end_col = nil
    end
    def close!(end_byte:, end_line:, end_col:)
      @end_byte, @end_line, @end_col = end_byte, end_line, end_col
    end
    def matches_prefix?(prefixes) = prefixes.any? { |p| scope.start_with?(p) }
    def ancestor_matching(prefixes)
      n = self
      while n
        return n if n.matches_prefix?(prefixes)
        n = n.parent
      end
      nil
    end
    def walk(&blk); yield self; children.each { |c| c.walk(&blk) }; end

    # Simple prefix match (fast + useful in practice)
    def matches?(selector_prefix)
      return true if selector_prefix.nil? || selector_prefix.empty?
      scope.start_with?(selector_prefix)
    end
    
    def find_all(selector_prefix, out = [])
      walk { |n| out << n if n.matches?(selector_prefix) }
      out
    end
  end

  class TreeBuilder
    def initialize(text, line_offsets)
      @text, @line_offsets = text, line_offsets
      @line_index = 0
      @root = Node.new(scope: 'source', start_byte: 0, start_line: 0, start_col: 0, parent: nil)
      @stack = [@root]
    end
    attr_reader :root

    def new_line(_line_content)
      @line_index += 1 unless @line_index.zero?
    end

    def open_tag(scope_name, col)
      abs = @line_offsets[@line_index] + col
      node = Node.new(scope: scope_name, start_byte: abs, start_line: @line_index, start_col: col, parent: @stack.last)
      @stack.last.children << node
      @stack << node
    end

    def close_tag(scope_name, col)
      abs = @line_offsets[@line_index] + col
      while @stack.size > 1
        n = @stack.pop
        n.close!(end_byte: abs, end_line: @line_index, end_col: col)
        break if n.scope == scope_name
      end
    end
    
    
    def start_parsing(_scope_name); end 
    
    def end_parsing(_scope_name);   end
  end

  class Engine
    def initialize(grammar_path: nil, fallback_scope: 'source.ruby')
      @syntax = grammar_path ? Textpow::SyntaxNode.load(grammar_path) : Textpow.syntax(fallback_scope)
    end

    def parse(text)
      lines = text.split("\n", -1)
      offsets, off = [], 0
      lines.each { |l| offsets << off; off += l.bytesize + 1 } # assumes "\n"
      builder = TreeBuilder.new(text, offsets)
      @syntax.parse(text, builder)
      builder.root
    end
  end

  module Finder
    module_function
    CANDIDATE_DIRS = [
      File.expand_path('~/Library/Application Support/TextMate/Bundles'),
      File.expand_path('~/Library/Application Support/TextMate/Managed/Bundles')
    ].freeze
    CANDIDATE_EXTS = %w[tmLanguage plist tmSyntax syntax].freeze

    def find_by_scope(scope_name)
      CANDIDATE_DIRS.each do |dir|
        next unless Dir.exist?(dir)
        Dir.glob(File.join(dir, '**', "*.{#{CANDIDATE_EXTS.join(',')}}")).each do |path|
          begin
            data =
              case File.extname(path)
              when '.syntax' then YAML.safe_load(File.read(path))
              else Plist.parse_xml(path)
              end
            return path if data && data['scopeName'] == scope_name
          rescue StandardError
          end
        end
      end
      nil
    end
  end

  # === Public helper: extract function names ===
  def self.function_names(text, top_scope: nil)
    top_scope ||= (ENV['TM_SCOPE'] || '').split.first || 'source'
    grammar = Finder.find_by_scope(top_scope)
    eng     = Engine.new(grammar_path: grammar, fallback_scope: top_scope)
    root    = eng.parse(text)

    out = []
    root.walk do |n|
      next unless n.matches_prefix?(NAME_SCOPE_PREFIXES)
      next unless n.end_byte # unopened/unterminated safety

      name = text.byteslice(n.start_byte...n.end_byte).to_s
      container = n.ancestor_matching(CONTAINER_SCOPE_PREFIXES)

      out << {
        name: name,
        scope: n.scope,
        range: { start: [n.start_line+1, n.start_col], end: [n.end_line+1, n.end_col] },
        container: container && {
          scope: container.scope,
          range: {
            start: [container.start_line+1, container.start_col],
            end:   [container.end_line+1, container.end_col]
          }
        }
      }
    end
    out
  end
end

# --- example usage ---
if __FILE__ == $0
  sample = <<~RUBY
    class Greeter
      def hello(name)
        puts "Hello, \#{name}"
      end

      def self.wave; end
    end
  RUBY

  names = AetherScopes.function_names(sample, top_scope: 'source.ruby')
  names.each do |h|
    puts "#{h[:name]}  @#{h[:range][:start].join(':')}  container=#{h[:container]&.dig(:scope)}"
  end
end
