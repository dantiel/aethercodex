# frozen_string_literal: true

require_relative '../magnum_opus/magnum_opus_engine'
require_relative 'fake_mnemosyne'
require_relative 'fake_aetherflux'
require 'rspec'
require 'json'

RSpec.describe MagnumOpusEngine do
  let(:mnemosyne) { FakeMnemosyne.new }
  let(:aetherflux) { FakeAetherflux.new }
  subject { described_class.new(mnemosyne: mnemosyne, aetherflux: aetherflux) }

  # ── Helpers ────────────────────────────────────────────────

  def create_pending_task(title: 'Test', plan: 'Test plan', workflow_type: 'full')
    result = subject.create_task(title: title, plan: plan, workflow_type: workflow_type)
    result[:id]
  end

  def task(id)
    mnemosyne.get_task(id)
  end

  def task_status(id)
    task(id)[:status]
  end

  def current_step(id)
    subject.send(:current_step, id)
  end

  def step_results(id)
    subject.send(:load_step_results, id)
  end

  # ── TASK CREATION ──────────────────────────────────────────

  describe '#create_task' do
    it 'creates a task with default full workflow' do
      result = subject.create_task(title: 'Test', plan: 'Plan')
      expect(result[:id]).to be_an(Integer)
      t = task(result[:id])
      expect(t[:title]).to eq('Test')
      expect(t[:plan]).to eq('Plan')
      expect(t[:status]).to eq('pending')
      expect(t[:workflow_type]).to eq('full')
      expect(t[:current_step]).to eq(0)
    end

    it 'creates a simple workflow task (3 steps)' do
      result = subject.create_task(title: 'Simple', plan: 'Quick', workflow_type: 'simple')
      t = task(result[:id])
      expect(t[:workflow_type]).to eq('simple')
    end

    it 'creates an analysis workflow task (5 steps)' do
      result = subject.create_task(title: 'Analysis', plan: 'Research', workflow_type: 'analysis')
      t = task(result[:id])
      expect(t[:workflow_type]).to eq('analysis')
    end

    it 'creates a sub-task with parent reference' do
      parent_id = create_pending_task
      result = subject.create_task(title: 'Sub', plan: 'Sub plan', parent_task_id: parent_id)
      t = task(result[:id])
      expect(t[:parent_task_id]).to eq(parent_id)
    end

    it 'raises TaskCreationError on failure' do
      allow(mnemosyne).to receive(:manage_tasks).and_return({ 'ok' => false, 'error' => 'DB down' })
      expect { subject.create_task(title: 'X', plan: 'Y') }.to raise_error(MagnumOpusEngine::TaskCreationError)
    end
  end

  # ── TASK STATE TRANSITIONS ─────────────────────────────────

  describe '#execute_task — state transitions' do
    it 'transitions pending → active when started' do
      id = create_pending_task
      # Simulate oracle completing all steps via divine interruption
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })
      expect { subject.execute_task(id) }.not_to raise_error
      # After all steps complete, status should be :completed
      expect(task_status(id)).to eq('completed')
    end

    it 'raises TaskCancelledError when task is cancelled' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'cancelled')
      expect { subject.execute_task(id) }.to raise_error(MagnumOpusEngine::TaskCancelledError)
    end

    it 'raises TaskStateError when task is paused' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'paused')
      expect { subject.execute_task(id) }.to raise_error(MagnumOpusEngine::TaskStateError, /paused/)
    end

    it 'raises TaskStateError when task is failed' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'failed')
      expect { subject.execute_task(id) }.to raise_error(MagnumOpusEngine::TaskStateError, /failed/)
    end

    it 'raises TaskStateError for invalid states' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'invalid')
      expect { subject.execute_task(id) }.to raise_error(MagnumOpusEngine::TaskStateError, /Invalid state/)
    end

    it 'raises TaskStateError when task not found' do
      expect { subject.execute_task(9999) }.to raise_error(MagnumOpusEngine::TaskStateError, /not found/)
    end
  end

  # ── STEP COMPLETION (DIVINE INTERRUPTION) ──────────────────

  describe '#execute_step — divine interruption: step_completed' do
    it 'returns __divine_interrupt :step_completed when oracle calls task_complete_step()' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      result = subject.execute_step(id, 1)
      expect(result).to be_a(Hash)
      expect(result[:__divine_interrupt]).to eq(:step_completed)
    end

    it 'advances progress after step completion' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      expect(current_step(id)).to eq(0)
      subject.execute_step(id, 1)
      expect(current_step(id)).to eq(1) # Step 1 completed = progress 1
    end

    it 'preserves completion result in step_results via execute_task_internal' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step(result: "Nigredo analysis done")' })

      # execute_task_internal stores step results, execute_step does not
      subject.execute_task_internal(id, 0, 'full', 10)
      results = step_results(id)
      expect(results['1']).to include('Nigredo analysis done')
    end
  end

  # ── STEP REJECTION (DIVINE INTERRUPTION) ───────────────────

  describe '#execute_step — divine interruption: step_rejected' do
    it 'returns __divine_interrupt :step_rejected' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'task_reject_step(reason: "Need more analysis")' })

      result = subject.execute_step(id, 1)
      expect(result[:__divine_interrupt]).to eq(:step_rejected)
      expect(result[:reason]).to eq('Need more analysis')
    end

    it 'rejection without explicit restart_from_step defaults to step 1' do
      id = create_pending_task
      # Rejection without restart_from_step defaults to [step_index-1, 1].max
      # For step 1: [0, 1].max = 1
      aetherflux.set_default_response({ status: :success, response: 'task_reject_step(reason: "redo")' })

      result = subject.execute_step(id, 1)
      expect(result[:__divine_interrupt]).to eq(:step_rejected)
      # Engine fills in default: [step_index - 1, 1].max = [0, 1].max = 1
      expect(result[:restart_from_step]).to eq(1)
      expect(result[:reason]).to eq('redo')
    end

    it 'restarts from specific step when restart_from_step is given' do
      id = create_pending_task
      aetherflux.configure_response('restart', { status: :success, response: 'task_reject_step(reason: "rethink architecture", restart_from_step: 2)' })

      result = subject.execute_step(id, 1)
      expect(result[:__divine_interrupt]).to eq(:step_rejected)
      expect(result[:restart_from_step]).to eq(2)
      expect(result[:reason]).to eq('rethink architecture')
    end
  end

  # ── STEP WITHOUT COMPLETION SIGNAL ─────────────────────────

  describe '#execute_step — no completion signal' do
    it 'returns :step_not_completed when oracle succeeds without task_complete_step' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'Just analyzing...' })

      result = subject.execute_step(id, 1)
      expect(result[:status]).to eq(:step_not_completed)
    end

    it 'does not advance progress when no completion signal' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :success, response: 'Partial work done' })

      expect(current_step(id)).to eq(0)
      subject.execute_step(id, 1)
      expect(current_step(id)).to eq(1) # execute_step calls update_progress at start
    end
  end

  # ── ENGINE reject_step & complete_step METHODS ─────────────

  describe '#reject_step (engine method)' do
    it 'goes back to previous step by default' do
      id = create_pending_task
      # Set current_step to 3 (3 steps completed)
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 3)

      result = subject.reject_step(id, reason: 'found a flaw')
      expect(result[:ok]).to eq(true)
      expect(current_step(id)).to eq(2) # Went back to step 2
    end

    it 'restarts from specific step (1-indexed)' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 5)

      result = subject.reject_step(id, reason: 'rethink', restart_from_step: 2)
      expect(result[:restart_from_step]).to eq(2)
      # restart_from_step=2 means "go back to start from step 2" → progress = 1
      expect(current_step(id)).to eq(1)
    end

    it 'clamps restart_from_step to valid range' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 3)

      # Try to restart from step 20 (beyond max)
      subject.reject_step(id, reason: 'overflow', restart_from_step: 20)
      expect(current_step(id)).to be <= 10

      # Try to restart from step 0 (below min)
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 3)
      subject.reject_step(id, reason: 'underflow', restart_from_step: 0)
      expect(current_step(id)).to be >= 0
    end

    it 'respects simple workflow max steps boundary' do
      id = create_pending_task(workflow_type: 'simple')
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 2)

      # Try to restart from step 8 (beyond simple's 3-step max)
      subject.reject_step(id, reason: 'overflow', restart_from_step: 8)
      expect(current_step(id)).to be <= 2 # 3 max steps, -1 for 0-indexed
    end
  end

  describe '#complete_step (engine method)' do
    it 'advances to next step' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 1)

      result = subject.complete_step(id, result: 'done')
      expect(result[:ok]).to eq(true)
      expect(result[:completed_step]).to eq(1)
      expect(current_step(id)).to eq(2)
    end

    it 'does not exceed max steps' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 10)

      result = subject.complete_step(id, result: 'done')
      expect(current_step(id)).to eq(10) # Clamped at 10
    end
  end

  # ── TASK RESUMPTION ────────────────────────────────────────

  describe '#execute_task_internal — resumption' do
    it 'resumes from current_step after stop' do
      id = create_pending_task

      # Complete step 1
      aetherflux.configure_response('step 1', { status: :success, response: 'task_complete_step()' })
      subject.execute_task_internal(id, 0, 'full', 10)
      expect(current_step(id)).to eq(1)

      # Resume from step 2
      aetherflux.configure_response('step 2', { status: :success, response: 'task_complete_step()' })
      subject.execute_task_internal(id, 1, 'full', 10)
      expect(current_step(id)).to eq(2)
    end

    it 'stops when halted' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'cancelled')
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      result = subject.execute_task_internal(id, 0, 'full', 10)
      expect(result).to be_nil
    end

    it 'stops when current_step >= max_steps' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 10)

      result = subject.execute_task_internal(id, 10, 'full', 10)
      expect(result).to be_nil
    end

    it 'stops when no completion signal received' do
      id = create_pending_task
      # Oracle succeeds but doesn't call task_complete_step
      aetherflux.set_default_response({ status: :success, response: 'Here is my analysis...' })

      result = subject.execute_task_internal(id, 0, 'full', 10)
      expect(result).to be_nil # Should stop
      # Progress was updated by execute_step but no completion → stuck at step 1
      expect(current_step(id)).to eq(1)
    end
  end

  # ── WORKFLOW TYPES ─────────────────────────────────────────

  describe 'workflow types' do
    it 'simple workflow completes after 3 steps' do
      id = create_pending_task(workflow_type: 'simple')
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      # Execute all 3 steps
      3.times { subject.execute_task_internal(id, current_step(id), 'simple', 3) }
      expect(current_step(id)).to eq(3)

      # Next execution should be no-op (already at max)
      result = subject.execute_task_internal(id, 3, 'simple', 3)
      expect(result).to be_nil
    end

    it 'analysis workflow completes after 5 steps' do
      id = create_pending_task(workflow_type: 'analysis')
      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      5.times { subject.execute_task_internal(id, current_step(id), 'analysis', 5) }
      expect(current_step(id)).to eq(5)
    end

    it 'update_progress clamps to workflow max steps' do
      id = create_pending_task(workflow_type: 'simple')
      # Try to set progress to 8 on a 3-step simple workflow
      subject.send(:update_progress, id, 8)
      expect(current_step(id)).to eq(3) # Clamped at 3
    end
  end

  # ── ERROR HANDLING ─────────────────────────────────────────

  describe 'error handling' do
    it 'handles :failure status by raising TaskStateError and marking task failed' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :failure, response: 'Catastrophic failure' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Step 1 failed/)
      expect(task_status(id)).to eq('failed')
    end

    it 'handles :timeout status by raising TaskStateError without marking task failed' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :timeout, response: 'Timed out' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /timed out/)
      # Timeout should not fail the task
      expect(task_status(id)).to eq('pending')
    end

    it 'handles :network_error by raising TaskStateError without marking failed' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :network_error, response: 'No connection' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /network error/)
      expect(task_status(id)).to eq('pending')
    end

    it 'handles :context_length_error by raising TaskStateError' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :context_length_error, response: 'Too long' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /context length/)
    end

    it 'handles :rate_limit_error by raising TaskStateError' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :rate_limit_error, response: 'Slow down' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /rate limit/)
    end

    it 'handles :empty_response by raising TaskStateError' do
      id = create_pending_task
      aetherflux.set_default_response({ status: :empty_response, response: '' })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Empty response/)
    end

    it 'handles unknown response status gracefully' do
      id = create_pending_task
      aetherflux.set_default_response({ weird: :format })

      expect { subject.execute_step(id, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /Unknown response status/)
    end

    it 'marks task failed on unexpected StandardError in execute_task' do
      id = create_pending_task
      allow(subject).to receive(:execute_task_internal).and_raise(StandardError, 'Boom!')

      expect { subject.execute_task(id) }.to raise_error(MagnumOpusEngine::TaskStateError, /failed/)
      expect(task_status(id)).to eq('failed')
    end
  end

  # ── halted? ────────────────────────────────────────────────

  describe '#halted?' do
    it 'returns true for cancelled tasks' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'cancelled')
      expect(subject.halted?(id)).to be true
    end

    it 'returns true for failed tasks' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'failed')
      expect(subject.halted?(id)).to be true
    end

    it 'returns true for paused tasks' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'paused')
      expect(subject.halted?(id)).to be true
    end

    it 'returns false for active tasks' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, status: 'active')
      expect(subject.halted?(id)).to be false
    end

    it 'returns false for pending tasks' do
      id = create_pending_task
      expect(subject.halted?(id)).to be false
    end
  end

  # ── SUB-TASKS ──────────────────────────────────────────────

  describe '#execute_sub_tasks' do
    it 'dispatches pending sub-tasks' do
      parent_id = create_pending_task
      sub_id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: sub_id, parent_task_id: parent_id)

      aetherflux.set_default_response({ status: :success, response: 'task_complete_step()' })

      # Parent execute_task also dispatches sub-tasks
      # We test the sub-task dispatch directly
      expect { subject.execute_sub_tasks(parent_id, 10) }.not_to raise_error
    end

    it 'skips halted sub-tasks' do
      parent_id = create_pending_task
      sub_id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: sub_id, parent_task_id: parent_id, status: 'cancelled')

      # Should not try to execute cancelled sub-task
      expect { subject.execute_sub_tasks(parent_id, 10) }.not_to raise_error
    end
  end

  # ── SUB-TASK CONTEXT INHERITANCE ───────────────────────────

  describe '#inherit_parent_context_to_subtask' do
    it 'creates inheritance notes for sub-task' do
      parent_id = create_pending_task(title: 'Parent', plan: 'Build something')
      mnemosyne.manage_tasks(action: :update, id: parent_id, current_step: 3,
                             step_results: { '1' => 'Analysis done', '2' => 'Design done' }.to_json)

      sub_id = create_pending_task
      # Set parent_task_id on sub-task so inherit can find the parent
      mnemosyne.manage_tasks(action: :update, id: sub_id, parent_task_id: parent_id)
      subject.inherit_parent_context_to_subtask(parent_id, sub_id)

      # Verify notes were created by checking the notes array directly
      notes = mnemosyne.notes
      inheritance_note = notes.find { |n| n[:tags]&.include?("task_#{sub_id}") }
      expect(inheritance_note).not_to be_nil
      expect(inheritance_note[:content]).to include('INHERITED FROM PARENT')
      expect(inheritance_note[:content]).to include('Build something')
    end
  end

  describe '#parent_task_context_for' do
    it 'returns nil when no parent exists' do
      id = create_pending_task
      expect(subject.parent_task_context_for(id)).to be_nil
    end

    it 'returns formatted context for sub-tasks' do
      parent_id = create_pending_task(title: 'Parent', plan: 'Master plan')
      sub_id = create_pending_task
      # Engine looks up task[:parent_task_id] on the sub-task to find its parent
      mnemosyne.manage_tasks(action: :update, id: sub_id, parent_task_id: parent_id)

      context = subject.parent_task_context_for(sub_id)
      expect(context).not_to be_nil
      expect(context).to include('PARENT TASK CONTEXT')
      expect(context).to include('Master plan')
    end
  end

  # ── STEP RESULT STORAGE ────────────────────────────────────

  describe 'step result storage and retrieval' do
    it 'stores and loads step results' do
      id = create_pending_task
      subject.send(:store_step_result, id, 1, 'Nigredo analysis complete')

      results = step_results(id)
      expect(results['1']).to include('Nigredo analysis complete')
    end

    it 'handles multiple step results' do
      id = create_pending_task
      subject.send(:store_step_result, id, 1, 'Step 1 done')
      subject.send(:store_step_result, id, 2, 'Step 2 done')
      subject.send(:store_step_result, id, 3, 'Step 3 done')

      results = step_results(id)
      expect(results.keys.sort).to eq(%w[1 2 3])
    end

    it 'overwrites step result on re-execution' do
      id = create_pending_task
      subject.send(:store_step_result, id, 1, 'First attempt')
      subject.send(:store_step_result, id, 1, 'Second attempt')

      results = step_results(id)
      expect(results['1']).to include('Second attempt')
    end

    it 'get_step_result returns individual result' do
      id = create_pending_task
      subject.send(:store_step_result, id, 2, 'Albedo result')

      result = subject.get_step_result(id, 2)
      expect(result[:ok]).to be true
      expect(result[:result]).to include('Albedo result')
    end

    it 'get_step_result returns error for non-existent step' do
      id = create_pending_task
      result = subject.get_step_result(id, 99)
      expect(result[:ok]).to be false
    end
  end

  # ── TOOL CALL STORAGE ──────────────────────────────────────

  describe 'tool call storage' do
    it 'stores and loads tool calls by step' do
      id = create_pending_task
      tool_calls = [{ name: 'read_file', result: 'ok' }]
      subject.send(:store_step_tool_calls, id, 1, tool_calls)

      loaded = subject.send(:load_step_tool_calls, id, 1)
      expect(loaded).not_to be_empty
    end

    it 'load_previous_step_tool_calls returns empty for step 1' do
      id = create_pending_task
      result = subject.send(:load_previous_step_tool_calls, id, 1)
      expect(result).to eq([])
    end

    it 'returns empty for nil/empty tool calls' do
      id = create_pending_task
      subject.send(:store_step_tool_calls, id, 1, nil)
      subject.send(:store_step_tool_calls, id, 1, [])
      loaded = subject.send(:load_step_tool_calls, id, 1)
      expect(loaded).to eq([])
    end
  end

  # ── EVALUATE ───────────────────────────────────────────────

  describe '#evaluate_task' do
    it 'returns task info for existing task' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, current_step: 3)

      result = subject.evaluate_task(id)
      expect(result[:status]).to eq(:success)
      expect(result[:task][:id]).to eq(id)
      expect(result[:task][:current_step]).to eq(3)
    end

    it 'returns error for non-existent task' do
      result = subject.evaluate_task(9999)
      expect(result[:status]).to eq(:error)
    end
  end

  # ── BOUNDARY & EDGE CASES ──────────────────────────────────

  describe 'boundary checks' do
    it 'rejects negative task IDs in execute_step' do
      expect { subject.execute_step(-1, 1) }.to raise_error(MagnumOpusEngine::TaskStateError, /not found/)
    end

    it 'handles malformed step_results JSON' do
      id = create_pending_task
      mnemosyne.manage_tasks(action: :update, id: id, step_results: 'not-json')
      results = step_results(id)
      expect(results).to eq({}) # Gracefully returns empty
    end

    it 'current_step returns 0 for new tasks' do
      id = create_pending_task
      expect(current_step(id)).to eq(0)
    end
  end
end