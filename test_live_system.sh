#!/bin/bash

# Start the live server in background
cd Support
bundle exec ruby oracle/live_server.rb &
SERVER_PID=$!

# Wait for server to start
sleep 2

# Test the server
echo "Testing live observer server..."
cd ..
ruby test_live_observer.rb

# Kill the server
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo "Test complete."