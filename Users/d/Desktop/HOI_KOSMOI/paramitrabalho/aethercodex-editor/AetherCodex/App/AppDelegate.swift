import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        RubyBridge.shared.initialize()
        setupMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {}

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "ÆtherCodex")
        appMenu.addItem(withTitle: "About ÆtherCodex", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit ÆtherCodex", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        NSApp.mainMenu = mainMenu
    }
}