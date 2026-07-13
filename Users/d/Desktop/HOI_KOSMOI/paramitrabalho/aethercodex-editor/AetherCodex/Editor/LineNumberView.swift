import Cocoa

class LineNumberView: NSView {
    weak var scrollView: NSScrollView?
    weak var textView: NSTextView?
    
    private let lineNumberWidth: CGFloat = 45
    private let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private let textColor = NSColor.secondaryLabelColor
    
    init(scrollView: NSScrollView, textView: NSTextView) {
        self.scrollView = scrollView
        self.textView = textView
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let textView = textView else { return }
        
        let context = NSGraphicsContext.current?.cgContext
        context?.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context?.fill(dirtyRect)
        
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        let visibleRect = scrollView?.documentVisibleRect ?? .zero
        
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        let string = textView.string as NSString
        let startLine = string.lineNumber(for: charRange.location)
        let endLine = string.lineNumber(for: NSMaxRange(charRange))
        
        for lineNumber in startLine...endLine {
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: charRange.location, effectiveRange: nil)
            let y = lineRect.origin.y - visibleRect.origin.y + textView.textContainerInset.height
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let lineString = "\(lineNumber)" as NSString
            let size = lineString.size(withAttributes: attributes)
            let x = lineNumberWidth - size.width - 5
            
            lineString.draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }
    }
}

extension NSString {
    func lineNumber(for location: Int) -> Int {
        let substring = self.substring(to: min(location, self.length))
        return substring.components(separatedBy: "\n").count
    }
}
