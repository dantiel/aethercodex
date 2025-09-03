require_relative '../instrumentarium/diff_crepusculum'



RSpec.describe DiffCrepusculum::ChrysopoeiaDiff do
  let(:strategy) { described_class.new }


  describe '#VALIDATE_MARKER_SEQUENCING' do
    it 'validates correct marker sequencing' do
      diff = "<<<<<<< SEARCH\nfoo\n=======\nbar\n>>>>>>> REPLACE"
      expect(strategy.validate_marker_sequencing(diff)).to eq({ success: true })
    end

    it 'handles escaped newlines in diff content' do
      diff = "<<<<<<< SEARCH\r\nfoo\r\n=======\r\nbar\r\n>>>>>>> REPLACE"
      expect(strategy.validate_marker_sequencing(diff)).to eq({ success: true })
    end

    it 'rejects incorrect marker sequencing' do
      diff = "=======\nfoo\n<<<<<<< SEARCH\nbar\n>>>>>>> REPLACE"
      expect(strategy.validate_marker_sequencing(diff)).to include(success: false)
    end
  end


  describe '#parse_replacements' do
    it 'parses search/replace blocks correctly' do
      diff = "<<<<<<< SEARCH\nfoo\n=======\nbar\n>>>>>>> REPLACE"
      replacements = strategy.parse_replacements(diff)
      expect(replacements).to eq([{ start_line: nil, search_content: "foo", replace_content: "bar" }])
    end
  end


  describe "perform_fuzzy_search" do
    it "finds exact matches" do
      content = "def foo\n  bar\nend".split(/\r?\n/)
      expect(strategy.perform_fuzzy_search(content, ["bar"], 1)[:success]).to eq(true)
    end

    it "finds approximate matches" do
      content = "def foo\n  baz\nend".split(/\r?\n/)
      expect(strategy.perform_fuzzy_search(content, ["bar"], 1)[:success]).to eq(true)
    end

    it "ignores indentation for scoring" do
      content = "def foo\n    deeply_indented\nend".split(/\r?\n/)
      expect(strategy.perform_fuzzy_search(content, ["deeply_indented"], 1)[:success]).to eq(true)
    end

    it "handles low thresholds conservatively" do
      content = "def foo\n  barely_matching\nend\nend2\nend3\nend4".split(/\r?\n/)
      expect(strategy.perform_fuzzy_search(content, "def foo\n  barely_matching".split(/\r?\n/), 1)[:success]).to eq(true)
    end
  end
  

  describe '#apply_replacement' do
    it 'applies replacements with indentation preservation' do
      lines = ["  foo", "  bar", "  baz"]
      updated = strategy.apply_replacement(lines, 1, ["bar"], ["qux"])
      expect(updated).to eq(["  foo", "  qux", "  baz"])
    end

    it 'handles nested indentation' do
      lines = ["x","    foo", "      bar", "    baz"]
      updated = strategy.apply_replacement(lines, 2, ["      bar"], ["      qux"])
      expect(updated).to eq(["x","    foo", "      qux", "    baz"])
    end
    
    it 'handles deeply nested indentation with fuzzy matching' do
      # puts "TEST"
      lines = ["def outer", "  def inner", "    puts \"nested\"", "  end", "end"]
      updated = strategy.apply_replacement(lines, 1, ["  def inner", "    puts \"nested\""], ["  def inner", "    puts \"updated\""])
      # puts "TEST2"

      expect(updated).to eq(["def outer", "  def inner", "    puts \"updated\"", "  end", "end"])
    end
  end


  describe '#apply_diff' do
    it 'applies a basic diff correctly' do
      content = "foo\nbar\nbaz"
      diff = "<<<<<<< SEARCH\nbar\n=======\nqux\n>>>>>>> REPLACE"
      result = strategy.apply_diff(content, diff)[:content]
      expect(result).to eq("foo\nqux\nbaz")
    end

    it 'handles escaped newlines in diff content' do
      content = "foo\r\nbar\r\nbaz"
      diff = "<<<<<<< SEARCH\r\nbar\r\n=======\r\nqux\r\n>>>>>>> REPLACE"
      result = strategy.apply_diff(content, diff)[:content]
      expect(result).to eq("foo\nqux\nbaz")
    end
    
    it 'returns original content if diff is invalid' do
      content = "foo\nbar\nbaz"
      diff = "<<<<<<< SEARCH\ninvalid\n=======\nqux\n>>>>>>> REPLACE"
      result = strategy.apply_diff(content, diff)[:content]
      expect(result).to eq(nil)
    end

    it 'test with start_line' do
      content = "foo\nbar\nbaz"
      diff = "<<<<<<< SEARCH\n:start_line:1\n-------\nfoo\n=======\nqux\n>>>>>>> REPLACE"
      result = strategy.apply_diff(content, diff)[:content]
      expect(result).to eq("qux\nbar\nbaz")
    end
      
    # Test placeholder for specialized diff testing scenarios
    # it 'test with start_line' do
    #   content = File.read "prima_materia.rb"
    #
    #   diff = """
    #     <<<<<<< SEARCH
    #         when 'file_overview'  then file_overview(**args)
    #         else { error: \"Unknown tool \#{tool}\" }
    #         end
    #       rescue ArgumentError => e
    #     =======
    #         when 'file_overview'  then file_overview(**args)
    #         when 'reasoning_model' then reasoning_model(**args)
    #         else { error: \"Unknown tool \#{tool}\" }
    #         end
    #       rescue ArgumentError => e
    #     >>>>>>> REPLACE
    #   """
    #   result = strategy.apply_diff(content, diff)
    #   puts result.inspect
    #
    #   expect(result[:content]).to eq("qux\nbar\nbaz")
    # end
  end
end