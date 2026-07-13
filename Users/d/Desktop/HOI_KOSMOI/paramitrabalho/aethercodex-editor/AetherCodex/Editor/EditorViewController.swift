import Cocoa

class EditorViewController: NSViewController {
    var textView: NSTextView!
    var scrollView: NSScrollView!
    var currentFileURL: URL?
    
    override func loadView() {
        self.view = NSView()
        self.view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupEditor()
    }
    
    private func setupEditor() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Create text view
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        
        textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        
        // Line numbers
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        scrollView.documentView = textView
        view.addSubview(scrollView)
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Document Operations
    
    func newDocument() {
        textView.string = ""
        currentFileURL = nil
        view.window?.title = "AetherCodex — Untitled"
    }
    
    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .sourceCode]
        
        panel.beginSheetModal(for: view.window!) { result in
            if result == .OK, let url = panel.url {
                self.loadFile(url: url)
            }
        }
    }
    
    func saveDocument() {
        if let url = currentFileURL {
            saveFile(url: url)
        } else {
            saveDocumentAs()
        }
    }
    
    func saveDocumentAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        
        panel.beginSheetModal(for: view.window!) { result in
            if result == .OK, let url = panel.url {
                self.saveFile(url: url)
                self.currentFileURL = url
            }
        }
    }
    
    private func loadFile(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            textView.string = content
            currentFileURL = url
            view.window?.title = "AetherCodex — \(url.lastPathComponent)"
        } catch {
            showError("Failed to load file: \(error.localizedDescription)")
        }
    }
    
    private func saveFile(url: URL) {
        do {
            try textView.string.write(to: url, atomically: true, encoding: .utf8)
            view.window?.title = "AetherCodex — \(url.lastPathComponent)"
        } catch {
            showError("Failed to save file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AI Context
    
    func getDocumentContext() -> [String: Any] {
        let selectedRange = textView.selectedRange()
        let selection = textView.string.nsString.substring(with: selectedRange)
        
        return [
            "file_path": currentFileURL?.path ?? "untitled",
            "file_name": currentFileURL?.lastPathComponent ?? "Untitled",
            "content": textView.string,
            "selection": selection,
            "cursor_line": textView.string.nsString.lineNumber(for: selectedRange.location)
        ]
    }
    
    func insertText(_ text: String, at location: Int? = nil) {
        let insertLoc = location ?? textView.selectedRange().location
        textView.insertText(text, replacementRange: NSRange(location: insertLoc, length: 0))
    }
    
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }
}

// MARK: - NSTextViewDelegate

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        // Update line numbers
        scrollView.verticalRulerView?.needsDisplay = true
    }
}

// MARK: - Line Number Ruler

class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    let textColor = NSColor.secondaryLabelColor
    
    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        self.clientView = textView
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var requiredThickness: CGFloat {
        return 40
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let textView = textView else { return }
        
        let contentRect = textView.visibleRect
        let layoutManager = textView.layoutManager!
        let textContainer = textView.textContainer!
        
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: contentRect, in: textContainer)
        let visibleLineRange = layoutManager.lineFragmentRect(forGlyphAt: visibleGlyphRange.location, effectiveRange: nil)
        
        let context = NSGraphicsContext.current!.cgContext
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(dirtyRect)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Draw line numbers
        var lineNumber = 1
        let glyphRange = layoutManager.glyphRange(forCharacterSet: .newline, actualCharacterRange: nil)
        
        layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { rect, usedRect, textContainer, glyphRange, stop in
            let lineRect = NSRect(x: 0, y: usedRect.origin.y, width: self.requiredThickness - 8, height: usedRect.height)
            let string = "\(lineNumber)" as NSString
            string.draw(in: lineRect, withAttributes: attributes)
            lineNumber += 1
            return true
        }
    }
}

// MARK: - String Extensions

extension String {
    var nsString: NSString {
        return self as NSString
    }
}

extension NSString {
    func lineNumber(for location: Int) -> Int {
        let substring = self.substring(to: location)
        return substring.components(separatedBy: .newlines).count
    }
}
