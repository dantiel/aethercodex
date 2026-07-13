import SwiftUI

/// Observable theme — watches system appearance, exposes colors
@MainActor
final class ThemeManager: ObservableObject {
    @Published var isDark: Bool = false
    @Published var effectiveAppearance: NSAppearance.Name = .aqua

    var background: Color { isDark ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color(red: 0.97, green: 0.97, blue: 0.97) }
    var surface: Color    { isDark ? Color(red: 0.18, green: 0.18, blue: 0.20) : Color.white }
    var foreground: Color { isDark ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.10, green: 0.10, blue: 0.10) }
    var muted: Color      { isDark ? Color(red: 0.50, green: 0.50, blue: 0.52) : Color(red: 0.45, green: 0.45, blue: 0.47) }
    var accent: Color     { Color.accentColor }
    var gutter: Color     { isDark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color(red: 0.93, green: 0.93, blue: 0.93) }

    init() { refresh() }

    func refresh() {
        let name = NSApp.effectiveAppearance.name
        effectiveAppearance = name
        isDark = name == .darkAqua || name == .vibrantDark
            || name == .accessibilityHighContrastDarkAqua
            || name == .accessibilityHighContrastVibrantDark
    }
}
