# frozen_string_literal: true

# LEXICON RESONANTIA: Hermetic Tag×File resonance matrix
# Atlantean pattern weaving for celestial code navigation
module LexiconResonantia
  class TextusContexor
    def initialize(notes, min_count: 1, top_k: nil)
      @notes = notes
      @min_count = min_count
      @top_k = top_k
      @weights = Hash.new { |h, k| h[k] = Hash.new(0) }
    end
    

    def ordinare_resonantias
      process_notes
      format_output
    end
    

    private


    def process_notes
      @notes.each do |note|
        # Handle tags (can be string or array)
        tags = if note[:tags].is_a?(Array)
                 note[:tags]
               else
                 note[:tags].to_s.split(',').map(&:strip).reject(&:empty?)
               end
        
        # Handle links (can be string or array, filter invalid paths)
        links = if note[:links].is_a?(Array)
                  note[:links]
                else
                  note[:links].to_s.split(',').map(&:strip).reject(&:empty?)
                end
        
        # Extract valid files (remove path not found markers)
        files = links.grep_v(/~~.*~~/)
        
        next if tags.empty? || files.empty?
        
        # Create unique (file, tag) pairs within this note
        files.product(tags).each do |file, tag|
          @weights[file][tag] += 1
        end
      end
    end


    def format_output
      # Calculate file totals for sorting
      file_totals = @weights.transform_values { |tags| tags.values.sum }
      
      # Sort files by total count desc, then filename asc
      sorted_files = file_totals.sort_by { |file, total| [-total, file] }
      
      sorted_files.map do |file, _total|
        tags = @weights[file]
        
        # Filter by min_count and sort tags by count desc, then tag asc
        filtered_tags = tags.select { |_, count| count >= @min_count }
        sorted_tags = filtered_tags.sort_by { |tag, count| [-count, tag] }
        
        # Apply top_k limit if specified
        sorted_tags = sorted_tags.take(@top_k) if @top_k
        
        # Format tags as TAG*COUNT pairs
        tag_pairs = sorted_tags.map { |tag, count| "#{tag}*#{count}" }
        
        "#{file}>#{tag_pairs.join(',')}"
      end.reject { |line| line.end_with?('>') } # Remove lines with no tags
    end
  end


  # Hermetic invocation to generate overview from notes
  def self.conjure(notes, min_count: 1, top_k: nil)
    TextusContexor.new(notes, min_count: min_count, top_k: top_k).ordinare_resonantias
  end

  # SYMBOLUM INTEGRATIO: Hermetic Tag×File resonance matrix integration
  # Weaves astral patterns between Mnemosyne's notes and the code plane
  def self.generate_from_notes(notes, min_count: 1, top_k: nil)
    # Transform notes to the expected format (handle both hash and array notes)
    formatted_notes = notes.map do |note|
      if note.is_a?(Hash)
        {
          id: note[:id] || note['id'],
          tags: note[:tags] || note['tags'],
          links: note[:links] || note['links']
        }
      else
        # Handle array format if needed
        { id: nil, tags: [], links: [] }
      end
    end
    
    conjure(formatted_notes, min_count: min_count, top_k: top_k)
  end
  
  def self.display_overview(overview_lines)
    puts "HERMETIC SYMBOLIC OVERVIEW"
    puts "=" * 50
    overview_lines.each { |line| puts line }
    puts "=" * 50
    puts "Total: #{overview_lines.size} file-tag mappings"
  end

  # Generate and display overview for AI visibility
  def self.generate_and_display_hermetic_overview(limit: 100, min_count: 1, top_k: nil)
    notes = recall_notes(limit: limit)[:notes]
    overview = generate_from_notes(notes, min_count: min_count, top_k: top_k)
    display_overview(overview)
    overview
  end
end

# Example usage:
# notes = recall_notes(limit: 50)[:notes]
# overview = LexiconResonantia.conjure(notes)
# puts overview.join("\n")
# LexiconResonantia.generate_and_display_hermetic_overview