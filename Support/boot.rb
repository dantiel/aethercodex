#!/usr/bin/env ruby
# frozen_string_literal: true
require 'socket'
require 'json'
require 'fileutils'
require_relative 'config'

SUPPORT = File.expand_path(__dir__)


DEFAULT_PORT = (CONFIG::CFG['port'] || 4567).to_i
PIDFILE  = File.expand_path('../.tm-ai/limen.pid', __dir__)
FileUtils.mkdir_p(File.dirname(PIDFILE))
# puts "PIDFILE=#{PIDFILE}"

# check port
def port_open?(p)
  TCPSocket.new('0.0.0.0', p).close rescue return false
  true
end


# free port finder
def find_free_port
  s = TCPServer.new('0.0.0.0', 0)
  p = s.addr[1]
  s.close
  p
end

port = DEFAULT_PORT
# puts "PORT OPEN #{port_open?(port)}"

unless port_open?(port)
  port = port.zero? ? find_free_port : port
  # Preserve TextMate environment variables
  tm_env = ENV.select { |k, v| k.start_with?('TM_') }
  env = {
    'AETHER_PORT'    => port.to_s,
    'BUNDLE_GEMFILE' => File.join(SUPPORT, 'Gemfile'),
    'AETHER_DAEMON'  => '1',
    'GEM_HOME'       => File.join(SUPPORT, '.vendor_bundle'),
    'GEM_PATH'       => File.join(SUPPORT, '.vendor_bundle'),
    'PATH'           => ENV['PATH']
  }
  # Merge TextMate environment into server environment
  env.merge!(tm_env)
  cmd = ['bundle', 'exec', 'ruby', File.join(SUPPORT, 'limen.rb')]
  pid = spawn(env, *cmd, out: File::NULL, err: File::NULL, pgroup: true)
  File.write(PIDFILE, pid)
  # wait ready
  50.times { break if port_open?(port); sleep 0.2 }
end
STDOUT.print({ port: port }.to_json)
