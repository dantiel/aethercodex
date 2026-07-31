# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'
require 'yaml'
require 'set'
require 'json'
require 'tiktoken_ruby'
require 'timeout'
require_relative '../config'
require_relative '../argonaut/argonaut'
require_relative '../instrumentarium/metaprogramming_utils'
using TokenExtensions

# Load sub-modules first — they reopen Mnemosyne to add inner classes
require_relative 'aegis'
require_relative 'notes'
require_relative 'metempsychosis_router'
require_relative 'task_ledger'
require_relative 'chronicle'

class Mnemosyne
  DB_VERSION = 4
  STOP_WORDS = Set.new %w[
    the a an and of in to with on for is are am be was were it this that
    at by from as if or but so not into out about then
  ]

  PRIORITY_HIGH = 3
  PRIORITY_MEDIUM = 2
  PRIORITY_LOW = 1

  DEFAULT_TRUNCATION_THRESHOLDS = {
    PRIORITY_HIGH   => { request: 2000, result: 4000 },
    PRIORITY_MEDIUM => { request: 1000, result: 1000 },
    PRIORITY_LOW    => { request: 500, result: 0 }
  }.freeze

  DEFAULT_ACTIVE_MEMORY_WINDOW = 5
  DEFAULT_PRIORITY_DECAY_RATE = 1.0

  DEFAULT_TOKEN_LIMITS = {
    active_memory:       8000,
    step_context:        4000,
    tool_call_expansion: 2000
  }.freeze

  OPERATIONAL_MODES = {
    standard:    {
      active_memory_window:  5,
      priority_decay_rate:   1.0,
      truncation_thresholds: DEFAULT_TRUNCATION_THRESHOLDS,
      token_limits:          DEFAULT_TOKEN_LIMITS
    },
    magnum_opus: {
      active_memory_window:  3,
      priority_decay_rate:   2.0,
      truncation_thresholds: {
        PRIORITY_HIGH   => { request: 1500, result: 3000 },
        PRIORITY_MEDIUM => { request: 800, result: 800 },
        PRIORITY_LOW    => { request: 300, result: 0 }
      },
      token_limits:          {
        active_memory:       6000,
        step_context:        3000,
        tool_call_expansion: 1500
      }
    },
    analysis:    {
      active_memory_window:  8,
      priority_decay_rate:   0.5,
      truncation_thresholds: {
        PRIORITY_HIGH   => { request: 3000, result: 6000 },
        PRIORITY_MEDIUM => { request: 1500, result: 2000 },
        PRIORITY_LOW    => { request: 800, result: 500 }
      },
      token_limits:          {
        active_memory:       12_000,
        step_context:        6000,
        tool_call_expansion: 3000
      }
    }
  }.freeze

  @current_mode = :standard

  class << self
    attr_accessor :aegis

    MAX_NOTE_CONTENT_LENGTH = 500

    # -- Core infrastructure methods --

    def truncate_note_content(content, max_length: MAX_NOTE_CONTENT_LENGTH)
      return content if content.to_s.length <= max_length

      if content.include? '```'
        content.gsub(/```(\w*)\n.*?\n```/m) do |match|
          lang = ::Regexp.last_match 1
          inner_content = match[(lang.length + 4)..-4]
          if inner_content.length > max_length / 2
            "```#{lang}\n#{inner_content[0...(max_length / 2)]}...\n```"
          else
            match
          end
        end
      else
        "#{content[0...max_length]}..."
      end
    end

    def db_path
      CONFIG.memory_db_path
    end

    def db
      @db ||= begin
        FileUtils.mkdir_p File.dirname(db_path)
        db = SQLite3::Database.new db_path
        db.results_as_hash = true
        migrate db
        restore_aegis db
        db
      end
    end

    def migrate(db)
      db.execute <<~SQL
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
      SQL

      db_version = db.execute("SELECT value FROM meta WHERE key = 'db_version'").first&.[]('value').to_i

      if 1 > db_version
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            prompt TEXT,
            answer TEXT,
            tags TEXT,
            file TEXT,
            selection TEXT,
            execution_time REAL,
            tool_call_count INTEGER,
            tool_calls_json TEXT,
            timestamp TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            plan TEXT,
            updates TEXT,
            logs TEXT,
            status TEXT,
            current_step INTEGER DEFAULT 0,
            step_results TEXT DEFAULT '{}',
            workflow_type TEXT DEFAULT 'full',
            parent_task_id INTEGER,
            subtask_results TEXT DEFAULT '{}',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS project_notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            links TEXT,
            content TEXT,
            tags TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL
        db.execute <<~SQL
          CREATE TABLE IF NOT EXISTS aegis_state (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tags TEXT,
            summary TEXT,
            temperature REAL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
        SQL

        existing_columns = db.execute('PRAGMA table_info(entries)').map { |col| col['name'] }
        db.execute 'ALTER TABLE entries ADD COLUMN execution_time REAL' unless existing_columns.include?('execution_time')
        db.execute 'ALTER TABLE entries ADD COLUMN tool_call_count INTEGER' unless existing_columns.include?('tool_call_count')
        db.execute 'ALTER TABLE entries ADD COLUMN timestamp TEXT' unless existing_columns.include?('timestamp')
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '1')"
      end

      if 2 > db_version
        existing_task_columns = db.execute('PRAGMA table_info(tasks)').map { |col| col['name'] }
        unless existing_task_columns.include?('tool_calls_json')
          db.execute "ALTER TABLE tasks ADD COLUMN tool_calls_json TEXT DEFAULT '[]'"
        end
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '2')"
      end

      if 3 > db_version
        existing_entries_columns = db.execute('PRAGMA table_info(entries)').map { |col| col['name'] }
        unless existing_entries_columns.include?('tool_calls_json')
          db.execute 'ALTER TABLE entries ADD COLUMN tool_calls_json TEXT'
        end
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '3')"
      end

      if 4 > db_version
        existing_aegis_columns = db.execute('PRAGMA table_info(aegis_state)').map { |col| col['name'] }
        unless existing_aegis_columns.include?('working_dir')
          db.execute 'ALTER TABLE aegis_state ADD COLUMN working_dir TEXT'
        end
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '4')"
      end

      if 5 > db_version
        existing_aegis_columns = db.execute('PRAGMA table_info(aegis_state)').map { |col| col['name'] }
        db.execute('ALTER TABLE aegis_state ADD COLUMN thinking INTEGER') unless existing_aegis_columns.include?('thinking')
        db.execute('ALTER TABLE aegis_state ADD COLUMN reasoning_effort TEXT') unless existing_aegis_columns.include?('reasoning_effort')
        db.execute('ALTER TABLE aegis_state ADD COLUMN model TEXT') unless existing_aegis_columns.include?('model')
        db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '5')"
      end

      return unless 6 > db_version

      existing_aegis_columns = db.execute('PRAGMA table_info(aegis_state)').map { |col| col['name'] }
      unless existing_aegis_columns.include?('thinking_str')
        db.execute 'ALTER TABLE aegis_state ADD COLUMN thinking_str TEXT'
        db.execute "UPDATE aegis_state SET thinking_str = 'normal' WHERE thinking = 1 AND thinking_str IS NULL"
      end
      db.execute "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '6')"
    end

    def tokenize(text)
      return Set.new unless text.is_a? String
      tokens = text.downcase.scan(/\w+/)
      Set.new(tokens) - STOP_WORDS
    end

    def safe_parse_json(json_string, default = {})
      return default if json_string.nil? || json_string.empty?
      JSON.parse(json_string)
    rescue JSON::ParserError
      default
    end

    # === Delegations to sub-modules ===

    # -- Aegis --
    def update_aegis_summary(summary) = Aegis.update_aegis_summary(summary)
    def set_aegis_temperature(temperature) = Aegis.set_aegis_temperature(temperature)
    def fetch_aegis_summaries(before:, max_tokens:) = Aegis.fetch_aegis_summaries(before: before, max_tokens: max_tokens)
    def save_aegis_state(tags: [], summary: nil, temperature: 1.0, working_dir: nil, thinking: nil, **) = Aegis.save_aegis_state(tags: tags, summary: summary, temperature: temperature, working_dir: working_dir, thinking: thinking)
    def load_aegis(db: nil, limit: 3) = Aegis.load_aegis(db: db, limit: limit)
    def restore_aegis(db = nil) = Aegis.restore_aegis(db)
    def unveil_aegis(**aegis) = Aegis.unveil_aegis(**aegis)
    def working_dir = Aegis.working_dir
    def set_working_dir(dir) = Aegis.set_working_dir(dir)
    def recall_aegis_notes(max_tokens: nil, max_content_length: nil) = Aegis.recall_aegis_notes(max_tokens: max_tokens, max_content_length: max_content_length)

    # -- Notes --
    def get_note(note_id) = Notes.get_note(note_id)
    def recall_notes(query, limit: 5, max_content_length: nil) = Notes.recall_notes(query, limit: limit, max_content_length: max_content_length)
    def create_note(content:, links: nil, tags: nil) = Notes.create_note(content: content, links: links, tags: tags)
    def remember(content:, links: nil, tags: nil) = Notes.remember(content: content, links: links, tags: tags)
    def fetch_notes_by_links(links) = Notes.fetch_notes_by_links(links)
    def update_note(id, content: nil, links: nil, tags: nil) = Notes.update_note(id, content: content, links: links, tags: tags)
    def remove_note(id) = Notes.remove_note(id)

    # -- MetempsychosisRouter --
    def metempsychosis(query:, from_task: nil, limit: 3, subscribe: false, unsubscribe: false, from_context: nil, to_context: nil, create_task_in: nil) = MetempsychosisRouter.metempsychosis(query: query, from_task: from_task, limit: limit, subscribe: subscribe, unsubscribe: unsubscribe, from_context: from_context, to_context: to_context, create_task_in: create_task_in)

    # -- TaskLedger --
    def create_task(title:, plan:, workflow_type: 'full', parent_task_id: nil) = TaskLedger.create_task(title: title, plan: plan, workflow_type: workflow_type, parent_task_id: parent_task_id)
    def max_steps_for_workflow(workflow_type) = TaskLedger.max_steps_for_workflow(workflow_type)
    def step_name(workflow_type, step_number) = TaskLedger.step_name(workflow_type, step_number)
    def get_subtasks(parent_task_id) = TaskLedger.get_subtasks(parent_task_id)
    def update_subtask_results(parent_task_id, subtask_id, result) = TaskLedger.update_subtask_results(parent_task_id, subtask_id, result)
    def get_task(task_id) = TaskLedger.get_task(task_id)
    def update_task(task_id, **fields) = TaskLedger.update_task(task_id, **fields)
    def remove_task(id) = TaskLedger.remove_task(id)
    def manage_tasks(params) = TaskLedger.manage_tasks(params)

    # -- Chronicle --
    def fetch_history(limit: 7, max_tokens: nil, include_tool_calls: false) = Chronicle.fetch_history(limit: limit, max_tokens: max_tokens, include_tool_calls: include_tool_calls)
    def record(prompt: '', attachments: [], tags: nil, file: nil, execution_time: 0, tool_call_count: 0, timestamp: nil, answer: '', tool_calls: [], task_id: nil, step_id: nil, mode: nil) = Chronicle.record(prompt: prompt, attachments: attachments, tags: tags, file: file, execution_time: execution_time, tool_call_count: tool_call_count, timestamp: timestamp, answer: answer, tool_calls: tool_calls, task_id: task_id, step_id: step_id, mode: mode)
    def truncate_tool_calls_by_priority(tool_calls) = Chronicle.truncate_tool_calls_by_priority(tool_calls)
    def truncate_hash_by_priority(hash, base_limit) = Chronicle.truncate_hash_by_priority(hash, base_limit)
    def get_entry(entry_id) = Chronicle.get_entry(entry_id)
    def search(query, limit: 5) = Chronicle.search(query, limit: limit)
    def format_history_tool_calls(tool_calls, index = 0) = Chronicle.format_history_tool_calls(tool_calls, index)
  end
end
