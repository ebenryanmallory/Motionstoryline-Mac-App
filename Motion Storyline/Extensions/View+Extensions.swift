import SwiftUI
import AppKit

// Extension to add preferences support to any view
extension View {
    func openPreferences() {
        // Use AppKit to show the app preferences window
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        
        // Post notification that preferences should be shown
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowPreferences"),
            object: nil
        )
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