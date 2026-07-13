import SwiftUI

struct ContentView: View {
    @EnvironmentObject var doc: DocumentManager
    @StateObject private var theme = ThemeManager()
    @State private var activeSidebarTab: SidebarTab = .files

    enum SidebarTab: String, CaseIterable {
        case files, oracle
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .files:  return "folder"
            case .oracle: return "wand.and.stars"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Sidebar ──
                sidebar
                    .frame(width: max(180, geo.size.width * 0.18))

                Divider()

                // ── Editor ──
                EditorView(doc: doc, theme: theme)
                    .frame(minWidth: 300)

                Divider()

                // ── Oracle inspector ──
                PythiaView(theme: theme)
                    .frame(width: max(280, geo.size.width * 0.30))
            }
        }
        .background(theme.background)
        .onAppear { theme.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            theme.refresh()
        }
        .toolbar { editorToolbar }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $activeSidebarTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            // Content
            Group {
                switch activeSidebarTab {
                case .files:
                    FileBrowserView(doc: doc)
                case .oracle:
                    VStack {
                        Spacer()
                        Label("Oracle active", systemImage: "wand.and.stars")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: { doc.newDocument() }) {
                Image(systemName: "doc.badge.plus")
            }.help("New")

            Button(action: { doc.openPanel() }) {
                Image(systemName: "folder.badge.plus")
            }.help("Open…")

            Button(action: { doc.save() }) {
                Image(systemName: "square.and.arrow.down")
            }.help("Save")
            .disabled(doc.currentURL == nil)

            Divider()

            Button(action: {}) {
                Image(systemName: "brain.head.profile")
            }.help("Explain Selection")
        }
    }
}