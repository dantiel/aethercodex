# frozen_string_literal: true

require 'net/http'
require 'json'

# ÆtherLink — the bridge between contexts.
# Discovers peer AetherCodex servers on localhost (ports 4567–4599)
# and provides cross-context querying, metempsychosis, and task spawning.
#
# === Hermetic Principle: Correspondence ===
# As each context mirrors the whole, so does the Link mirror each context —
# a resonant network where every node reflects and transforms every other.
module AetherLink
  SCAN_RANGE = (4567..4599).freeze
  HEARTBEAT_PATH = '/aether/heartbeat'.freeze
  CONNECT_TIMEOUT = 2
  READ_TIMEOUT = 5

  @known_contexts = {}
  @mutex = Mutex.new

  class << self
    attr_reader :known_contexts

    # Scan localhost ports for peer AetherCodex servers.
    # Calls GET /aether/heartbeat on each candidate and registers responders.
    # Skips own port. Marks unreachable contexts as stale.
    def discover!
      @mutex.synchronize do
        SCAN_RANGE.each do |port|
          next if port == own_port

          info = heartbeat_from(port) or next
          name = info[:name] || info['name'] or next

          @known_contexts[name] = {
            port:         port,
            path:         info[:path] || info['path'],
            capabilities: info[:capabilities] || info['capabilities'] || [],
            version:      info[:version] || info['version'],
            last_seen:    Time.now,
            stale:        false
          }
        end
      end
      @known_contexts
    end

    # Look up a peer context by name.
    def lookup(name)
      @known_contexts[name]
    end

    # POST a JSON payload to a peer context's endpoint.
    # Returns parsed response body (symbolized keys) or nil on failure.
    # Stale contexts are marked and returned nil.
    def query(context_name, endpoint, payload = {})
      ctx = lookup(context_name) or return nil

      uri = URI("http://127.0.0.1:#{ctx[:port]}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      request.body = payload.to_json

      response = http.request(request)
      return nil unless response.code.to_i == 200

      JSON.parse(response.body, symbolize_names: true)
    rescue StandardError
      mark_stale(context_name)
      nil
    end

    # Mark a context as stale (unreachable) — retried on next discover!
    def mark_stale(name)
      ctx = @known_contexts[name]
      ctx[:stale] = true if ctx
    end

    # The name this context advertises to peers (derived from project directory).
    def own_name
      File.basename(Dir.pwd)
    end

    # The port this server runs on.
    def own_port
      ENV['AETHER_PORT']&.to_i || CONFIG.port
    end

    private

    # GET /aether/heartbeat on a given port, return parsed info or nil.
    def heartbeat_from(port)
      uri = URI("http://127.0.0.1:#{port}#{HEARTBEAT_PATH}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = CONNECT_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      response = http.get(uri.path)
      return nil unless response.code.to_i == 200

      JSON.parse(response.body, symbolize_names: true)
    rescue StandardError
      nil
    end
  end
end
