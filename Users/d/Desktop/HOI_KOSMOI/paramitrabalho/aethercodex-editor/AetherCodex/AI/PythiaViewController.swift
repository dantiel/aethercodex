import Cocoa
import WebKit

class PythiaViewController: NSViewController {
    var webView: WKWebView!
    var rubyBridge: RubyBridge { RubyBridge.shared }
    
    override func loadView() {
        self.view = NSView()
        self.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadPythia()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // Message handler for communication
        config.userContentController.add(self, name: "pythia")
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadPythia() {
        // Load from local Pythia directory
        let pythiaURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Pythia")
            ?? URL(fileURLWithPath: "Pythia/index.html")
        
        webView.loadFileURL(pythiaURL, allowingReadAccessTo: pythiaURL.deletingLastPathComponent())
    }
    
    func sendContext(_ context: [String: Any]) {
        let jsonData = try? JSONSerialization.data(withJSONObject: context)
        guard let jsonString = jsonData.flatMap({ String(data: $0, encoding: .utf8) }) else { return }
        
        let script = "window.pythiaContext = \(jsonString);"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func sendMessage(_ message: String) {
        let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "window.receiveMessage(\"\(escaped)\");"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
}

// MARK: - WKScriptMessageHandler

extension PythiaViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "pythia",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }
        
        switch action {
        case "ask":
            if let question = body["question"] as? String {
                handleAsk(question: question, context: body["context"] as? [String: Any])
            }
        case "tool":
            if let toolName = body["tool"] as? String,
               let args = body["args"] as? [String: Any] {
                handleToolCall(name: toolName, args: args)
            }
        default:
            break
        }
    }
    
    private func handleAsk(question: String, context: [String: Any]?) {
        // Call Ruby oracle
        let result = rubyBridge.call("Oracle.divination", args: [question, context ?? [:]])
        
        // Send response back to Pythia
        DispatchQueue.main.async {
            self.sendMessage(result)
        }
    }
    
    private func handleToolCall(name: String, args: [String: Any]) {
        // Execute tool via Ruby bridge
        let result = rubyBridge.call("Instrumenta.execute", args: [name, args])
        
        DispatchQueue.main.async {
            self.sendMessage(result)
        }
    }
}

// MARK: - WKNavigationDelegate

extension PythiaViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Pythia loaded, ready for messages
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Pythia failed to load: \(error)")
    }
}
