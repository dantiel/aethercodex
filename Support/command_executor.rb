require 'open3'
require 'timeout'

class CommandExecutor
  def self.run(cmd)
    stdout, stderr, status = Open3.capture3(cmd)
    (stdout + stderr + "\n(exit #{status.exitstatus})").strip
  end

  def self.run_with_timeout(cmd, seconds)
    stdout = stderr = nil; status = nil
    Timeout.timeout(seconds) do
      stdout, stderr, status = Open3.capture3(cmd)
    end
    (stdout + stderr + "\n(exit #{status.exitstatus})").strip
  rescue Timeout::Error
    "Command timed out after #{seconds}s"
  end
end
