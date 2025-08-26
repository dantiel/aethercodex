# frozen_string_literal: true

require 'redcarpet'
require 'rouge'
require 'diffy'
require 'htmldiff'




# Custom renderer with Rouge integration
class RougeRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    if language && !language.empty?
      lexer = Rouge::Lexer.find_fancy(language) || Rouge::Lexers::PlainText
      formatter = Rouge::Formatters::HTMLPygments.new Rouge::Formatters::HTML.new,
                                                      css_class: 'highlight'
      formatter.format lexer.lex(code)
    else
      "<pre><code>#{html_escape code}</code></pre>"
    end
  end


  private


  def html_escape(text)
    text.gsub(/[&<>"']/, '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;',
                         "'" => '&#39;')
  end
end


module Scriptorium
  # Renderer with Rouge syntax highlighting
  @rouge_renderer ||= Redcarpet::Markdown.new \
    RougeRenderer.new(hard_wrap: true, safe_links_only: true),
    fenced_code_blocks: true,
    tables: true,
    no_intra_emphasis: true,
    autolink: true,
    strikethrough: true,
    superscript: true


  # Original renderer for fallback
  @basic_renderer = Redcarpet::Markdown.new \
    Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true, filter_html: false),
    fenced_code_blocks: true,
    tables: true,
    autolink: true,
    no_intra_emphasis: true,
    strikethrough: true,
    superscript: true,
    prettify: true


  # Primary method with Rouge highlighting
  def self.html_with_syntax_highlight(md)
    @rouge_renderer.render md.to_s.gsub(/([^\n])\n```(\w*)\n([^\n])/, "\\1\n\n```\\2\n\\3")
  end


  # Legacy method for compatibility
  def self.html(md)
    @basic_renderer.render md.to_s
  end


  def self.language_tag_from_path(filepath)
    language_tag_from_file File.basename filepath
  end


  def self.language_tag_from_file(filename)
    extension = File.extname(filename).delete '.'
    lexer = Rouge::Lexer.guess_by_filename filename

    if lexer
      return lexer.tag
    elsif !extension.empty?
      lexer_by_extension = Rouge::Lexer.find extension
      return lexer_by_extension.tag if lexer_by_extension
    end

    'text'
  end


  # Function to perform character-level diff on *hunks* identified by Diffy
  def self.hunk_based_character_diff(old_content, new_content, path = nil)
    diff_output = Diffy::Diff.new(old_content, new_content,
                                  context: 3, include_diff_info: true).to_s :text
    original_hunk_lines = []
    modified_hunk_lines = []
    out = ''

    diff_output.each_line do |line|
      case line[0]
      when '@'
        unless original_hunk_lines.empty? and modified_hunk_lines.empty?
          out += "#{process_hunk original_hunk_lines, modified_hunk_lines}</div>"
        end

        original_hunk_lines = []
        modified_hunk_lines = []
        unless path.nil?
          line = line.gsub(/@@ -([0-9]+),([0-9]+) \+([0-9]+),([0-9]+) @@/,
                           "<file path=\"#{path}\" line=\"\\3\">@@ -\\1,\\2 +\\3,\\4 @@</file>")
        end

        out += "<span class=\"info\">#{line.strip}</span>\n<div class=\"hunk-content\">"
      when '+'
        modified_hunk_lines << line[1..] unless '+++ ' == line[0..3]
      when '-'
        original_hunk_lines << line[1..] unless '--- ' == line[0..3]
      when ' '
        original_hunk_lines << line[1..]
        modified_hunk_lines << line[1..]
      end
    end

    out += "#{process_hunk original_hunk_lines, modified_hunk_lines}</div>"

    out
  end


  def self.process_hunk(original_lines, modified_lines)
    original_content = original_lines ? original_lines.join : ''
    modified_content = modified_lines ? modified_lines.join : ''

    HTMLDiff.diff original_content, modified_content, html_format: { class: 'diff' }
  end
end