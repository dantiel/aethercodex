TOOLS = [
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
      description: 'Apply a unified diff to a file.',
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
      name: 'recall',
      description: 'Retrieve notes from Mnemosyne memory.',
      parameters: {
        type: 'object',
        properties: {
          query: { type: 'string' },
          limit: { type: 'integer', default: 3 }
        },
        required: ['query']
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
  }
]
