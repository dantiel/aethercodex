import SwiftUI

/// Native SwiftUI oracle chat — markdown rendered via AttributedString
struct PythiaView: View {
    @StateObject private var oracle = OracleViewModel()
    @ObservedObject var theme: ThemeManager
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(oracle.messages) { msg in
                            MessageBubble(msg: msg)
                                .id(msg.id)
                        }
                        if oracle.isLoading {
                            HStack { ProgressView().scaleEffect(0.6); Text("The oracle ponders…").font(.caption).foregroundColor(.secondary) }
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: oracle.messages.count) { _ in
                    if let last = oracle.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            // Divider + input
            Divider()
            HStack(spacing: 8) {
                TextField("Ask the Oracle…", text: $oracle.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .lineLimit(1...6)
                    .padding(8)
                    .background(theme.surface)
                    .cornerRadius(8)
                    .onSubmit { oracle.send() }

                Button(action: oracle.send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(oracle.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || oracle.isLoading)
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(10)
        }
        .background(theme.background)
        .onAppear { inputFocused = true }
    }
}

/// Single chat bubble
struct MessageBubble: View {
    let msg: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !msg.isUser { Spacer(minLength: 40) }
            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: msg.avatar)
                        .font(.caption)
                        .foregroundColor(msg.isUser ? .accentColor : .secondary)
                    Text(msg.isUser ? "You" : "ÆtherCodex")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                MarkdownText(msg.content)
                    .padding(10)
                    .background(msg.bubbleColor)
                    .cornerRadius(10)
            }
            if msg.isUser { Spacer(minLength: 40) }
        }
    }
}

/// Native markdown → AttributedString renderer
struct MarkdownText: View {
    let content: String

    init(_ content: String) { self.content = content }

    var body: some View {
        if #available(macOS 12, *) {
            Text(try! AttributedString(markdown: content,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                .textSelection(.enabled)
        } else {
            Text(content)
                .textSelection(.enabled)
        }
    }
}
