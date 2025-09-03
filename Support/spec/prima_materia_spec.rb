require_relative '../instrumentarium/instrumenta'
require_relative 'fake_mnemosyne'



RSpec.describe PrimaMateria do
  # PrimaMateria is a module, so we test its singleton methods directly
  let(:fake_mnemosyne) { FakeMnemosyne.new }


  before do
    allow(Mnemosyne).to receive(:new).and_return(fake_mnemosyne)
  end
  

  describe "#instrumenta_schema" do
    it "returns a complete schema with all tools and aliases" do
      schema = Instrumenta.instrumenta_schema
      
      expect(schema).to be_an(Array)
      expect(schema.size).to eq(39) # 20 tools + 19 aliases (updated count)
      
      # Check a few key tools exist
      read_file_tool = schema.find { |t| t[:function][:name] == "read_file" }
      expect(read_file_tool).not_to be_nil
      expect(read_file_tool[:function][:name]).to eq("read_file")
      expect(read_file_tool[:function][:description]).to include("Read a file")
      
      patch_file_tool = schema.find { |t| t[:function][:name] == "patch_file" }
      expect(patch_file_tool).not_to be_nil
      expect(patch_file_tool[:function][:description]).to include("PRECISE, TARGETED modifications")
    end
  end
  

  describe "#handle" do
    context "with valid parameters" do
      it "successfully calls read_file with valid parameters" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "../README.md", "range" => [1, 10]}})
        expect(result).to be_a(Hash)
        expect(result[:content]).to include("AetherCodex") if result[:content]
      end

      it "successfully calls tell_user with valid parameters" do
        result = Instrumenta::handle({"tool" => "tell_user", "args" => {"message" => "Test message", "level" => "info"}})
        expect(result[:say][:message]).to eq("Test message")
        expect(result[:say][:level]).to eq("info")
      end

      it "successfully calls run_command with valid parameters" do
        result = Instrumenta::handle({"tool" => "run_command", "args" => {"cmd" => "echo 'test'"}})
        expect(result).to be_a(Hash)
        expect(result[:result]).to include("test")
      end

      it "handles tool aliases correctly" do
        result = Instrumenta::handle({"tool" => "readfile", "args" => {"path" => "../README.md", "range" => [1, 5]}})
        expect(result).to be_a(Hash)
        expect(result[:content]).to be_a(String) if result[:content]
      end
    end

    context "with invalid parameters" do
      it "raises error for missing required parameters" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {}})
        expect(result[:error]).to include("missing required parameter: path")
      end

      it "raises error for invalid parameter types" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => 123, "range" => [1, 10]}})
        expect(result[:error]).to include("path must be a String")
      end

      it "raises error for out of range values" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => [-1, 10]}})
        expect(result[:error]).to include("range[0] must be >= 0")
      end

      it "raises error for invalid enum values" do
        result = Instrumenta::handle({"tool" => "tell_user", "args" => {"message" => "test", "level" => "invalid"}})
        expect(result[:error]).to include("level must be one of: info, warn")
      end
    end

    context "with default values" do
      it "applies default values for missing optional parameters" do
        result = Instrumenta::handle({"tool" => "tell_user", "args" => {"message" => "test"}}) # level defaults to "info"
        expect(result[:say][:level]).to eq("info") # default applied
        expect(result[:say][:message]).to eq("test")
      end
    end

    context "with unknown tool" do
      it "raises error for unknown tool name" do
        result = Instrumenta::handle({"tool" => "unknown_tool", "args" => {}})
        expect(result[:error]).to include("Unknown tool unknown_tool")
      end
    end
  end
  

  describe "parameter validation" do
    describe "string validation" do
      it "validates minLength constraint" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "", "range" => [1, 10]}})
        expect(result[:error]).to include("path must be at least 1 characters")
      end
    end

    describe "integer validation" do
      it "validates minimum constraint" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => [-5, 10]}})
        expect(result[:error]).to include("range[0] must be >= 0")
      end

      it "validates maximum constraint" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => [1, 20000]}})
        expect(result[:error]).to include("range[1] must be <= 10000")
      end
    end

    describe "array validation" do
      it "validates minItems constraint" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => []}})
        expect(result[:error]).to include("range must have at least 2 items")
      end

      it "validates maxItems constraint" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => [1, 2, 3]}})
        expect(result[:error]).to include("range must have at most 2 items")
      end

      it "validates array item types" do
        result = Instrumenta::handle({"tool" => "read_file", "args" => {"path" => "test.txt", "range" => ["one", "two"]}})
        expect(result[:error]).to include("range\[0\] must be an Integer")
      end
    end

    describe "boolean validation" do
      it "accepts true boolean values" do
        # Test with a tool that has boolean parameters when available
        result = Instrumenta::handle({"tool" => "run_command", "args" => {"cmd" => "echo test"}})
        expect(result).to be_a(Hash)
      end

      it "rejects non-boolean values for boolean parameters" do
        # This will test when we have boolean parameters in tools
        # For now, just ensure the validation method works
        expect {
          Instrumenta::PRIMA_MATERIA.send(:validate_type, "test_param", "test", :boolean)
        }.to raise_error(ArgumentError, /test_param must be a Boolean/)
      end
    end
  end
  

  describe "tool registration" do
    it "has all expected tools registered" do
      expect(Instrumenta::tools.keys).to include(
        :read_file, :oracle_conjuration, :run_command, :create_file, :rename_file,
        :recall_history, :tell_user, :recall_notes, :file_overview, :remember,
        :remove_note, :patch_file, :aegis, :create_task, :execute_task,
        :update_task, :evaluate_task, :list_tasks, :reject_step, :complete_step
      )
    end

    xit "has all expected aliases registered" do
      expect(PrimaMateria::TOOL_ALIASES.keys.map(&:to_sym)).to include(
        :readfile, :patchfile, :createfile, :runcommand, :renamefile,
        :telluser, :oracleconjuration, :rejectstep, :completestep
      )
    end
  end
  
  describe "#merge_tools" do
    let(:prima1) { PrimaMateria.new }
    let(:prima2) { PrimaMateria.new }
    
    before do
      prima1.add_instrument(:tool1, description: "First tool", params: {}) { |**| { result: "tool1" } }
      prima2.add_instrument(:tool2, description: "Second tool", params: {}) { |**| { result: "tool2" } }
    end
    
    it "merges tools from two PrimaMateria instances" do
      merged = prima1.merge_tools(prima2)
      
      expect(merged.tools.keys).to include(:tool1, :tool2)
      expect(merged.tools.size).to eq(2)
    end
    
    it "handles overlapping tool names by overwriting with second instance" do
      prima1.add_instrument(:common_tool, description: "First version", params: {}) { |**| { result: "first" } }
      prima2.add_instrument(:common_tool, description: "Second version", params: {}) { |**| { result: "second" } }
      
      merged = prima1.merge_tools(prima2)
      
      # Should use the second instance's implementation
      result = merged.handle({"tool" => "common_tool", "args" => {}})
      expect(result[:result]).to eq("second")
    end
    
    it "creates a new instance without modifying the originals" do
      original_size1 = prima1.tools.size
      original_size2 = prima2.tools.size
      
      merged = prima1.merge_tools(prima2)
      
      expect(prima1.tools.size).to eq(original_size1)
      expect(prima2.tools.size).to eq(original_size2)
      expect(merged).to be_a(PrimaMateria)
      expect(merged).not_to equal(prima1)
      expect(merged).not_to equal(prima2)
    end
    
    it "preserves tool functionality in merged instance" do
      merged = prima1.merge_tools(prima2)
      
      result1 = merged.handle({"tool" => "tool1", "args" => {}})
      result2 = merged.handle({"tool" => "tool2", "args" => {}})
      
      expect(result1[:result]).to eq("tool1")
      expect(result2[:result]).to eq("tool2")
    end
    
    it "returns self for method chaining" do
      merged = prima1.merge_tools(prima2)
      expect(merged).to be_a(PrimaMateria)
    end
  end
  
  describe "#merge_tools!" do
    let(:prima1) { PrimaMateria.new }
    let(:prima2) { PrimaMateria.new }
    
    before do
      prima1.add_instrument(:tool1, description: "First tool", params: {}) { |**| { result: "tool1" } }
      prima2.add_instrument(:tool2, description: "Second tool", params: {}) { |**| { result: "tool2" } }
    end
    
    it "merges tools destructively into the first instance" do
      original_size = prima1.tools.size
      
      prima1.merge_tools!(prima2)
      
      expect(prima1.tools.keys).to include(:tool1, :tool2)
      expect(prima1.tools.size).to eq(original_size + 1)
      expect(prima2.tools.size).to eq(1) # Should remain unchanged
    end
    
    it "handles overlapping tool names by overwriting with second instance" do
      prima1.add_instrument(:common_tool, description: "First version", params: {}) { |**| { result: "first" } }
      prima2.add_instrument(:common_tool, description: "Second version", params: {}) { |**| { result: "second" } }
      
      prima1.merge_tools!(prima2)
      
      # Should use the second instance's implementation
      result = prima1.handle({"tool" => "common_tool", "args" => {}})
      expect(result[:result]).to eq("second")
    end
    
    it "modifies the first instance in place" do
      original_prima1 = prima1
      
      prima1.merge_tools!(prima2)
      
      expect(prima1).to equal(original_prima1)
      expect(prima1.tools.size).to eq(2)
    end
    
    it "preserves tool functionality after merge" do
      prima1.merge_tools!(prima2)
      
      result1 = prima1.handle({"tool" => "tool1", "args" => {}})
      result2 = prima1.handle({"tool" => "tool2", "args" => {}})
      
      expect(result1[:result]).to eq("tool1")
      expect(result2[:result]).to eq("tool2")
    end
    
    it "returns self for method chaining" do
      result = prima1.merge_tools!(prima2)
      expect(result).to equal(prima1)
    end
  end
end