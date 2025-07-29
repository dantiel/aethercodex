require 'redcarpet'
require 'rouge'



# Custom renderer with Rouge integration
class RougeRenderer < Redcarpet::Render::HTML
  def block_code(code, language)
    if language && !language.empty?
      lexer = Rouge::Lexer.find_fancy(language) || Rouge::Lexers::PlainText
      formatter = Rouge::Formatters::HTMLPygments.new Rouge::Formatters::HTML.new, css_class: 'highlight'
      formatter.format(lexer.lex(code))
    else
      "<pre><code>#{html_escape(code)}</code></pre>"
    end
  end


  private
  def html_escape(text)
    text.gsub(/[&<>"']/, '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;')
  end
end





module MarkdownRenderer
  # Renderer with Rouge syntax highlighting
  @rouge_renderer ||= Redcarpet::Markdown.new(
    RougeRenderer.new(hard_wrap: true, safe_links_only: true),
    fenced_code_blocks: true, 
    tables: true, 
    autolink: true, 
    strikethrough: true,
    superscript: true
  )

  # Original renderer for fallback
  @basic_renderer = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(hard_wrap: true, safe_links_only: true),
    fenced_code_blocks: true, 
    tables: true, 
    autolink: true, 
    strikethrough: true,
    superscript: true,
    prettify: true
  )
  

  # Primary method with Rouge highlighting
  def self.html_with_syntax_highlight(md)
    @rouge_renderer.render(md.to_s)
  end


  # Legacy method for compatibility
  def self.html(md)
    @basic_renderer.render(md.to_s)
  end
  
  
  def self.language_tag_from_path(filepath)
    language_tag_from_file File.basename filepath
  end
  
  
  def self.language_tag_from_file(filename)
    extension = File.extname(filename).delete('.')
    lexer = Rouge::Lexer.guess_by_filename filename

    if lexer
      return lexer.tag 
    elsif !extension.empty?
      lexer_by_extension = Rouge::Lexer.find(extension)
      return lexer_by_extension.tag if lexer_by_extension
    end

    return 'text'
  end
end
