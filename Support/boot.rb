#!/usr/bin/env ruby
# frozen_string_literal: true
require 'socket'
require 'json'
require 'fileutils'

SUPPORT = File.expand_path(__dir__)
CFG = begin
  require 'yaml'; YAML.load_file(File.join(SUPPORT, '.deepseekrc'))
rescue; {}; end

DEFAULT_PORT = (CFG['port'] || 4567).to_i
PIDFILE  = File.expand_path('../../.tm-ai/gatekeeper.pid', __dir__)
FileUtils.mkdir_p(File.dirname(PIDFILE))


# check port
def port_open?(p)
  TCPSocket.new('127.0.0.1', p).close rescue return false
  true
end


# free port finder
def find_free_port
  s = TCPServer.new('127.0.0.1', 0)
  p = s.addr[1]
  s.close
  p
end


port = DEFAULT_PORT
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
  cmd = ['bundle', 'exec', 'ruby', File.join(SUPPORT, 'gatekeeper.rb')]
  pid = spawn(env, *cmd, out: File::NULL, err: File::NULL, pgroup: true)
  File.write(PIDFILE, pid)
  # wait ready
  50.times { break if port_open?(port); sleep 0.2 }
end
STDOUT.print({ port: port }.to_json)
