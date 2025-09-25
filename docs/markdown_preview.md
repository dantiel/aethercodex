# ÆtherCodex Markdown Preview System

## Overview

The ÆtherCodex Markdown Preview system provides beautiful, hermetic-styled previews of markdown files with cosmic mystic styling. It converts markdown to HTML with AetherCodex's signature color scheme and typography, then opens the result in macOS Preview for professional-looking documentation.

## Features

### 🎨 **Hermetic Cosmic Styling**
- **AetherCodex Color Scheme**: Uses the official AetherCodex cosmic colors
- **Custom Typography**: Syne, Marcellus SC, and Iosevka fonts
- **Mystical Effects**: Glows, gradients, and animations
- **Responsive Design**: Works on desktop and mobile

### 📝 **Enhanced Markdown Support**
- **Full Markdown Syntax**: Tables, code blocks, lists, blockquotes
- **Code Highlighting**: Syntax highlighting for multiple languages
- **Link Styling**: Beautiful hover effects for links
- **Print Optimization**: Clean print styles for documentation

### 🚀 **Seamless Integration**
- **TextMate Command**: Keyboard shortcut for instant preview
- **Standalone Ruby Script**: Can be used independently
- **Automatic Cleanup**: Temporary files automatically removed
- **macOS Preview Integration**: Opens directly in Preview.app

## Usage

### TextMate Command

Use the keyboard shortcut `⌃⌥⌘P` (Control+Option+Command+P) or select **AetherCodex: Markdown Preview** from the bundle menu.

**Options:**
- **Current Selection**: Preview only selected text
- **Entire Document**: Preview the entire document

### Command Line Usage

```bash
# Preview a markdown file
cd Support && bundle exec ruby markdown_preview.rb ../path/to/file.md

# Preview markdown content directly
cd Support && bundle exec ruby markdown_preview.rb --content "# Hello World"
```

### Ruby API

```ruby
require_relative 'markdown_preview'

# Preview a file
AetherCodexMarkdownPreview.preview_file('documentation.md')

# Preview content from string
content = "# Hello World\n\nThis is **markdown** content."
AetherCodexMarkdownPreview.preview_content(content)

# Convert to HTML without preview
html = AetherCodexMarkdownPreview.convert_to_html(markdown_content)
```

## Styling Features

### Color Scheme

| Element | Color | Variable |
|---------|-------|----------|
| Headers | Cosmic Blue | `var(--argonaut-cosmic)` |
| Emphasis | Mystic Purple | `var(--argonaut-mystic)` |
| Strong Text | Hermetic Gold | `var(--hermetic-gold)` |
| Code Blocks | Dimensional Purple | `var(--dimensional-purple)` |
| Background | Void Black | `var(--void-black)` |

### Typography

- **Primary Font**: Syne (sans-serif)
- **Code Font**: Syne Mono / Iosevka Curly (monospace)
- **Header Font**: Marcellus SC (serif accents)

### Special Effects

- **Cosmic Pulse**: Subtle animation on headers
- **Hermetic Glow**: Text shadow effects
- **Gradient Backgrounds**: Deep space gradients
- **Hover Transitions**: Smooth color transitions

## Technical Implementation

### Dependencies

- **redcarpet**: Markdown parsing and conversion
- **tempfile**: Temporary file management
- **open3**: Process execution for Preview.app

### File Structure

```
Commands/markdown_preview.tmCommand    # TextMate command
Support/markdown_preview.rb           # Ruby implementation
test_markdown_preview.md              # Test file
docs/markdown_preview.md              # This documentation
```

### Temporary File Handling

1. **Creation**: Temporary HTML files created in `/tmp/`
2. **Preview**: Opened in macOS Preview
3. **Cleanup**: Files automatically removed after preview closes
4. **Safety**: Uses `lsof` to check if Preview is still using file

## Examples

### Basic Markdown

```markdown
# Project Documentation

## Installation

```bash
git clone https://github.com/username/project
cd project
bundle install
```

## Usage

Run the main script:

```bash
ruby main.rb
```
```

### Advanced Features

```markdown
# API Reference

## Methods

| Method | Parameters | Returns |
|--------|------------|---------|
| `transform` | `input: String` | `String` |
| `analyze` | `data: Array` | `Hash` |

## Code Example

```ruby
def hermetic_process(data)
  data.map(&:upcase)
      .select { |item| item.start_with?('A') }
      .then { |filtered| filtered.join(', ') }
end
```

> **Note**: This method demonstrates functional programming principles.
```

## Integration with Other Features

### Task Engine Integration

The Markdown Preview system can be integrated with the Magnum Opus Engine for automated documentation generation:

```ruby
task = {
  title: "Generate Documentation Preview",
  steps: [
    { action: "generate_markdown_docs" },
    { action: "preview_markdown", file: "docs/README.md" }
  ]
}
```

### Symbolic Patch Integration

Preview markdown documentation for symbolic patch operations:

```ruby
# Preview transformation documentation
AetherCodexMarkdownPreview.preview_content(<<~MD)
# Symbolic Patch: #{patch_name}

## Transformation

```
#{before_pattern}
```

→

```
#{after_pattern}
```

## Affected Files

#{affected_files.join("\n")}
MD
```

## Troubleshooting

### Common Issues

**Preview doesn't open:**
- Check if Preview.app is installed
- Verify temporary file permissions
- Ensure redcarpet gem is installed (`bundle install`)

**Styling not applied:**
- Check internet connection for font loading
- Verify CSS is properly embedded
- Test with basic markdown file

**Temporary files not cleaned up:**
- Files are removed when Preview closes
- Manual cleanup: `rm /tmp/aethercodex_preview_*.html`

### Performance Tips

- **Large Files**: Preview works best with files under 10MB
- **Font Loading**: First preview may be slower due to font download
- **Memory Usage**: Temporary files are automatically cleaned up

## Future Enhancements

### Planned Features

- **Live Preview**: Real-time preview as you type
- **Custom Themes**: User-selectable styling themes
- **Export Options**: PDF, PNG, and other formats
- **Template System**: Custom header/footer templates
- **Syntax Themes**: Multiple code highlighting themes

### Integration Ideas

- **Documentation Generator**: Auto-generate from code comments
- **API Documentation**: Integration with Swagger/OpenAPI
- **Project Reports**: Automated project status reports
- **Release Notes**: Beautiful release note generation

## Conclusion

The ÆtherCodex Markdown Preview system brings hermetic elegance to technical documentation. With its cosmic styling and seamless integration, it transforms ordinary markdown into beautiful, professional documentation that reflects the mystical nature of the ÆtherCodex project.

*Precision in documentation plane = precision in astral plane.*