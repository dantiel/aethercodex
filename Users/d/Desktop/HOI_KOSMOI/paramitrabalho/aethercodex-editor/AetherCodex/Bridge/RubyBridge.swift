import Foundation

/// Bridge to embedded Ruby runtime
/// Calls existing Ruby code from Support/oracle/
class RubyBridge {
    static let shared = RubyBridge()
    
    private var isInitialized = false
    private let queue = DispatchQueue(label: "com.aethercodex.ruby", qos: .userInitiated)
    
    private init() {}
    
    /// Initialize Ruby interpreter
    func initialize() {
        guard !isInitialized else { return }
        
        queue.async {
            // TODO: Initialize embedded Ruby
            // This requires:
            // 1. Linking libruby (statically or dynamically)
            // 2. Calling ruby_init()
            // 3. Loading Support/oracle/oracle.rb
            // 4. Setting up $LOAD_PATH to find all dependencies
            
            // For now, use NSTask to run Ruby externally
            self.isInitialized = true
            print("Ruby bridge initialized (external mode)")
        }
    }
    
    /// Send message to Oracle divination
    func sendToOracle(message: String, completion: @escaping (String) -> Void) {
        queue.async {
            // Option 1: Use NSTask to run Ruby script
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
            
            // Find Support directory
            let supportPath = Bundle.main.resourcePath! + "/../Support"
            
            task.arguments = [
                "-I", supportPath,
                "-e",
                """
                require 'oracle/oracle'
                
                # Create minimal context
                context = {
                  messages: [{role: 'user', content: '\(message)'}],
                  tools: Instrumenta.instrumenta_schema
                }
                
                # Call divination
                result = Oracle.divination(context)
                puts result
                """
            ]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Error: No output"
                completion(output)
            } catch {
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Call Ruby method with arguments
    func call(method: String, arguments: [String], completion: @escaping (String) -> Void) {
        queue.async {
            // Build Ruby command
            let argsString = arguments.map { "'\($0)'" }.joined(separator: ", ")
            let rubyCode = "puts Oracle.\(method)(\(argsString))"
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
            task.arguments = ["-e", rubyCode]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                completion(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                completion("Error: \(error.localizedDescription)")
            }
        }
    }
}
