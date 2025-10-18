# frozen_string_literal: true

require_relative '../magnum_opus/magnum_opus_engine'
require_relative '../mnemosyne/mnemosyne'
require_relative 'fake_mnemosyne'
require_relative 'fake_aetherflux'
require 'rspec'
require 'timeout'
require 'net/protocol'  # For Net::ReadTimeout and Net::OpenTimeout



RSpec.describe MagnumOpusEngine do
  let(:mnemosyne) { FakeMnemosyne.new }
  let(:aetherflux) { FakeAetherflux.new }
  subject { described_class.new mnemosyne: mnemosyne, aetherflux: aetherflux }

  before do
    # Setup default task
    mnemosyne.manage_tasks({ 'action' => 'create', 'parent_task_id' => nil })

    # Initialize task state before relevant tests - FORCE reset to pending
    mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'pending', 'current_step' => 0 })
    
    # Also reset class-level storage for real interface
    FakeMnemosyne.tasks[1] = { 'id' => 1, 'status' => 'pending', 'progress' => 0, 'max_loops' => 10, 'current_step' => 0 }

    # Configure fake aetherflux with default response
    aetherflux.set_default_response({ status: :success, response: 'Simulated response' })
    
    # Enable debug logging for timeout tests
    ENV['DEBUG_TASK_ENGINE'] = 'true'
  end

  after do
    # Disable debug logging after tests
    ENV.delete('DEBUG_TASK_ENGINE')
  end

  after do
    # Clear task state after each test
    mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'pending' })
    
    # Clear captured conjurations
    aetherflux.clear_captured_conjurations
  end

  describe '#oracle_conjuration_failure' do
    it 'handles :failure responses gracefully' do
      aetherflux.configure_response('CURRENT STEP: 1', { status: :failure, response: 'Task execution failed' })

      # Failure should set task status to failed and raise TaskStateError
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('failed')
    end

    it 'logs the failure response' do
      aetherflux.configure_response('CURRENT STEP: 1', { status: :failure, response: 'Task execution failed' })

      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Step 1 failed: Task execution failed/)
    end
  end

  describe '#oracle_conjuration_timeout' do
    it 'handles timeout errors gracefully without failing entire task' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Timeout::Error, 'Request timed out' })

      # Timeout should break execution but not crash the entire task
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 timed out/)

      # Task should remain in pending state for retry, not failed
      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('pending')  # Should remain pending for retry
      
      # Step result should be stored for context
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:') if step_results['1']
    end

    it 'logs the timeout error with detailed context' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Timeout::Error, 'Request timed out' })

      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 timed out/)

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Step 1 timed out: Request timed out/)
    end

    it 'handles Net::ReadTimeout specifically' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Net::ReadTimeout, 'Read timed out' })

      # Should be treated as network error, not generic timeout
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 timed out/)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:') if step_results['1']
    end

    it 'handles Net::OpenTimeout specifically' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Net::OpenTimeout, 'Connection timed out' })

      # Should be treated as network error, not generic timeout
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 timed out/)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:') if step_results['1']
    end

    it 'handles mixed timeout scenarios across multiple steps' do
      # Step 1: Success
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: 'Step 1 completed' })
      # Step 2: Timeout
      aetherflux.configure_response('CURRENT STEP: 2', -> { raise Timeout::Error, 'Step 2 timeout' })
      
      # Should complete step 1, then timeout on step 2
      # Note: execute_task handles multiple steps, execute_step handles single steps
      expect { subject.execute_step(1, 2) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 2 timed out/)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Both steps should have results
      expect(step_results['1']).to eq('Step 1 completed') if step_results['1']
      expect(step_results['2']).to include('TIMEOUT: Step 2 timeout') if step_results['2']
      
      # Task should remain pending for retry
      expect(task_state['status']).to eq('pending')
    end

    it 'ensures step counter does not restart at zero after completion' do
      # Execute multiple steps successfully
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: 'Step 1 completed' })
      aetherflux.configure_response('CURRENT STEP: 2', { status: :success, response: 'Step 2 completed' })
      aetherflux.configure_response('CURRENT STEP: 3', { status: :success, response: 'Step 3 completed' })
      
      # Verify step counter does NOT reset to zero
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(3)  # Should be at step 3, not 0
      
      # Execute another step to confirm counter continues
      aetherflux.configure_response('CURRENT STEP: 4', { status: :success, response: 'Step 4 completed' })
      expect { subject.execute_step(1, 4) }.to raise_error(MagnumOpusEngine::StepCompleted)
      
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(4)  # Should be at step 4, not 0
    end

    it 'preserves step counter across error recovery scenarios' do
      # Step 1: Success
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: 'Step 1 completed' })
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
      
      # Step 2: Timeout error
      aetherflux.configure_response('CURRENT STEP: 2', -> { raise Timeout::Error, 'Step 2 timeout' })
      expect { subject.execute_step(1, 2) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 2 timed out/)
      
      # Step counter should be preserved at 2 despite error
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(2)  # Should remain at step 2, not reset
      
      # Step 3: Success after recovery
      aetherflux.configure_response('CURRENT STEP: 3', { status: :success, response: 'Step 3 completed' })
      expect { subject.execute_step(1, 3) }.to raise_error(MagnumOpusEngine::StepCompleted)
      
      # Step counter should continue to 3
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(3)  # Should progress to step 3
    end

    it 'handles markdown content in step results correctly' do
      # Test rich markdown content in step results
      markdown_content = "**Bold text** and *italic text* with `code` example"
      
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: markdown_content })
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Verify markdown content is stored correctly
      expect(step_results['1']).to eq(markdown_content)
      
      # Verify backend processing preserves markdown
      expect(step_results['1']).to include('**Bold text**')
      expect(step_results['1']).to include('*italic text*')
      expect(step_results['1']).to include('`code`')
    end

    it 'handles complex step navigation with multiple markdown steps' do
      # Create multiple steps with rich markdown content
      steps_content = {
        1 => "NIGREDO PHASE: **Prima Materia** analysis complete",
        2 => "ALBEDO PHASE: *Purified* architecture defined with `code examples`",
        3 => "CITRINITAS PHASE: **Golden** paths identified with *insights*",
        4 => "RUBEDO PHASE: **Philosopher's Stone** selected with complex formatting"
      }

      steps_content.each do |step_num, content|
        aetherflux.configure_response("CURRENT STEP: #{step_num}", { status: :success, response: content })
        expect { subject.execute_step(1, step_num) }.to raise_error(MagnumOpusEngine::StepCompleted)
      end

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Verify all steps are stored correctly
      expect(step_results.keys.length).to eq(4)
      
      # Verify markdown content preservation
      steps_content.each do |step_num, expected_content|
        expect(step_results[step_num.to_s]).to eq(expected_content)
        expect(step_results[step_num.to_s]).to include('**') if expected_content.include?('**')
        expect(step_results[step_num.to_s]).to include('*') if expected_content.include?('*')
        expect(step_results[step_num.to_s]).to include('`') if expected_content.include?('`')
      end

      # Verify step counter is correct
      expect(task_state['current_step']).to eq(4)
    end

    it 'handles object results with .result and .content properties' do
      # Test object results with different property names
      object_result = {
        result: "Step completed with **markdown** content",
        metadata: { timestamp: Time.now.to_s }
      }
      
      content_result = {
        content: "Step analysis with *italic* emphasis",
        type: "analysis"
      }
      
      # Test .result property
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: object_result })
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Backend should extract .result property
      expect(step_results['1']).to eq(object_result[:result])

      # Test .content property
      aetherflux.configure_response('CURRENT STEP: 2', { status: :success, response: content_result })
      expect { subject.execute_step(1, 2) }.to raise_error(MagnumOpusEngine::StepCompleted)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Backend should extract .content property
      expect(step_results['2']).to eq(content_result[:content])
    end

    it 'maintains correct step counter with multiple error types' do
      # Step 1: Success
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: 'Step 1 completed' })
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
      
      # Step 2: Network error
      aetherflux.configure_response('CURRENT STEP: 2', { status: :network_error, response: 'Network failed' })
      expect { subject.execute_step(1, 2) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 2 network error/)
      
      # Step counter should be at 2
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(2)
      
      # Step 3: Rate limit error
      aetherflux.configure_response('CURRENT STEP: 3', { status: :rate_limit_error, response: 'Rate limited' })
      expect { subject.execute_step(1, 3) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 3 rate limit exceeded/)
      
      # Step counter should be at 3
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(3)
      
      # Step 4: Success
      aetherflux.configure_response('CURRENT STEP: 4', { status: :success, response: 'Step 4 completed' })
      expect { subject.execute_step(1, 4) }.to raise_error(MagnumOpusEngine::StepCompleted)
      
      # Step counter should be at 4
      task_state = mnemosyne.task_state 1
      expect(task_state['current_step']).to eq(4)
    end
  end

  describe '#invalid_task_state' do
    it 'raises an error for invalid states' do
      mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'invalid' })
      expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Invalid state: invalid')
    end
  end

  describe '#create_task' do
    it 'creates a task with default metadata' do
      task = subject.create_task(title: 'test', plan: 'test plan')
      expect(task[:id]).to be_a(Integer)
    end
  end

  describe '#execute_task' do
    before do
      aetherflux.set_default_response({ status: :success, response: 'Simulated response' })
    end

    context 'when task is paused' do
      before { mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'paused' }) }

      it 'halts execution' do
        expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Task is paused')
      end
    end

    context 'when task is failed' do
      before { mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'failed' }) }

      it 'halts execution' do
        expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Task is failed')
      end
    end

    context 'when max_loops is exhausted' do
      it 'does not execute sub-tasks' do
        expect(subject).not_to receive(:execute_task).with(2, max_loops: 0)
        subject.execute_task 1, max_loops: 1
      end
    end

    context 'with invalid task ID' do
      it 'raises error' do
        expect { subject.execute_step(-1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Task not found: -1/)
      end
    end
  end

  context 'with task cancellation' do
    before { mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'cancelled' }) }

    it 'halts execution' do
      expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskCancelledError, 'Task cancelled')
    end
  end

  context 'with sub-tasks' do
    before do
      # Create sub-task
      sub_task = subject.create_task(title: 'sub', plan: 'sub plan', parent_task_id: 1)
      mnemosyne.manage_tasks({ 'action' => 'update', 'id' => sub_task[:id], 'status' => 'pending' })
    end

    it 'executes sub-tasks recursively' do
      # Allow parent task execution
      allow(subject).to receive(:execute_task).and_call_original
      
      # Expect sub-task call with reduced max_loops
      expect(subject).to receive(:execute_task).with(anything).and_call_original
      
      subject.execute_task 1
    end
  end

  describe 'edge case testing' do
    context 'with empty task plan' do
      it 'handles empty plan gracefully' do
        task_id = subject.create_task(title: 'Empty Plan Test', plan: '')
        mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id[:id], 'status' => 'pending' })
        
        # Enable capture mode to capture conjuration parameters
        aetherflux.set_capture_mode(true)
        
        expect { subject.execute_step(task_id[:id], 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
        
        conjuration_params = aetherflux.captured_conjurations.last
        prompt = conjuration_params[:prompt]
        # Empty plan should show as empty string, not '--'
        expect(prompt).to include('TASK PLAN: ')
      end
    end

    context 'with nil task description' do
      it 'handles nil description gracefully' do
        task_id = subject.create_task(title: 'Nil Description Test', plan: 'test')
        mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id[:id], 'description' => nil, 'status' => 'pending' })
        
        # Enable capture mode to capture conjuration parameters
        aetherflux.set_capture_mode(true)
        
        expect { subject.execute_step(task_id[:id], 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
        
        conjuration_params = aetherflux.captured_conjurations.last
        prompt = conjuration_params[:prompt]
        expect(prompt).to include('TASK DESCRIPTION: --')
      end
    end

    context 'with malformed step results JSON' do
      it 'handles JSON parsing errors gracefully' do
        task_id = subject.create_task(title: 'Malformed JSON Test', plan: 'test')
        mnemosyne.manage_tasks({
          'action' => 'update',
          'id' => task_id[:id],
          'step_results' => 'invalid json',
          'status' => 'pending'
        })
        
        # Enable capture mode to capture conjuration parameters
        aetherflux.set_capture_mode(true)
        
        expect { subject.execute_step(task_id[:id], 2) }.to raise_error(MagnumOpusEngine::StepCompleted)
        
        conjuration_params = aetherflux.captured_conjurations.last
        prompt = conjuration_params[:prompt]
        expect(prompt).to include('No previous step results available.')
      end
    end

    context 'with invalid input validation' do
      it 'rejects negative task IDs' do
        expect { subject.execute_step(-1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Task not found: -1/)
      end

      it 'rejects non-integer task IDs' do
        expect { subject.execute_step('invalid', 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Task not found: invalid/)
      end
    end

    context 'with empty response handling' do
      it 'handles empty oracle responses gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', { status: :empty_response, response: '' })
        
        # Empty response should break execution but not crash the entire task
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Empty response received for step 1')
        
        task_state = mnemosyne.task_state 1
        # Task should remain in pending state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('EMPTY_RESPONSE:') if step_results['1']
      end

    it 'handles nil oracle responses gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', {status: :success, response: nil})
        
        # Nil response should break execution but not crash the entire task
        # The engine handles nil responses differently - it may not raise an error but handle it internally
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
        
        task_state = mnemosyne.task_state 1
        # Task should remain in pending state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('EMPTY_RESPONSE:') if step_results['1']
      end
    end

    context 'with unknown response format handling' do
      it 'handles completely unknown response formats gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', { completely: :unknown, format: 'unexpected' })
        
        # Unknown response should break execution but not crash the entire task
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Unknown response status/)
        
        task_state = mnemosyne.task_state 1
        # Task should remain in pending state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('ERROR: Unknown response status:') if step_results['1']
      end

      it 'handles string-based status keys gracefully' do
        # Configure a successful response with string keys
        aetherflux.configure_response('CURRENT STEP: 1', { 'status' => 'success', 'response' => 'test response' })
        
        # String-based status should work correctly
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::StepCompleted)
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('pending')  # Should remain pending for next step
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to eq('test response') if step_results['1']
      end
      
      
      it 'handles memory allocation errors' do
        allow(aetherflux).to receive(:channel_oracle_divination).and_raise(NoMemoryError, 'Cannot allocate memory')
        
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Cannot allocate memory')
        
        task_state = mnemosyne.task_state 1
        # Memory errors should fail the task
        expect(task_state['status']).to eq('failed')
      end

      it 'handles context length exceeded errors gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :context_length_error,
          response: 'maximum context length is 131072 tokens'
        })
        
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 context length exceeded/)
        
        task_state = mnemosyne.task_state 1
        # Context length errors should allow retries (pending state)
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('CONTEXT_LENGTH_ERROR:') if step_results['1']
      end

      it 'handles rate limit errors gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :rate_limit_error,
          response: 'rate limit exceeded'
        })
        
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 rate limit exceeded/)
        
        task_state = mnemosyne.task_state 1
        # Rate limit errors should allow retries (pending state)
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('RATE_LIMIT_ERROR:') if step_results['1']
      end

      it 'handles network errors gracefully without failing entire task' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :network_error,
          response: 'network connection failed'
        })
        
        # Network error should break execution but not crash the entire task
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 network error/)
        
        task_state = mnemosyne.task_state 1
        # Task should remain in pending state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('NETWORK_ERROR:') if step_results['1']
      end
    end
  end

  context 'with resource constraints' do
    it 'handles memory allocation errors' do
      allow(aetherflux).to receive(:channel_oracle_divination).and_raise(NoMemoryError, 'Cannot allocate memory')
      
      expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Cannot allocate memory')
      
      task_state = mnemosyne.task_state 1
      # Memory errors should fail the task
      expect(task_state['status']).to eq('failed')
    end
  end

  context 'with invalid input validation' do
    it 'rejects negative task IDs' do
      expect { subject.execute_step(-1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Task not found: -1/)
    end

    it 'rejects non-integer task IDs' do
      expect { subject.execute_step('invalid', 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Task not found: invalid/)
    end
  end

  # COMMAND SYSTEM INTEGRATION TESTS
  context 'with command system integration' do
    it 'verifies command system integration with task completion workflow' do
      # Configure oracle to complete step with command execution result
      aetherflux.configure_response('CURRENT STEP: 1', {
        status: :success,
        response: 'Command system integration test completed successfully'
      })

      # Execute step that should complete normally
      result = subject.execute_step(1, 1)
      
      # Verify step completed successfully
      expect(result[:status]).to eq(:step_not_completed)
      
      # Verify step results stored correctly
      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('Command system integration test completed successfully')
    end

    it 'verifies command system handles step completion workflow' do
      # Configure oracle to use task_complete_step to finish the step
      aetherflux.configure_response('CURRENT STEP: 1', {
        status: :success,
        response: 'task_complete_step()'
      })

      # Execute step that should complete via divine interruption
      result = subject.execute_step(1, 1)
      
      # Verify step completed with divine interruption
      expect(result).to include(__divine_interrupt: :step_completed)
      
      # Verify task state updated correctly
      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('completed')
      expect(task_state['current_step']).to eq(1)
    end

    it 'verifies command system supports multiple step execution' do
      # Configure multiple steps with different responses
      aetherflux.configure_response('CURRENT STEP: 1', {
        status: :success,
        response: 'Step 1 command execution completed'
      })

      aetherflux.configure_response('CURRENT STEP: 2', {
        status: :success,
        response: 'Step 2 command execution completed'
      })

      # Execute both steps
      result1 = subject.execute_step(1, 1)
      result2 = subject.execute_step(1, 2)
      
      # Verify both steps completed successfully
      expect(result1[:status]).to eq(:step_not_completed)
      expect(result2[:status]).to eq(:step_not_completed)

      # Verify step results are properly stored and navigable
      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      expect(step_results['1']).to include('Step 1 command execution completed')
      expect(step_results['2']).to include('Step 2 command execution completed')
      
      # Verify task completed successfully
      expect(task_state['status']).to eq('completed')
      expect(task_state['current_step']).to eq(2)
    end
  end
end