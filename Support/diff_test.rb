require 'diffy'
# require 'differ'
require 'htmldiff'


# Function to perform character-level diff on *hunks* identified by Diffy
def hunk_based_character_diff_final(string1, string2)
  # Get the unified diff output from Diffy, including some context lines
  diff_output = Diffy::Diff.new(string1, string2, :context =>  3, :include_diff_info => true).to_s(:text) 
  # puts diff_output
  current_original_hunk_lines = []
  current_modified_hunk_lines = []
  out = ''

  diff_output.each_line do |line|
    case line[0] 
    when '@' # Hunk header
      out += process_hunk_final(current_original_hunk_lines, current_modified_hunk_lines)
      
      # Reset for the new hunk
      current_original_hunk_lines = []
      current_modified_hunk_lines = []
      out += "\n<span class=\"info\">#{line.strip}</span>\n"
    when '+'
      current_modified_hunk_lines << line[1..-1] unless "+++ " == line[0..3]
    when '-' # Deletion
      current_original_hunk_lines << line[1..-1] unless "--- " == line[0..3]
    when ' ' # Unchanged line (context line)
      current_original_hunk_lines << line[1..-1] 
      current_modified_hunk_lines << line[1..-1]
    end
  end

  # Process any remaining hunk at the end
  out += process_hunk_final(current_original_hunk_lines, current_modified_hunk_lines)
  
  out
end

def process_hunk_final(original_lines, modified_lines)
  # Differ.format = :html # Set Differ's format to HTML

  # Ensure both original_lines and modified_lines are non-nil before joining
  original_content = original_lines ? original_lines.join("") : ""
  modified_content = modified_lines ? modified_lines.join("") : ""
  
  puts "DIFF\n#{original_content}\nVS\n#{modified_content}"

  # Generate the character-level diff and print it directly
  # Differ.diff_by_char(modified_content, original_content).to_s
  HTMLDiff.diff(original_content, modified_content, html_format: { class: 'diff' })
end

# Example usage
string1 = <<~RUBY
  class MyClass
    def initialize
      @name = "Original"
    end
    
    identical
    identical2
    identical3
    identical4

    def greet
      puts "Hello, \#{@name}!"
    end
  end
RUBY

string2 = <<~RUBY
  class MyClass
    def initialize(name)
      @name = name || "Changed"
    end
    
    identical
    identical2
    identical3
    identical4

    def say_hello
      puts "Hi, \#{@name}!"
    end
  end
RUBY
#
# puts hunk_based_character_diff_final(string1, string2)
#
# puts "\n--- Another Example with simpler indentation ---"
# string3 = "  Line 1\n    Line 2 indented\n  Line 3"
# string4 = "  Line 1a\n    Line 2 indented changed\n  Line 3"
#
# puts hunk_based_character_diff_final(string3, string4)
#
# puts "\n--- Example with only additions ---"
# string5 = ""
# string6 = "  Added Line 1\n    Added Line 2\n  Added Line 3"
#
# puts hunk_based_character_diff_final(string5, string6)
#
# puts "\n--- Example with only deletions ---"
# string7 = "  Deleted Line 1\n    Deleted Line 2\n  Deleted Line 3"
# string8 = ""
#
# puts hunk_based_character_diff_final(string7, string8)
