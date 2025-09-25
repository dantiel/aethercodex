require 'yaml'
require 'pathname'
require 'dotenv'
require_relative 'instrumentarium/metaprogramming_utils'



# Unified hierarchical configuration loading system
# Loads .aethercodex files from multiple sources with precedence:
# 1. Current project directory (highest priority)
# 2. User home directory (~/.aethercodex)
# 3. Bundle Support directory (lowest priority)
class CONFIG
  
  class << self
    
    def load_hierarchical_config(start_dir = Dir.pwd)
      configs = []
      
      # 1. Bundle Support directory (lowest priority)
      bundle_config_path = File.expand_path('.aethercodex', __dir__)
      if File.exist?(bundle_config_path)
        bundle_config = load_config_file(bundle_config_path)
        bundle_config[:__source] = :bundle
        configs << bundle_config
      end
      
      # 2. User home directory
      home_config_path = File.expand_path('~/.aethercodex')
      if File.exist?(home_config_path)
        home_config = load_config_file(home_config_path)
        home_config[:__source] = :home
        configs << home_config
      end
      
      # 3. Current project directory and parent directories (highest priority)
      current_dir = Pathname.new(start_dir)
      root_dir = Pathname.new('/')
      
      # Traverse up directory tree until reaching root
      while current_dir != root_dir
        project_config_path = current_dir + '.aethercodex'
        if File.exist?(project_config_path.to_s)
          project_config = load_config_file(project_config_path.to_s)
          project_config[:__source] = :project
          configs << project_config
          break # Stop at first project config found
        end
        current_dir = current_dir.parent
      end
      
      # Merge all configs with proper precedence (first = lowest, last = highest)
      merged_config = {}
      configs.each do |config|
        merged_config = deep_merge(merged_config, config)
      end
      
      # Track the actual source for debugging
      merged_config[:__loaded_from] = merged_config[:__source]
      merged_config.delete(:__source)
      
      # puts "[CONFIG][LOAD_HIERARCHICAL_CONFIG]: merged_config: #{merged_config.inspect}"
      
      merged_config
    end
    
    def load_config_file(path)
      return {} unless File.exist?(path)
      
      begin
        config = YAML.load_file(path) || {}
        symbolize_keys(config)
      rescue => e
        puts "[CONFIG] Error loading #{path}: #{e.message}"
        {}
      end
    end
    
    def symbolize_keys(hash)
      return hash unless hash.is_a?(Hash)
      
      hash.each_with_object({}) do |(key, value), result|
        symbolized_key = key.respond_to?(:to_hermetic_symbol) ? key.to_hermetic_symbol : key
        result[symbolized_key] = if value.is_a?(Hash)
                                  symbolize_keys(value)
                                elsif value.is_a?(Array)
                                  value.map { |v| v.is_a?(Hash) ? symbolize_keys(v) : v }
                                else
                                  value
                                end
      end
    end
    
    def deep_merge(first, second)
      merger = proc do |key, v1, v2|
        if Hash === v1 && Hash === v2
          v1.merge(v2, &merger)
        elsif Array === v1 && Array === v2
          v1 + v2
        else
          v2.nil? ? v1 : v2
        end
      end
      first.merge(second, &merger)
    end
    
  end
  
  # Load configuration hierarchically (initial load)
  CFG = load_hierarchical_config
  
  # Default values
  DEFAULT_CONFIG = {
    port: 4567,
    model: 'deepseek-chat',
    'api-url': 'https://api.deepseek.com/v1/chat/completions',
    'reasoning-model': 'deepseek-reasoner',
    'tm-ai': '.tm-ai/',
    'memory-db': '.tm-ai/memory.db'
  }
  
  # Get configuration value with ENV override and default fallback
  def self.[](key)
    env_key = "AETHER_#{key.to_s.upcase}"
    
    # Check ENV first (highest priority)
    return ENV[env_key] if ENV.key?(env_key)
    
    # Check merged configuration (symbol keys)
    return CFG[key] if CFG.key?(key)
    
    # Check merged configuration (string keys)
    return CFG[key.to_s] if CFG.key?(key.to_s)
    
    # Fall back to default
    DEFAULT_CONFIG[key]
  end
  
  def self.port
    env_port = ENV['AETHER_PORT']
    return env_port.to_i if env_port
    
    config_port = CFG[:port] || CFG['port']
    return config_port.to_i if config_port
    
    DEFAULT_CONFIG[:port]
  end
  
  def self.api_key
    ENV['AETHER_API_KEY'] || CFG[:api_key] || CFG['api-key']
  end
  
  def self.api_url
    ENV['AETHER_API_URL'] || CFG[:api_url] || CFG['api-url'] || DEFAULT_CONFIG[:api_url]
  end
  
  # Check if configuration is loaded from specific source
  def self.loaded_from_project?
    CFG[:__loaded_from] == :project
  end
  
  def self.loaded_from_home?
    CFG[:__loaded_from] == :home
  end
  
  def self.loaded_from_bundle?
    CFG[:__loaded_from] == :bundle
  end
  
  # Debug method to show loaded configuration sources
  def self.debug_info
    {
      port: port,
      api_key: api_key ? "#{api_key[0..8]}..." : nil,
      api_url: api_url,
      model: self[:model],
      reasoning_model: self[:reasoning-model],
      config_sources: CFG.select { |k, _| k.to_s.start_with?('__loaded_from') }
    }
  end
  
  # Resolve a path relative to project root, handling absolute paths
  def self.resolve_path(relative_path)
    # Handle absolute paths (starting with "/")
    return relative_path if relative_path.start_with?('/')
    
    # For relative paths, resolve relative to project root
    project_root = ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd
    File.join(project_root, relative_path)
  end
  
  # Get the tm-ai directory path
  def self.tm_ai_dir
    resolve_path(self[:tm_ai] || '.tm-ai/')
  end
  
  # Get the memory database path
  def self.memory_db_path
    resolve_path(self[:memory_db] || '.tm-ai/memory.db')
  end
  
  # Get the log file path
  def self.log_file_path
    resolve_path('.tm-ai/limen.log')
  end
  
  # Get the PID file path
  def self.pid_file_path
    resolve_path('.tm-ai/limen.pid')
  end
  
  # Get custom allowed commands from configuration
  def self.allowed_commands
    custom_commands = CFG[:allowed_commands] || CFG['allowed-commands'] || []
    
    # Handle wildcard - allow all commands
    return [//] if custom_commands == '*' || custom_commands == ['*']
    
    # Convert string commands to regex patterns
    custom_commands.map do |cmd|
      if cmd.is_a?(Regexp)
        cmd
      else
        /^#{Regexp.escape(cmd.to_s)}\b/
      end
    end
  end
end