#!/bin/bash
# Test the async observer pattern

# Simulate TextMate environment
export TM_BUNDLE_SUPPORT="$PWD/Support"
export TM_PROJECT_DIRECTORY="$PWD"
export TM_FILEPATH="/tmp/test.rb"
export TM_LINE_NUMBER="10"
export TM_REFRESH="DocumentChanged"
export TM_SCOPE="source.ruby"

# Test content
TEST_CONTENT="class Test\n  def method\n    puts 'hello'\n  end\nend"

echo "Testing async observer..."
echo "Time before: $(date +%s.%N)"

# Run the command (simulating TextMate execution)
echo "$TEST_CONTENT" | {
  # IMMEDIATELY fork to background to prevent UI blocking
  {
  set -e
  BUNDLE_SUPPORT="$TM_BUNDLE_SUPPORT"
  PROJECT_ROOT="$TM_PROJECT_DIRECTORY"
  export BUNDLE_GEMFILE="$BUNDLE_SUPPORT/Gemfile"
  export GEM_HOME="$BUNDLE_SUPPORT/.vendor_bundle"
  export GEM_PATH="$GEM_HOME"

  cd "$BUNDLE_SUPPORT"

  # Read document content from stdin
  CONTENT=$(cat)

  # Simple time-based debouncing using file timestamps
  STATE_FILE="/tmp/aethercodex_$(basename "$TM_FILEPATH" 2>/dev/null || echo "unknown")_buffer"
  CURRENT_TIME=$(date +%s)

  # Check if we should skip (processed within last 200ms)
  if [[ -f "$STATE_FILE" ]]; then
    LAST_TIME=$(stat -f %m "$STATE_FILE" 2>/dev/null || echo "0")
    if (( CURRENT_TIME - LAST_TIME < 1 )); then  # 1 second debounce
      exit 0
    fi
  fi

  # Update the buffer state (touch file)
  touch "$STATE_FILE"

  export PORT="4567"

  # Prepare payload with minimal processing
  PAYLOAD_JSON=$(cat << EOF
{
  "path": "$TM_FILEPATH",
  "cursor": $TM_LINE_NUMBER,
  "content": $(ruby -rjson -e 'puts JSON.generate(STDIN.read)' <<< "$CONTENT"),
  "timestamp": $(date +%s.%N),
  "event": "$TM_REFRESH",
  "type": "hermetic_document_update",
  "scope": "$TM_SCOPE",
  "language": "$(echo "$TM_SCOPE" | sed 's/.*\.//')"
}
EOF
  )

  echo "Payload prepared, sending async..."
  
  # Push to server with minimal overhead (no bundle exec)
  ruby -rnet/http -rjson -e '
    begin
      Thread.new do
        uri = URI("http://127.0.0.1:4567/hermetic_live_update")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 0.5
        http.read_timeout = 1
        response = http.post(uri.path, ARGV[0], "Content-Type" => "application/json")
        puts "Server response: #{response.code}"
      end
    rescue StandardError => e
      puts "Error (expected if server down): #{e.message}"
    end
  ' "$PAYLOAD_JSON"

  } &  # This & forks the entire block to background

  echo "Command completed immediately (async)"
}

echo "Time after: $(date +%s.%N)"
echo "TextMate UI would NOT be blocked!"