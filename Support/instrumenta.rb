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
        required: ['path']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'patch_file',
      description: 'Apply a unified diff (exactly 1 line of context) to a file.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          diff: { type: 'string' }
        },
        required: ['path','diff']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'run_command',
      description: 'Run an allowed shell command (rspec, rubocop, git…).',
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
      name: 'remember',
      description: 'Store a note in Mnemosyne memory.',
      parameters: {
        type: 'object',
        properties: {
          key:  { type: 'string' },
          body: { type: 'string' },
          tags: { type: 'array', items: { type: 'string' } }
        },
        required: ['key','body']
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
      name: 'add_note',
      description: 'Store a note in Mnemosyne (internal use only).',
      parameters: {
        type: 'object',
        properties: {
          key:  { type: 'string' },
          body: { type: 'string' },
          tags: { type: 'array', items: { type: 'string' } }
        },
        required: ['key','body']
      }
    }
  },
  {
    type: 'function',
    function: {
      name: 'recall_notes',
      description: 'Recall notes from Mnemosyne by tags or context (internal use only).',
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
      description: 'Fetch notes associated with specific file paths for Argonaut.',
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
      name: 'update_note',
      description: 'Update a note by id with optional content, links, and tags.',
      parameters: {
        type: 'object',
        properties: {
          id:      { type: 'integer' },
          content: { type: 'string' },
          links:   { type: 'array', items: { type: 'string' } },
          tags:    { type: 'array', items: { type: 'string' } }
        },
        required: ['id']
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
  }
]