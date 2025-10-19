#!/usr/bin/env ruby
require 'net/http'
require 'json'

# Test payload simulating a TextMate document update
payload = {
  path: "/Users/test/example.rb",
  cursor: 15,
  content: "class Example\n  def initialize\n    @data = []\n  end\n\n  def add_item(item)\n    @data << item\n  end\n\n  def calculate_total\n    # TODO: implement total calculation\n    # Cursor is here\n  end\nend",
  timestamp: Time.now.to_f
}

begin
  uri = URI("http://127.0.0.1:5001/live_update")
  response = Net::HTTP.post(uri, JSON.dump(payload), "Content-Type" => "application/json")
  puts "Response: #{response.code} - #{response.body}"
rescue StandardError => e
  puts "Error: #{e.message}"
end