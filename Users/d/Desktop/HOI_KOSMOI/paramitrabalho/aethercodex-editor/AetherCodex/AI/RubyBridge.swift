import Foundation

/// Bridge between Swift and Ruby runtime
/// Calls existing oracle.rb methods
class RubyBridge {
    static let shared = RubyBridge()
    
    private var isInitialized = false
    private let rubyPath: String
    
    private init() {
        // Path to embedded Ruby or system Ruby
        self.rubyPath = Bundle.main.path(forResource: "ruby", ofType: nil)
            ?? "/usr/bin/ruby"
    }
    
    func initialize() {
        guard !isInitialized else { return }
        
        // Set up Ruby load path
        let supportPath = Bundle.main.path(forResource: "Support", ofType: nil)
            ?? Bundle.main.bundlePath + "/Support"
        
        setenv("RUBYLIB", supportPath, 1)
        
        // Initialize Ruby interpreter (if embedded)
        // For now, use subprocess approach
        isInitialized = true
        
        print("RubyBridge initialized with path: \(rubyPath)")
    }
    
    func cleanup() {
        // Cleanup Ruby runtime
        isInitialized = false
    }
    
    /// Call a Ruby method and return result as string
    func call(_ method: String, args: [Any]) -> String {
        let argString = args.map { argToString($0) }.joined(separator: ", ")
        let script = """
        require 'oracle'
        result = #{method}(#{argString})
        puts result.to_json
        """
        
        return executeRuby(script)
    }
    
    /// Execute raw Ruby code
    func execute(_ code: String) -> String {
        return executeRuby(code)
    }
    
    // MARK: - Private
    
    private func executeRuby(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: rubyPath)
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func argToString(_ arg: Any) -> String {
        switch arg {
        case let str as String:
            return "\"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
        case let num as NSNumber:
            return num.stringValue
        case let dict as [String: Any]:
            let pairs = dict.map { "\"\($0.key)\": \(argToString($0.value))" }
            return "{ \(pairs.joined(separator: ", ")) }"
        case let arr as [Any]:
            let items = arr.map { argToString($0) }
            return "[ \(items.joined(separator: ", ")) ]"
        default:
            return "nil"
        }
    }
}
