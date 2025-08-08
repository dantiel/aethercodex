class TaskEngine
  def initialize(mnemosyne)
    @mnemosyne = mnemosyne
  end

  def execute_active_tasks
    active_tasks = @mnemosyne.recall_notes(tags: ["task", "active"])
    active_tasks.each do |task|
      # Execute task (e.g., patch a file, run a command)
      log_execution(task, success: true)
    end
  end

  private

  def log_execution(task, success:)
    @mnemosyne.update_note(task[:id], state: success ? :completed : :failed)
  end
end