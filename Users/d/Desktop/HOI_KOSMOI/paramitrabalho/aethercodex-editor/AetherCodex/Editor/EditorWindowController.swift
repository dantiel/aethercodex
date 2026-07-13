import Cocoa

class EditorWindowController: NSWindowController {
    var editorViewController: EditorViewController?
    var pythiaViewController: PythiaViewController?
    var splitViewController: NSSplitViewController?
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AetherCodex"
        window.minSize = NSSize(width: 600, height: 400)
        self.init(window: window)
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setupSplitView()
    }
    
    private func setupSplitView() {
        splitViewController = NSSplitViewController()
        
        editorViewController = EditorViewController()
        let editorItem = NSSplitViewItem(viewController: editorViewController!)
        editorItem.minimumThickness = 400
        splitViewController?.addSplitViewItem(editorItem)
        
        pythiaViewController = PythiaViewController()
        let pythiaItem = NSSplitViewItem(viewController: pythiaViewController!)
        pythiaItem.minimumThickness = 300
        pythiaItem.isCollapsed = true
        splitViewController?.addSplitViewItem(pythiaItem)
        
        window?.contentViewController = splitViewController
    }
    
    func toggleAIChat() {
        guard let splitViewController = splitViewController,
              let pythiaItem = splitViewController.splitViewItems.last else { return }
        pythiaItem.isCollapsed.toggle()
        if !pythiaItem.isCollapsed {
            pythiaViewController?.loadPythiaInterface()
        }
    }
}
