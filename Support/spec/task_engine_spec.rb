require_relative '../task_engine'
require_relative '../mnemosyne'
require_relative './fake_mnemosyne'
require 'rspec'
require 'timeout'

RSpec.describe TaskEngine do
  let(:mnemosyne) { FakeMnemosyne.new }
  let(:aetherflux) { double('Aetherflux') }
  subject { described_class.new(mnemosyne: mnemosyne, aetherflux: aetherflux) }

  before do
    # Setup default task
    mnemosyne.manage_tasks({'action' => 'create', 'parent_task_id' => nil})
    
    # Initialize task state before relevant tests
    mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'pending'})
    
    # Default mock
    allow(aetherflux).to receive(:channel_oracle_conjuration) do |prompt|
      { status: :success, response: "Simulated response" }
    end
  end

  after do
    # Clear task state after each test
    mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'pending'})
  end

  describe '#oracle_conjuration_failure' do
    it 'handles :failure responses' do
      allow(aetherflux).to receive(:channel_oracle_conjuration).and_return({ status: :failure, response: "Task execution failed" })
      
      expect { subject.execute_task(1) }.to raise_error(RuntimeError)
      
      task_state = mnemosyne.task_state(1)
      expect(task_state['status']).to eq('failed')
      logs = mnemosyne.task_logs(1)
      expect(logs.join).to match(/Task execution failed/)
    end

    it 'logs the failure response' do
      allow(aetherflux).to receive(:channel_oracle_conjuration).and_return({ status: :failure, response: "Task execution failed" })
      
      expect { subject.execute_task(1) }.to raise_error(RuntimeError)
      
      task_state = mnemosyne.task_state(1)
      expect(task_state['status']).to eq('failed')
      logs = mnemosyne.task_logs(1)
      expect(logs.join).to match(/Step 1 failed: Task execution failed/)
    end
  end

  describe '#oracle_conjuration_timeout' do
    it 'handles timeout errors' do
      allow(aetherflux).to receive(:channel_oracle_conjuration).and_raise(Timeout::Error, "Request timed out")
      
      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)
      
      task_state = mnemosyne.task_state(1)
      expect(task_state['status']).to eq('failed')
    end

    it 'logs the timeout error' do
      allow(aetherflux).to receive(:channel_oracle_conjuration).and_raise(Timeout::Error, "Request timed out")
      
      expect { subject.execute_task(1) }.to raise_error(Timeout::Error)
      
      logs = mnemosyne.task_logs(1)
      expect(logs.join).to match(/Timeout in step 1/)
    end
  end

  describe '#invalid_task_state' do
    it 'raises an error for invalid states' do
      mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'invalid'})
      expect { subject.execute_task(1) }.to raise_error(RuntimeError, "Invalid state: invalid")
    end

    it 'logs the invalid state' do
      mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'invalid'})
      expect { subject.execute_task(1) }.to raise_error(RuntimeError, "Invalid state: invalid")
      
      logs = mnemosyne.task_logs(1)
      expect(logs.join).to include("Invalid state: invalid")
    end
  end

  describe '#create_task' do
    it 'creates a task with default metadata' do
      task_id = subject.create_task('test')
      expect(task_id).to be_a(Integer)
    end
  end
  
  describe '#execute_task' do
    before do
      allow_any_instance_of(TaskEngine).to receive(:query_notes)
      allow_any_instance_of(TaskEngine).to receive(:generate_solution_options)
      allow_any_instance_of(TaskEngine).to receive(:evaluate_alternatives)
      allow_any_instance_of(TaskEngine).to receive(:choose_best_option)
      allow_any_instance_of(TaskEngine).to receive(:analyze_files)
      allow_any_instance_of(TaskEngine).to receive(:apply_patches)
      allow_any_instance_of(TaskEngine).to receive(:run_tests)
      allow_any_instance_of(TaskEngine).to receive(:validate_edge_scenarios)
      allow_any_instance_of(TaskEngine).to receive(:audit_and_optimize)
      allow_any_instance_of(TaskEngine).to receive(:update_documentation)
      allow(aetherflux).to receive(:channel_oracle_conjuration).and_return({ status: :success, response: "Simulated response" })
    end

    context 'when task is paused' do
      before { mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'paused'}) }
      
      it 'halts execution' do
        expect { subject.execute_task(1) }.to raise_error(RuntimeError, "Invalid state: paused")
      end
    end

    context 'when task is failed' do
      before { mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'failed'}) }
      
      it 'halts execution' do
        expect { subject.execute_task(1) }.to raise_error(RuntimeError, "Invalid state: failed")
      end
    end

    context 'when max_loops is exhausted' do
      it 'does not execute sub-tasks' do
        expect(subject).not_to receive(:execute_task).with(2, max_loops: 0)
        subject.execute_task(1, max_loops: 1)
      end
    end

    context "with invalid task ID" do
      it 'does nothing' do
        expect(subject).not_to receive(:execute_step)
        subject.execute_task(999)
      end
    end
  end

  context 'with task cancellation' do
    before { mnemosyne.manage_tasks({'action' => 'update', 'id' => 1, 'status' => 'cancelled'}) }
    
    it 'halts execution' do
      expect { subject.execute_task(1) }.to raise_error(RuntimeError, "Task cancelled")
    end

    it 'logs the cancellation' do
      begin
        subject.execute_task(1)
      rescue
      end
      logs = mnemosyne.task_logs(1)
      expect(logs.join).to include("Task was cancelled")
    end
  end

  context 'with sub-tasks' do
    before do
      # Create sub-task
      sub_task_id = mnemosyne.manage_tasks({'action' => 'create', 'parent_task_id' => 1})['id']
      mnemosyne.manage_tasks({'action' => 'update', 'id' => sub_task_id, 'status' => 'pending'})
    end
    
    it 'executes sub-tasks recursively' do
      expect(subject).to receive(:execute_task).with(1, max_loops: 10).and_call_original
      expect(subject).to receive(:execute_task).with(anything, max_loops: 9).and_call_original
      subject.execute_task(1, max_loops: 10)
    end

    it 'decrements max_loops correctly' do
      subject.execute_task(1, max_loops: 10)
      expect(mnemosyne.task_state(1)['max_loops']).to eq(9)
    end
  end
end