# The following serves as Schema for AI API and will be converted to JSON. This is the collection of all available tools but may be filtered later however.
INSTRUMENTA = [
  {
    type: 'function',
    function: {
      name: 'read_file',
      description: 'Read a file (optionally a line range).',
      parameters: {
        type: 'object',
        properties: {
          path:  { type: 'string' },
          range: { type: 'array', items: { type: 'integer' }, minItems: 2, maxItems: 2 }
        },
        required: ['path', 'diff']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'oracle_conjuration',
      description: (
        <<~DESCRIPTION
        Invoke the reasoning model to generate responses based on a prompt and filtered tools. Make 
        sure to provide a meaningful and profound prompt as invocation to the high oracle and give a 
        rich context as sacred offerings like files and other tools output, however the oracle may 
        call tools on its own, too.
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          prompt: { type: 'string', description: 'The input prompt for reasoning.' }
        },
        required: ['prompt'],
        forbidden: ['recursive']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'run_command',
      description: (
        <<~DESCRIPTION
        Run an allowed shell command in project base dir. Allowed: `rspec`, `rubocop`, `git`, `ls`, 
        `cat`, `mkdir`, `$TM_QUERY`, `echo`, `grep`, `bundle exec ruby`, `bundle exec irb`, `ruby`, 
        `irb`, `cd`, `curl`, `ag`. Please suggest to add more cmds to this list if you like.
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          cmd: { type: 'string' }
        },
        required: ['cmd']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_file',
      description: 'Create (or overwrite) a file with given content.',
      parameters: {
        type: 'object',
        properties: {
          path:      { type: 'string' },
          content:   { type: 'string' },
          overwrite: { type: 'boolean', default: false }
        },
        required: ['path','content']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'rename_file',
      description: 'Rename a file with given content.',
      parameters: {
        type: 'object',
        properties: {
          from: { type: 'string' },
          to:   { type: 'string' }
        },
        required: ['from','to']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'recall_history',
      description: 'Retrieve notes from Mnemosyne. Without a query just yields last.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
          limit: { type: 'integer', default: 3 }
        },
        required: []
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'tell_user',
      description: 'If you wish to inform the user mid-process.',
      parameters: {
        type: 'object',
        properties: {
          message: { type: 'string' },
          level: { type: 'string', enum: ['info', 'warn'] }
        },
        required: ['message']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'recall_notes',
      description: """
        Recall notes from Mnemosyne by tags, content
        or context (internal use only).""",
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
          limit: { type: 'integer', default: 3 }
        }
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'file_overview',
      description: (
        <<~DESCRIPTION
        Fetch all information associated with a file (e.g., ai notes metadata and related file metadata, size, number of line, last modified).
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string' }
        },
        required: ['path']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'remember',
      description: (
        <<~DESCRIPTION
        Store a note in Mnemosyne memory. To overwrite existing note use id, otherwise a new note 
        will be created. Remove redundant notes with remove_note. links is an array of linked paths, 
        these are used by file_overview tool. These can be many or only one file, thus reflecting on 
        multifile relations and significatives. When links are empty or null the note will be stored 
        in a global context and always be present.
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          id:      { type: 'integer' },
          content: { type: 'string' },
          links:   { type: 'array', items: { type: 'string' } },
          tags: { type: 'array', items: { type: 'string' } }
        },
        required: ['content']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'remove_note',
      description: 'Remove a note by id.',
      parameters: {
        type: 'object',
        properties: {
          id: { type: 'integer' }
        },
        required: ['id']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'patch_file',
      description: (
        <<~DESCRIPTION
        Request to apply PRECISE, TARGETED modifications to an existing file by searching for 
        specific sections of content and replacing them. This tool is for SURGICAL EDITS ONLY - 
        specific changes to existing code.

        You can perform multiple distinct search and replace operations within a single `patch_file` 
        call by providing multiple SEARCH/REPLACE blocks in the `diff` parameter. This is the 
        preferred way to make several targeted changes efficiently.

        The SEARCH section must exactly match existing content including whitespace and indentation. 
        If you're not confident in the exact content to search for, use the `read_file` tool first 
        to get the exact content.

        When applying the diffs, be extra careful to remember to change any closing brackets or 
        other syntax that may be affected by the diff farther down in the file.

        ALWAYS make as many changes in a single 'patch_file' request as possible using multiple 
        SEARCH/REPLACE blocks.
        
        If a patch fails it may be that the line number was too wrong.

        ### Diff Format:
        ```
        <<<<<<< SEARCH
        :start_line: (required) The line number of original content where the search block begins.
        -------
        [exact content to find including whitespace]
        =======
        [new content to replace with]
        >>>>>>> REPLACE
        ```

        ### Example 1: Single Edit
        ```
        <<<<<<< SEARCH
        :start_line:116
        -------
        def calculate_total(items):
            total = 0
            for item in items:
                total += item
            return total
        =======
        def calculate_total(items):
            """Calculate total with 10% markup"""
            return sum(item * 1.1 for item in items)
        >>>>>>> REPLACE
        ```

        ### Example 2: Multiple Edits
        ```
        <<<<<<< SEARCH
        :start_line:10
        -------
        def calculate_total(items):
            sum = 0
        =======
        def calculate_sum(items):
            sum = 0
        >>>>>>> REPLACE

        <<<<<<< SEARCH
        :start_line:42
        -------
            total += item
            return total
        =======
            sum += item
            return sum
        >>>>>>> REPLACE
        ```
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          diff: { type: 'string' }
        },
        required: ['path', 'diff']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'aegis',
      description: (
        <<~DESCRIPTION
        The Aegis tool is for enabling an active context from Mnemosyne during conversations. When topic in current conversation changes you have to change or refine its state, ensuring relevance and precision in context note recall. Use it to refine the oracle’s focus. The Aegis tool will immediately return notes like `recall_notes` and keep them in context unlike `recall_notes` which only retrieves note for current interaction.
        DESCRIPTION
      ),
      parameters: {
        type: 'object',
        properties: {
          tags: { type: 'array', items: { type: 'string' } },
          summary: { type: 'string', description: 'Dynamic summary update without altering tags. Required for every invocation.' },
          temperature: { type: 'number', description: 'Optional parameter to fine-tune the Aegis state responsiveness.' }
        },
        required: []
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_task',
      description: 'Generate a task for complex prompts with fields for plan, progress, and max_steps.',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'The title of the plan.' },
          plan: { type: 'string', description: 'The task execution plan.' },
          max_steps: { type: 'integer', description: 'Total steps in the task.' }
        },
        required: ['plan', 'max_steps', 'title']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'execute_task',
      description: 'Run the task loop with minimal intervention, updating status and progress.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to execute.' }
        },
        required: ['task_id']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'update_task',
      description: 'Dynamically refine the task plan during execution.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to update.' },
          new_plan: { type: 'string', description: 'The updated task plan.' }
        },
        required: ['task_id', 'new_plan']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'evaluate_task',
      description: 'Check task progress and handle edge cases.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to evaluate.' }
        },
        required: ['task_id']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'create_task',
      description: 'Generate a task for complex prompts with fields for plan, progress, and max_steps.',
      parameters: {
        type: 'object',
        properties: {
          plan: { type: 'string', description: 'The task execution plan.' },
          max_steps: { type: 'integer', description: 'Total steps in the task.' }
        },
        required: ['plan', 'max_steps']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'execute_task',
      description: 'Run the task loop with minimal intervention, updating status and progress.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to execute.' }
        },
        required: ['task_id']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'update_task',
      description: 'Dynamically refine the task plan during execution.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to update.' },
          new_plan: { type: 'string', description: 'The updated task plan.' }
        },
        required: ['task_id', 'new_plan']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'evaluate_task',
      description: 'Check task progress and handle edge cases.',
      parameters: {
        type: 'object',
        properties: {
          task_id: { type: 'integer', description: 'The ID of the task to evaluate.' }
        },
        required: ['task_id']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'list_tasks',
      description: 'List all active tasks in the system.',
      parameters: {
        type: 'object',
        properties: {},
        required: []
      }
    }
  }
]