import SwiftUI

/// Editor gutter — pure SwiftUI line numbers synced to scroll
struct EditorGutter: View {
    let lines: [String]
    let font: NSFont

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, _ in
                Text("\(idx + 1)")
                    .font(Font(font))
                    .foregroundColor(.secondary)
                    .frame(height: lineHeight, alignment: .top)
            }
        }
        .padding(.trailing, 6)
        .padding(.top, 4)
    }

    private var lineHeight: CGFloat {
        (font.ascender - font.descender) + font.leading + 2
    }
}

/// Native code editor — NSTextView via NSViewRepresentable
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 13

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let tv = NSTextView()
        tv.isRichText = false
        tv.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        tv.allowsUndo = true
        tv.isContinuousSpellCheckingEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.autoresizingMask = [.width]
        tv.delegate = context.coordinator
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isHorizontallyResizable = true
        tv.textContainer?.widthTracksTextView = false

        scrollView.documentView = tv
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView,
              tv.string != text else { return }
        let selected = tv.selectedRanges
        tv.string = text
        tv.selectedRanges = selected
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: CodeEditor
        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

/// Full editor pane — gutter + code area
struct EditorView: View {
    @ObservedObject var doc: DocumentManager
    @ObservedObject var theme: ThemeManager

    var body: some View {
        HStack(spacing: 0) {
            // Gutter
            EditorGutter(
                lines: doc.text.components(separatedBy: "\n"),
                font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            )
            .frame(width: 44)
            .background(theme.gutter)

            // Code area
            CodeEditor(text: $doc.text)
                .onChange(of: doc.text) { _ in doc.isDirty = true }
        }
        .background(theme.background)
    }
}
