import SwiftUI
import AppKit

// Extension to add preferences support to any view
extension View {
    func showPreferences() {
        // Create a new window for preferences
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
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// Extension to create NSColor from SwiftUI Color
extension NSColor {
    convenience init(_ color: Color) {
        // Try to get the CGColor first
        if let cgColor = color.cgColor, let nsColor = NSColor(cgColor: cgColor) {
            // Use the components from the created NSColor
            self.init(red: nsColor.redComponent, 
                  green: nsColor.greenComponent, 
                  blue: nsColor.blueComponent, 
                  alpha: nsColor.alphaComponent)
            return
        }
        
        // Fallback to white if we can't create the color
        self.init(white: 1.0, alpha: 1.0)
    }
}

// Helper extension to get CGColor from SwiftUI Color
extension Color {
    // Helper method to extract CGColor safely
    var cgColorSafe: CGColor {
        return self.cgColor ?? CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    }
}
#endif 