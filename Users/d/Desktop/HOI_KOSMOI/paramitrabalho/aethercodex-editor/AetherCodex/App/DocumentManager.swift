import SwiftUI
import UniformTypeIdentifiers

/// Observable document state — open file, dirty flag, save/load
@MainActor
final class DocumentManager: ObservableObject {
    @Published var currentURL: URL?
    @Published var text: String = ""
    @Published var isDirty: Bool = false

    var fileName: String { currentURL?.lastPathComponent ?? "Untitled" }
    var title: String { "\(fileName)\(isDirty ? " ●" : "") — ÆtherCodex" }

    func newDocument() {
        currentURL = nil
        text = ""
        isDirty = false
    }

    func open(_ url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        currentURL = url
        text = content
        isDirty = false
    }

    func save() {
        guard let url = currentURL else { return saveAs() }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        isDirty = false
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.swiftSource, UTType.rubyScript, UTType.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        currentURL = url
        isDirty = false
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }
}
