import SwiftUI

@main
struct News_MonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // Add Quit menu item
            CommandGroup(replacing: .appInfo) {
                Button("Quit News Monitor") {
                    NSApplication.shared.terminate(nil)
                }.keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launching...")
        
        // Ensure we're on the main thread when creating UI elements
        DispatchQueue.main.async { [weak self] in
            self?.menuBarController = MenuBarController()
            print("MenuBarController initialized")
        }
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
}
