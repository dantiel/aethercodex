import SwiftUI

/// ViewModel for oracle conversation — messages, sending, Ruby bridge
@MainActor
final class OracleViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isLoading: Bool = false

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        input = ""
        isLoading = true

        let query = text
        RubyBridge.shared.sendToOracle(message: query) { [weak self] response in
            DispatchQueue.main.async {
                self?.messages.append(ChatMessage(role: .assistant, content: response))
                self?.isLoading = false
            }
        }
    }

    func clear() { messages.removeAll() }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role { case user, assistant }

    var isUser: Bool { role == .user }
    var avatar: String { isUser ? "person.circle.fill" : "wand.and.stars" }
    var bubbleColor: Color {
        isUser ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.08)
    }
}