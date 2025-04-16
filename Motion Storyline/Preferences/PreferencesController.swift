import SwiftUI
import AppKit

class PreferencesController: NSObject, NSWindowDelegate {
    private static var preferencesWindow: NSWindow?
    private static var instance: PreferencesController?
    
    static func showPreferences() {
        // Check if we already have a window open
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create controller instance if needed
        if instance == nil {
            instance = PreferencesController()
        }
        
        // Create a new window
        let preferencesView = PreferencesView()
            .environmentObject(AppStateManager.shared)
        
        let hostingController = NSHostingController(rootView: preferencesView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.contentView = hostingController.view
        window.title = "Preferences"
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.delegate = instance
        
        preferencesWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - NSWindowDelegate
    
    func windowWillClose(_ notification: Notification) {
        // Just hide the window instead of letting it close
        if let window = notification.object as? NSWindow, window == PreferencesController.preferencesWindow {
            window.orderOut(nil)
        }
    }
} 