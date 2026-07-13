import SwiftUI

/// Native SwiftUI file browser sidebar
struct FileBrowserView: View {
    @ObservedObject var doc: DocumentManager
    @State private var rootURL: URL = URL(fileURLWithPath: NSHomeDirectory())
    @State private var entries: [FileEntry] = []
    @State private var expanded: Set<URL> = []

    var body: some View {
        List(entries, children: \.children) { entry in
            Label {
                Text(entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: entry.icon)
                    .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if entry.isDirectory {
                    toggleExpand(entry.url)
                } else {
                    doc.open(entry.url)
                }
            }
            .onTapGesture(count: 1) {
                if entry.isDirectory { toggleExpand(entry.url) }
            }
        }
        .listStyle(.sidebar)
        .task { loadRoot() }
        .onChange(of: expanded) { _ in refreshEntries() }
    }

    private func loadRoot() {
        rootURL = URL(fileURLWithPath: NSHomeDirectory())
        expanded.insert(rootURL)
        refreshEntries()
    }

    private func toggleExpand(_ url: URL) {
        if expanded.contains(url) { expanded.remove(url) }
        else { expanded.insert(url) }
    }

    private func refreshEntries() {
        entries = children(of: rootURL)
    }

    private func children(of url: URL) -> [FileEntry] {
        guard expanded.contains(url),
              let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }

        return contents
            .sorted { ($0.lastPathComponent.lowercased()) < ($1.lastPathComponent.lowercased()) }
            .map { u in
                let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FileEntry(url: u, name: u.lastPathComponent, isDirectory: isDir)
            }
    }
}

struct FileEntry: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool

    var icon: String { isDirectory ? "folder" : "doc.text" }
    var children: [FileEntry]? { isDirectory ? [] : nil }
}
