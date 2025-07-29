#!/usr/bin/env ruby
# Quick environment diagnostic script

puts "🔮 TextMate Environment Diagnostics:"
puts "=" * 50

tm_vars = ENV.select { |k, v| k.start_with?('TM_') }.sort
tm_vars.each { |k, v| puts "#{k}: #{v.inspect}" }

puts "\n📁 Current Directory: #{Dir.pwd}"
puts "📂 __FILE__: #{__FILE__}"
puts "📁 __dir__: #{__dir__}"

puts "\n🌟 Project Root Resolution:"
require_relative 'file_manager'
ENV['TM_DEBUG_PATHS'] = '1'
puts "Resolved root: #{FileManager.project_root}"