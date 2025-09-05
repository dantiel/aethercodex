module TestModule
  class TestClass
    def instance_method
      "instance method"
    end
    
    def self.class_method
      "class method"
    end
    
    CONSTANT = "value"
  end
  
  def module_function
    "module function"
  end
end

require 'some_gem'
require_relative 'local_file'

def standalone_function
  "standalone"
end