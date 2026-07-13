import SwiftUI

@main
struct AetherCodexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var doc = DocumentManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(doc)
                .frame(minWidth: 1100, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") { doc.newDocument() }.keyboardShortcut("n")
                Button("Open…") { doc.openPanel() }.keyboardShortcut("o")
                Button("Save") { doc.save() }.keyboardShortcut("s")
            }
            CommandMenu("Oracle") {
                Button("Ask Oracle") {}.keyboardShortcut(.return, modifiers: [.command])
                Button("Explain Selection") {}.keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
    }
}
