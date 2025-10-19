#!/usr/bin/env ruby
require_relative 'Support/config'

# Test FIM completion through the actual system
puts "Testing FIM Completion System..."

begin
  result = FimCompletion.complete(
    before_context: 'def calculate_sum(numbers)',
    after_context: 'end',
    file_path: 'test.rb',
    cursor_line: 1,
    cursor_column: 0
  )
  
  puts "FIM Result: #{result.inspect}"
  
  if result && !result.empty?
    puts "SUCCESS: FIM completion is working!"
    puts "Generated code:"
    puts result
  else
    puts "WARNING: FIM completion returned empty result"
  end
rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace.join("\n")
end