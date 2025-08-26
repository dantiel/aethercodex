# frozen_string_literal: true

require_relative '../task_engine'
require_relative '../mnemosyne'
require_relative 'fake_mnemosyne'
require_relative 'fake_aetherflux'
require 'rspec'
require 'timeout'
require 'net/protocol'  # For Net::ReadTimeout and Net::OpenTimeout


RSpec.describe TaskEngine do
  let(:mnemosyne) { FakeMnemosyne.new }
  let(:aetherflux) { FakeAetherflux.new }
  subject { described_class.new mnemosyne: mnemosyne, aetherflux: aetherflux }

  before do
    # Setup default task
    mnemosyne.manage_tasks({ 'action' => 'create', 'parent_task_id' => nil })

    # Initialize task state before relevant tests
    mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'pending' })

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
    it 'handles :failure responses' do
      aetherflux.configure_response('CURRENT STEP: 1', { status: :failure, response: 'Task execution failed' })

      expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('failed')
    end

    it 'logs the failure response' do
      aetherflux.configure_response('CURRENT STEP: 1', { status: :failure, response: 'Task execution failed' })

      expect { subject.execute_task(1) }.to raise_error(MagnumOpusEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Step 1 failed: Task execution failed/)
    end
  end

  describe '#oracle_conjuration_timeout' do
    it 'handles timeout errors gracefully without failing entire task' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Timeout::Error, 'Request timed out' })

      # Timeout should break execution loop but not crash the entire task
      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)

      # Task should remain in active state for retry, not failed
      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('pending')  # Should remain pending for retry
      
      # Step result should be stored for context
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:')
    end

    it 'logs the timeout error with detailed context' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Timeout::Error, 'Request timed out' })

      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Step 1 timed out: Request timed out/)
    end

    it 'handles Net::ReadTimeout specifically' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Net::ReadTimeout, 'Read timed out' })

      # Should be treated as network error, not generic timeout
      expect { subject.execute_task(1) }.to raise_error(Net::ReadTimeout)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:')
    end

    it 'handles Net::OpenTimeout specifically' do
      aetherflux.configure_response('CURRENT STEP: 1', -> { raise Net::OpenTimeout, 'Connection timed out' })

      # Should be treated as network error, not generic timeout
      expect { subject.execute_task(1) }.to raise_error(Net::OpenTimeout)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      expect(step_results['1']).to include('TIMEOUT:')
    end

    it 'handles mixed timeout scenarios across multiple steps' do
      # Step 1: Success
      aetherflux.configure_response('CURRENT STEP: 1', { status: :success, response: 'Step 1 completed' })
      # Step 2: Timeout
      aetherflux.configure_response('CURRENT STEP: 2', -> { raise Timeout::Error, 'Step 2 timeout' })
      
      # Should complete step 1, then timeout on step 2
      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)

      task_state = mnemosyne.task_state 1
      step_results = JSON.parse(task_state['step_results'] || '{}')
      
      # Both steps should have results
      expect(step_results['1']).to eq('Step 1 completed')
      expect(step_results['2']).to include('TIMEOUT: Step 2 timeout')
      
      # Task should remain pending for retry
      expect(task_state['status']).to eq('pending')
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
      task_id = subject.create_task(title: 'test', plan: 'test plan')
      expect(task_id[:id]).to be_a(Integer)
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
      expect(subject).to receive(:execute_task).with(anything, max_loops: 9).and_call_original
      
      subject.execute_task 1, max_loops: 10
    end
  end

  describe 'edge case testing' do
    context 'with empty task plan' do
      it 'handles empty plan gracefully' do
        task_id = subject.create_task(title: 'Empty Plan Test', plan: '')
        mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id[:id], 'status' => 'pending' })
        
        expect { subject.execute_step(task_id[:id], 1) }.not_to raise_error
        
        conjuration_params = aetherflux.captured_conjurations.last
        prompt = conjuration_params[:prompt]
        expect(prompt).to include('TASK PLAN: --')
      end
    end

    context 'with nil task description' do
      it 'handles nil description gracefully' do
        task_id = subject.create_task(title: 'Nil Description Test', plan: 'test')
        mnemosyne.manage_tasks({ 'action' => 'update', 'id' => task_id[:id], 'description' => nil, 'status' => 'pending' })
        
        expect { subject.execute_step(task_id[:id], 1) }.not_to raise_error
        
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
        
        expect { subject.execute_step(task_id[:id], 2) }.not_to raise_error
        
        conjuration_params = aetherflux.captured_conjurations.last
        prompt = conjuration_params[:prompt]
        expect(prompt).to include('No previous step results available.')
      end
    end

    context 'with invalid input validation' do
      it 'rejects negative task IDs' do
        expect { subject.execute_step(-1, 1) }.to raise_error(TaskEngine::TaskStateError, /Task not found: -1/)
      end

      it 'rejects non-integer task IDs' do
        expect { subject.execute_step('invalid', 1) }.to raise_error(TypeError)
      end
    end

    context 'with empty response handling' do
      it 'handles empty oracle responses gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', { status: :empty_response, response: '' })
        
        # Empty response should break execution loop but not crash the entire task
        expect { subject.execute_step(1, 1) }.not_to raise_error
        
        task_state = mnemosyne.task_state 1
        # Task should remain in active state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('EMPTY_RESPONSE:')
      end

      it 'handles nil oracle responses gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', nil)
        
        # Nil response should break execution loop but not crash the entire task
        expect { subject.execute_step(1, 1) }.not_to raise_error
        
        task_state = mnemosyne.task_state 1
        # Task should remain in active state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('EMPTY_RESPONSE:')
      end
    end

    context 'with unknown response format handling' do
      it 'handles completely unknown response formats gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', { completely: :unknown, format: 'unexpected' })
        
        # Unknown response should break execution loop but not crash the entire task
        expect { subject.execute_step(1, 1) }.not_to raise_error
        
        task_state = mnemosyne.task_state 1
        # Task should remain in active state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('ERROR: Unknown response status:')
      end

      it 'handles string-based status keys gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', { 'status' => 'success', 'response' => { 'answer' => 'test' } })
        
        # String-based status should work correctly
        expect { subject.execute_step(1, 1) }.not_to raise_error
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('pending')  # Should progress normally
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to eq('test')
      end
    end
  end
end
      it 'handles memory allocation errors' do
        allow(aetherflux).to receive(:channel_oracle_conjuration).and_raise(NoMemoryError, 'Cannot allocate memory')
        
        expect { subject.execute_step(1, 1) }.to raise_error(NoMemoryError, 'Cannot allocate memory')
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('failed')
      end

      it 'handles context length exceeded errors gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :context_length_error,
          response: 'maximum context length is 131072 tokens'
        })
        
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError)
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('failed')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('CONTEXT_LENGTH_ERROR:')
      end

      it 'handles rate limit errors gracefully' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :rate_limit_error,
          response: 'rate limit exceeded'
        })
        
        expect { subject.execute_step(1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError)
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('failed')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('RATE_LIMIT_ERROR:')
      end

      it 'handles network errors gracefully without failing entire task' do
        aetherflux.configure_response('CURRENT STEP: 1', {
          status: :network_error,
          response: 'network connection failed'
        })
        
        # Network error should break execution loop but not crash the entire task
        expect { subject.execute_step(1, 1) }.not_to raise_error
        
        task_state = mnemosyne.task_state 1
        # Task should remain in active state for retry, not failed
        expect(task_state['status']).to eq('pending')
        
        step_results = JSON.parse(task_state['step_results'] || '{}')
        expect(step_results['1']).to include('NETWORK_ERROR:')
      end
    end

    context 'with resource constraints' do
      it 'handles memory allocation errors' do
        allow(aetherflux).to receive(:channel_oracle_conjuration).and_raise(NoMemoryError, 'Cannot allocate memory')
        
        expect { subject.execute_step(1, 1) }.to raise_error(NoMemoryError, 'Cannot allocate memory')
        
        task_state = mnemosyne.task_state 1
        expect(task_state['status']).to eq('failed')
      end
    end

    context 'with invalid input validation' do
      it 'rejects negative task IDs' do
        expect { subject.execute_step(-1, 1) }.to raise_error(TaskEngine::TaskStateError, /Task not found: -1/)
      end

      it 'rejects non-integer task IDs' do
        expect { subject.execute_step('invalid', 1) }.to raise_error(TypeError)
      end
    end
  end
end