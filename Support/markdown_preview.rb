# frozen_string_literal: true
require 'bundler/setup'

require 'tempfile'
require 'open3'
require_relative 'instrumentarium/scriptorium'

# AetherCodex Markdown Preview System
# Converts markdown files to beautifully styled HTML with hermetic cosmic styling
module AetherCodexMarkdownPreview
  extend self
  
  UIDIR = "file://#{ENV['TM_BUNDLE_SUPPORT']}/pythia"

  # Convert markdown content to HTML with AetherCodex styling
  # @param markdown_content [String] The markdown content to convert
  # @param title [String] Optional title for the document
  # @return [String] Complete HTML document with AetherCodex styling
  def convert_to_html(markdown_content, title: "AetherCodex Markdown Preview")
    # Convert markdown to HTML
    html_content = Scriptorium.html_with_syntax_highlight markdown_content
    puts "UIDIR #{UIDIR} #{ENV.inspect}"

    # Build complete HTML document
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta name="theme-color" content="#4285f4">
        
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{title}</title>
          <link rel="stylesheet" href="#{UIDIR}/markdown-preview.css?random=0">
          <link rel="stylesheet" href="#{UIDIR}/syntax-styles.css?random=0">
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