import Foundation
import SwiftUI

/// Helper for accessing assets and resources in both Xcode and Swift Package Manager builds
enum ResourceHelper {
    /// Returns the appropriate bundle for resource loading
    /// When built with SPM, this will use Bundle.module
    /// When built with Xcode, this will use Bundle.main
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        // When built with Swift Package Manager
        return Bundle.module
        #else
        // When built with Xcode
        return Bundle.main
        #endif
    }
    
    /// Load an image from Assets.xcassets that works in both Xcode and SPM builds
    static func image(named name: String) -> NSImage? {
        NSImage(symbolName: name, bundle: resourceBundle, variableValue: 0.0)
    }
    
    /// Load a color from Assets.xcassets that works in both Xcode and SPM builds
    static func color(named name: String) -> NSColor? {
        NSColor(named: name, bundle: resourceBundle)
    }
    
    /// Load a color from Assets.xcassets for use with SwiftUI
    static func swiftUIColor(named name: String) -> Color {
        Color(name, bundle: resourceBundle)
    }
    
    /// Load an image from Assets.xcassets for use with SwiftUI
    static func swiftUIImage(named name: String) -> Image {
        Image(name, bundle: resourceBundle)
    }
} 