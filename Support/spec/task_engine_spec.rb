# Support/spec/task_engine_spec.rb
require_relative '../task_engine'

RSpec.describe TaskEngine do
  let(:mnemosyne) { double('Mnemosyne') }
  subject { described_class.new(mnemosyne) }

  describe '#create_task' do
    it 'creates a task with default metadata' do
      allow(mnemosyne).to receive(:remember).and_return(1)
      expect(subject.create_task('test')).to eq(1)
    end
  end

  describe '#execute_task' do
    let(:task) { { id: 1, status: 'pending' } }
    before do
      allow(mnemosyne).to receive(:manage_tasks).and_return([task])
      allow(mnemosyne).to receive(:update_note)
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
    end

    it 'executes a task and updates its state' do
      expect(mnemosyne).to receive(:manage_tasks).with({ 'action' => 'update', 'id' => 1, 'status' => 'active' })
      subject.execute_task(1)
    end

    it 'updates progress after each step' do
      expect(mnemosyne).to receive(:manage_tasks).with({ 'action' => 'update', 'id' => 1, 'progress' => 1 })
      expect(mnemosyne).to receive(:manage_tasks).with({ 'action' => 'update', 'id' => 1, 'progress' => 2 })
      subject.execute_task(1)
    end

    context 'with sub-tasks' do
      let(:sub_task) { { id: 2, status: 'pending', parent_task_id: 1 } }
      before do
        allow(mnemosyne).to receive(:manage_tasks).and_return([task, sub_task])
      end

      it 'executes sub-tasks recursively' do
        expect(subject).to receive(:execute_task).with(1).and_call_original
        subject.execute_task(1)
      end
    end
  end
end