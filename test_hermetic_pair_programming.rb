#!/usr/bin/env ruby
require 'net/http'
require 'json'

# Test the hermetic pair programming system
puts "🧪 Testing Hermetic Pair Programming System..."

# Test payload simulating a document update
test_payload = {
  path: "/Users/test/example.rb",
  cursor: 15,
  content: "class Example\n  def initialize\n    @data = []\n  end\n\n  def process\n    # TODO: implement processing logic\n    \n  end\nend",
  timestamp: Time.now.to_f,
  type: "hermetic_document_update",
  scope: "source.ruby",
  language: "ruby"
}

begin
  uri = URI("http://127.0.0.1:5001/hermetic_live_update")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 2
  http.read_timeout = 5
  
  response = http.post(uri.path, JSON.dump(test_payload), "Content-Type" => "application/json; charset=utf-8")
  
  if response.code == "200"
    result = JSON.parse(response.body)
    puts "✅ Hermetic live update successful!"
    puts "   Status: #{result['status']}"
    puts "   Suggestions: #{result['suggestions']&.length || 0}"
    puts "   Context: #{result['context']}"
  else
    puts "❌ HTTP Error: #{response.code} - #{response.body}"
  end
rescue => e
  puts "❌ Connection failed: #{e.message}"
  puts "   Make sure the live server is running on port 5001"
end

puts "\n📡 Testing regular live update endpoint..."

# Test regular endpoint
test_payload2 = {
  path: "/Users/test/example.rb",
  cursor: 15,
  content: "class Example\n  def initialize\n    @data = []\n  end\n\n  def process\n    # TODO: implement processing logic\n    \n  end\nend",
  timestamp: Time.now.to_f
}

begin
  uri = URI("http://127.0.0.1:5001/live_update")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 2
  http.read_timeout = 5
  
  response = http.post(uri.path, JSON.dump(test_payload2), "Content-Type" => "application/json")
  
  if response.code == "200"
    result = JSON.parse(response.body)
    puts "✅ Regular live update successful!"
    puts "   Status: #{result['status']}"
  else
    puts "❌ HTTP Error: #{response.code} - #{response.body}"
  end
rescue => e
  puts "❌ Connection failed: #{e.message}"
end