# frozen_string_literal: true

require_relative '../task_engine'
require_relative '../mnemosyne'
require_relative 'fake_mnemosyne'
require_relative '../fake_aetherflux'
require 'rspec'
require 'timeout'


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
  end

  after do
    # Clear task state after each test
    mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'pending' })
  end

  describe '#oracle_conjuration_failure' do
    it 'handles :failure responses' do
      aetherflux.configure_response('Step 1', { status: :failure, response: 'Task execution failed' })

      expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('failed')
    end

    it 'logs the failure response' do
      aetherflux.configure_response('Step 1', { status: :failure, response: 'Task execution failed' })

      expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskStateError, 'Step 1 failed: Task execution failed')

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Step 1 failed: Task execution failed/)
    end
  end

  describe '#oracle_conjuration_timeout' do
    it 'handles timeout errors' do
      aetherflux.configure_response('Step 1', -> { raise Timeout::Error, 'Request timed out' })

      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)

      task_state = mnemosyne.task_state 1
      expect(task_state['status']).to eq('failed')
    end

    it 'logs the timeout error' do
      aetherflux.configure_response('Step 1', -> { raise Timeout::Error, 'Request timed out' })

      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)

      logs = mnemosyne.task_logs 1
      expect(logs.join).to match(/Timeout in step 1/)
    end
  end

  describe '#invalid_task_state' do
    it 'raises an error for invalid states' do
      mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'invalid' })
      expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskStateError, 'Invalid state: invalid')
    end
  end

  describe '#create_task' do
    it 'creates a task with default metadata' do
      task_id = subject.create_task(title: 'test', plan: 'test plan', max_steps: 5)
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
        expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskStateError, 'Task is paused')
      end
    end

    context 'when task is failed' do
      before { mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'failed' }) }

      it 'halts execution' do
        expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskStateError, 'Task is failed')
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
        expect { subject.execute_task(999) }.to raise_error(TaskEngine::TaskStateError, /Task not found: 999/)
      end
    end
  end

  context 'with task cancellation' do
    before { mnemosyne.manage_tasks({ 'action' => 'update', 'id' => 1, 'status' => 'cancelled' }) }

    it 'halts execution' do
      expect { subject.execute_task(1) }.to raise_error(TaskEngine::TaskCancelledError, 'Task cancelled')
    end
  end

  context 'with sub-tasks' do
    before do
      # Create sub-task
      sub_task = subject.create_task(title: 'sub', plan: 'sub plan', max_steps: 3, parent_task_id: 1)
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
end