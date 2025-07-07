import SwiftUI
import AppKit

enum AppAppearance: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2
}

enum VideoFormat: Int, CaseIterable {
    case mp4 = 0
    case proRes422 = 1
    case proRes422HQ = 2
    case proRes4444 = 3
}

enum PreferenceImageFormat: Int, CaseIterable {
    case png = 0
    case jpeg = 1
    case tiff = 2
}

class PreferencesViewModel: ObservableObject {
    // MARK: - Appearance Settings
    @AppStorage("appearance") var appearance: AppAppearance = .system
    @AppStorage("useAccentColor") var useAccentColor: Bool = false
    @AppStorage("accentColorR") var accentColorR: Double = 0.0
    @AppStorage("accentColorG") var accentColorG: Double = 0.5
    @AppStorage("accentColorB") var accentColorB: Double = 1.0
    @AppStorage("accentColorA") var accentColorA: Double = 1.0
    
    @AppStorage("showGrid") var showGrid: Bool = true
    @AppStorage("snapToGrid") var snapToGrid: Bool = true
    @AppStorage("gridSize") var gridSize: Double = 16
    @AppStorage("gridColorR") var gridColorR: Double = 0.7
    @AppStorage("gridColorG") var gridColorG: Double = 0.7
    @AppStorage("gridColorB") var gridColorB: Double = 0.7
    @AppStorage("gridColorA") var gridColorA: Double = 0.3
    
    @AppStorage("canvasBgColorR") var canvasBgColorR: Double = 0.95
    @AppStorage("canvasBgColorG") var canvasBgColorG: Double = 0.95
    @AppStorage("canvasBgColorB") var canvasBgColorB: Double = 0.95
    @AppStorage("canvasBgColorA") var canvasBgColorA: Double = 1.0
    
    // MARK: - Export Settings
    @AppStorage("defaultVideoFormat") var defaultVideoFormat: VideoFormat = .mp4
    @AppStorage("defaultFrameRate") var defaultFrameRate: Int = 30
    @AppStorage("includeAlphaChannel") var includeAlphaChannel: Bool = false
    @AppStorage("exportLocation") var exportLocation: String = ""
    
    @AppStorage("defaultImageFormat") var defaultImageFormat: PreferenceImageFormat = .png
    @AppStorage("jpegQuality") var jpegQuality: Double = 0.9
    
    // MARK: - General Settings
    @AppStorage("restorePreviousSession") var restorePreviousSession: Bool = true
    @AppStorage("autoSaveProjects") var autoSaveProjects: Bool = true
    @AppStorage("autoSaveInterval") var autoSaveInterval: Int = 5
    @AppStorage("checkForUpdates") var checkForUpdates: Bool = true
    
    @AppStorage("enableHardwareAcceleration") var enableHardwareAcceleration: Bool = true
    @AppStorage("timelineCacheSize") var timelineCacheSize: Double = 500
    
    // MARK: - Computed Properties
    var accentColor: Color {
        get {
            Color(red: accentColorR, green: accentColorG, blue: accentColorB, opacity: accentColorA)
        }
        set {
            if let components = NSColor(newValue).cgColor.components, components.count >= 4 {
                accentColorR = Double(components[0])
                accentColorG = Double(components[1])
                accentColorB = Double(components[2])
                accentColorA = Double(components[3])
            }
        }
    }
    
    var gridColor: Color {
        get {
            Color(red: gridColorR, green: gridColorG, blue: gridColorB, opacity: gridColorA)
        }
        set {
            if let components = NSColor(newValue).cgColor.components, components.count >= 4 {
                gridColorR = Double(components[0])
                gridColorG = Double(components[1])
                gridColorB = Double(components[2])
                gridColorA = Double(components[3])
            }
        }
    }
    
    var canvasBackgroundColor: Color {
        get {
            Color(red: canvasBgColorR, green: canvasBgColorG, blue: canvasBgColorB, opacity: canvasBgColorA)
        }
        set {
            if let components = NSColor(newValue).cgColor.components, components.count >= 4 {
                canvasBgColorR = Double(components[0])
                canvasBgColorG = Double(components[1])
                canvasBgColorB = Double(components[2])
                canvasBgColorA = Double(components[3])
            }
        }
    }
    
    // MARK: - Methods
    func selectExportLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                exportLocation = url.path
            }
        }
    }
    
    func clearCache() {
        // Implementation would clear the cached animation frames and timeline data
        // This is a placeholder for the actual implementation
        let notificationCenter = NotificationCenter.default
        notificationCenter.post(name: Notification.Name("ClearCacheNotification"), object: nil)
    }
} 