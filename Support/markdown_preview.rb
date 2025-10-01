# frozen_string_literal: true
require 'bundler/setup'

require 'tempfile'
require 'open3'
require_relative 'instrumentarium/scriptorium'

# AetherCodex Markdown Preview System
# Converts markdown files to beautifully styled HTML with hermetic cosmic styling
module AetherCodexMarkdownPreview
  extend self

  # AetherCodex cosmic mystic styling
  AETHERCODEX_CSS = <<~CSS
    /* AetherCodex - Cosmic Mystic Styling */
    @import url('https://fonts.googleapis.com/css2?family=Syne+Mono&family=Syne+Tactile&family=Syne:wght@400..800&display=swap');
    @import url('https://iosevka-webfonts.github.io/iosevka-curly/iosevka-curly.css');
    :root {
        --mono: "Syne Mono","Iosevka Curly", "Fira Code", monospace;
        --sans: "Syne","General Sans","Plus Jakarta Sans","Inter",sans-serif;
        --argonaut-void: #151515; 
        --argonaut-deep: #000C16;   
        --argonaut-azure: #00A6FF;  
        --argonaut-cosmic: #6497C5; 
        --argonaut-nexus: #62A6FF;  
        --argonaut-cosmic2: #4a90e2;
        --argonaut-mystic: #8e44ad;
        --void-black: #0a0a0a;
        --astral-gray: #1a1a1a;
        --ethereal-white: #f8f9fa;
        --hermetic-gold: #f39c12;
        --dimensional-purple: #6c5ce7;
        --arcane-teal: #17a2b8;
        --mystic-rose: #e74c3c;
        --ethereal-green: #27ae60;
    }

    body {
        font-family: var(--sans);
        background: linear-gradient(135deg, var(--void-black) 0%, var(--astral-gray) 100%);
        color: var(--ethereal-white);
        min-height: 100vh;
        line-height: 1.6;
        margin: 0;
        padding: 3rem;
        max-width: 1200px;
        margin: 0 auto;
    }

    h1 {
        color: var(--argonaut-cosmic2);
        text-shadow: 0 0 20px rgba(74, 144, 226, 0.5);
        border-bottom: 2px solid var(--argonaut-mystic);
        padding-bottom: 0.5rem;
        margin-bottom: 2rem;
        font-size: 2.5rem;
    }

    h2 {
        color: var(--argonaut-mystic);
        text-shadow: 0 0 15px rgba(142, 68, 173, 0.4);
        margin-top: 2rem;
        font-size: 2rem;
    }

    h3 {
        color: var(--hermetic-gold);
        text-shadow: 0 0 10px rgba(243, 156, 18, 0.3);
        font-size: 1.5rem;
    }

    h4, h5, h6 {
        color: var(--dimensional-purple);
    }

    p {
        margin: 1rem 0;
        font-size: 1.1rem;
    }

    strong {
        color: var(--hermetic-gold);
        font-weight: 700;
    }

    em {
        color: var(--argonaut-mystic);
        font-style: italic;
    }

    code {
        background: rgba(26, 26, 26, 0.8);
        color: var(--argonaut-cosmic2);
        font-family: var(--mono);
        padding: 0.2rem 0.4rem;
        border-radius: 4px;
        border: 1px solid rgba(74, 144, 226, 0.3);
        font-size: 0.9rem;
    }

    pre {
        background: rgba(10, 10, 10, 0.9);
        padding: 1.5rem;
        border-radius: 8px;
        border: 1px solid var(--dimensional-purple);
        margin: 1.5rem 0;
        overflow-x: auto;
        -webkit-backdrop-filter: blur(0.2rem);
        backdrop-filter: blur(0.2rem);
    }

    pre code {
        background: transparent;
        border: none;
        padding: 0;
        font-size: 0.9rem;
        line-height: 1.4;
    }

    blockquote {
        border-left: 4px solid var(--arcane-teal);
        padding-left: 1.5rem;
        margin: 1.5rem 0;
        background: rgba(23, 162, 184, 0.1);
        padding: 1rem 1.5rem;
        border-radius: 0 8px 8px 0;
        font-style: italic;
    }

    ul, ol {
        padding-left: 2rem;
    }

    li {
        margin: 0.5rem 0;
    }

    a {
        color: var(--argonaut-cosmic2);
        text-decoration: none;
        border-bottom: 1px solid transparent;
        transition: all 0.3s ease;
    }

    a:hover {
        color: var(--argonaut-mystic);
        border-bottom-color: var(--argonaut-mystic);
        text-shadow: 0 0 10px var(--argonaut-mystic);
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 1.5rem 0;
        background: rgba(26, 26, 26, 0.8);
        border: 1px solid rgba(74, 144, 226, 0.3);
        border-radius: 8px;
        overflow: hidden;
    }

    th {
        background: rgba(74, 144, 226, 0.2);
        color: var(--argonaut-cosmic2);
        padding: 1rem;
        text-align: left;
        font-weight: 600;
    }

    td {
        padding: 1rem;
        border-top: 1px solid rgba(74, 144, 226, 0.1);
    }

    tr:hover {
        background: rgba(74, 144, 226, 0.05);
    }

    hr {
        border: none;
        border-bottom: 0.2em solid var(--argonaut-void);
    }

    /* Scrollbar Styling */
    ::-webkit-scrollbar {
      width: 0.5rem;
      height:0.5rem;
    }

    ::-webkit-scrollbar-track {
      background: var(--argonaut-deep);
      border-radius: 0.25rem;
    }

    ::-webkit-scrollbar-thumb {
      background: linear-gradient(135deg, var(--argonaut-cosmic), var(--argonaut-azure));
      border-radius: 0.25rem;
      transition: all 0.3s ease;
    }

    ::-webkit-scrollbar-thumb:hover {
      background: linear-gradient(135deg, var(--argonaut-azure), var(--argonaut-nexus));
    }

    ::-webkit-scrollbar-corner {
      background: color-mix(in srgb, var(--argonaut-deep) 30%, transparent);
    }
    
    .aethercodex-header {
        text-align: center;
        padding: 2rem;
        background: radial-gradient(circle at center, rgba(74, 144, 226, 0.1) 0%, transparent 70%);
        margin-bottom: 3rem;
        border-radius: 10px;
        border: 1px solid rgba(74, 144, 226, 0.3);
    }

    .aethercodex-header h1 {
        font-size: 3rem;
        margin: 0;
        border: none;
        padding: 0;
        text-shadow: 0 0 30px var(--argonaut-cosmic2);
    }

    .aethercodex-header .subtitle {
        color: var(--hermetic-gold);
        font-style: italic;
        opacity: 0.8;
        margin-top: 0.5rem;
        font-size: 1.2rem;
    }

    .aethercodex-footer {
        text-align: center;
        padding: 2rem;
        margin-top: 3rem;
        color: var(--hermetic-gold);
        opacity: 0.7;
        font-size: 0.9rem;
        border-top: 1px solid rgba(243, 156, 18, 0.3);
    }

    /* Hermetic mystical effects */
    .hermetic-glow {
        text-shadow: 0 0 10px currentColor;
    }

    .cosmic-pulse {
        animation: cosmic-pulse 3s ease-in-out infinite;
    }

    @keyframes cosmic-pulse {
        0%, 100% { opacity: 0.7; }
        50% { opacity: 1; }
    }

    /* Print styles */
    @media print {
        body {
            background: white;
            color: black;
            padding: 1rem;
            max-width: none;
        }
        
        .aethercodex-header, .aethercodex-footer {
            display: none;
        }
        
        pre {
            background: #f8f8f8;
            border: 1px solid #ddd;
        }
        
        code {
            background: #f8f8f8;
            border: 1px solid #ddd;
        }
    }

    /* Responsive design */
    @media (max-width: 768px) {
        body {
            padding: 1rem;
        }
        
        .aethercodex-header h1 {
            font-size: 2rem;
        }
        
        h1 { font-size: 2rem; }
        h2 { font-size: 1.5rem; }
        h3 { font-size: 1.25rem; }
    }
  CSS
  
  SYNTAX_CSS = File.read (File.join __dir__, "pythia/syntax-styles.css")

  # Convert markdown content to HTML with AetherCodex styling
  # @param markdown_content [String] The markdown content to convert
  # @param title [String] Optional title for the document
  # @return [String] Complete HTML document with AetherCodex styling
  def convert_to_html(markdown_content, title: "AetherCodex Markdown Preview")
    # Convert markdown to HTML
    html_content = Scriptorium.html_with_syntax_highlight markdown_content

    # Build complete HTML document
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{title}</title>
          <style type="text/css">#{AETHERCODEX_CSS}</style>
          <style type="text/css">#{SYNTAX_CSS}</style>
      </head>
      <body>
          <!-- <div class="aethercodex-header cosmic-pulse">
              <h1 class="hermetic-glow">ÆtherCodex</h1>
              <div class="subtitle">Markdown Preview - Hermetic Wisdom Revealed</div>
          </div>
           -->
          #{html_content}
          <!--
          <div class="aethercodex-footer">
              Generated with ÆtherCodex Markdown Preview • #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}
          </div> -->
      </body>
      </html>
    HTML
  end

  # Preview markdown file in macOS Preview
  # @param file_path [String] Path to markdown file
  # @param open_in_preview [Boolean] Whether to open in macOS Preview
  # @return [String] Path to generated HTML file
  def preview_file(file_path, open_in_preview: true)
    unless File.exist?(file_path)
      raise "Markdown file not found: #{file_path}"
    end

    markdown_content = File.read(file_path)
    html_content = convert_to_html(markdown_content, title: File.basename(file_path))

    # Create temporary HTML file
    temp_html = Tempfile.new(['aethercodex_preview_', '.html.txt'])
    temp_html.write(html_content)
    temp_html.close

    if open_in_preview
      # Open in macOS Preview
      system('open', '-a', 'Preview', temp_html.path)
      
      # Schedule cleanup after preview closes
      Thread.new do
        sleep 10  # Wait for Preview to open
        # Check if Preview is still using the file
        while `lsof #{temp_html.path} 2>/dev/null`.include?('Preview')
          sleep 5
        end
        File.unlink(temp_html.path) if File.exist?(temp_html.path)
      end
    end

    temp_html.path
  end

  # Preview markdown content from string
  # @param content [String] Markdown content
  # @param open_in_preview [Boolean] Whether to open in macOS Preview
  # @return [String] Path to generated HTML file
  def preview_content(content, open_in_preview: true)
    html_content = convert_to_html(content)

    # Create temporary HTML file
    temp_html = Tempfile.new(['aethercodex_preview_', '.html'])
    temp_html.write(html_content)
    temp_html.close

    if open_in_preview
      # Open in macOS Preview
      system('qlmanage', '-p', "#{temp_html.path}")
      
      # Schedule cleanup after preview closes
      Thread.new do
        sleep 10  # Wait for Preview to open
        # Check if Preview is still using the file
        while `lsof #{temp_html.path} 2>/dev/null`.include?('Preview')
          sleep 5
        end
        File.unlink(temp_html.path) if File.exist?(temp_html.path)
      end
    end

    temp_html.path
  end

  # Command line interface for TextMate - outputs HTML to stdout
  def self.textmate_preview
    content = ARGF.read
    preview_content content
  end

  # Command line interface for file preview
  def self.run_cli
    if ARGV.empty?
      puts "Usage: #{$0} <markdown_file>"
      puts "       #{$0} --content 'markdown content here'"
      exit 1
    end

    if ARGV[0] == '--content'
      content = ARGV[1..-1].join(' ')
      preview_content(content)
    else
      file_path = ARGV[0]
      if File.exist?(file_path)
        preview_file(file_path)
      else
        puts "Error: File '#{file_path}' not found"
        exit 1
      end
    end

    puts "Markdown preview generated and opened in Preview.app"
  end
end

# Run CLI if executed directly
if __FILE__ == $0
  if ENV['TM_SELECTED_TEXT'] || ENV['TM_FULLNAME']
    # Running from TextMate - output HTML to stdout
    AetherCodexMarkdownPreview.textmate_preview
  else
    # Running as CLI - open in Preview app
    AetherCodexMarkdownPreview.run_cli
  end
end