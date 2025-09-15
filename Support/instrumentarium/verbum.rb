require 'open3'
require 'io/wait'
require 'timeout'

class Verbum
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
  

  def self.run_command_in_real_time(env_vars, cmd, chdir:, timeout_seconds: 60)
    captured_stdout = ""
    captured_stderr = ""
    status = nil

    begin
      Open3.popen3(env_vars, cmd, chdir:) do |stdin, stdout, stderr, wait_thr|
        stdin.close

        # Set the encoding for the output streams to prevent conversion errors.
        stdout.set_encoding(Encoding::UTF_8, invalid: :replace, undef: :replace)
        stderr.set_encoding(Encoding::UTF_8, invalid: :replace, undef: :replace)

        # A map of IO streams to their corresponding captured output
        readers = { stdout => captured_stdout, stderr => captured_stderr }
      
        start_time = Time.now
        child_terminated = false
      
        loop do
          # Exit condition: Process has terminated AND all pipes are closed
          break if child_terminated && readers.empty?


          # Handle timeout
          if Time.now - start_time > timeout_seconds
            Process.kill('TERM', wait_thr.pid)
            raise "Command timed out after #{timeout_seconds} seconds"
          end

          # Check if the child process has terminated
          child_terminated = true if wait_thr.status

          ready, _, _ = IO.select(readers.keys, nil, nil, 1)
        
          # Process any available output
          if ready
            ready.each do |reader|
              begin
                data = reader.read_nonblock(4096)
            
                # Print the output, distinguishing between stdout and stderr
                if reader == stdout
                  # print "[STDOUT] #{data}"
                  readers[reader] << data
                else
                  # print "[STDERR] #{data}"
                  readers[reader] << data
                end
              rescue EOFError
                readers.delete(reader)
              end
            end
          end
        end

        status = wait_thr.value
      end
    
    rescue => e
      captured_stderr ||= ''
      captured_stderr = "#{captured_stderr}\n\n#{e.message}" 
      puts "\nExecution failed: #{e.message}"
    end
  
    if false == status
      status = { success: false }
    end
  
    return captured_stdout, captured_stderr, status
  end
  
end
