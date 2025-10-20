#!/usr/bin/env ruby
require 'json'
require 'net/http'

# Test the hermetic live update endpoint
payload = {
  "path" => "test_file.rb",
  "cursor" => 10,
  "content" => "class Example\n  def initialize\n    @value = 42\n  end\n\n  def calculate\n    # TODO: implement calculation\n  end\nend",
  "timestamp" => Time.now.to_f,
  "type" => "hermetic_document_update",
  "scope" => "source.ruby",
  "language" => "ruby"
}

begin
  uri = URI("http://127.0.0.1:4567/hermetic_live_update")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 2
  http.read_timeout = 3
  
  response = http.post(uri.path, JSON.dump(payload), "Content-Type" => "application/json")
  
  puts "Response Code: #{response.code}"
  puts "Response Body: #{response.body}"
rescue => e
  puts "Error: #{e.message}"
  puts "Make sure the server is running on port 5000"
end