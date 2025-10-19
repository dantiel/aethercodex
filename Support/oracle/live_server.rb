#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require_relative 'live_observer'

# Sinatra server for live observer testing
class LiveObserverServer < Sinatra::Base
  configure do
    set :port, ENV['AETHER_LIVE_PORT'] || 5001
    set :bind, '127.0.0.1'
  end

  post '/live_update' do
    content_type :json
    
    begin
      payload = JSON.parse(request.body.read)
      
      # Process the live update
      result = LiveObserver.process_live_update(payload)
      
      JSON.generate(result)
    rescue JSON::ParserError => e
      status 400
      JSON.generate({ error: 'Invalid JSON payload', details: e.message })
    rescue StandardError => e
      status 500
      JSON.generate({ error: 'Internal server error', details: e.message })
    end
  end

  get '/' do
    content_type :json
    JSON.generate({ status: 'live_observer_server_running', timestamp: Time.now.to_f })
  end
end

# Start the server if this file is run directly
if __FILE__ == $0
  puts "🌌 AetherCodex Live Observer Server starting on port #{LiveObserverServer.settings.port}..."
  puts "📡 Endpoint: http://127.0.0.1:#{LiveObserverServer.settings.port}/live_update"
  LiveObserverServer.run!
end