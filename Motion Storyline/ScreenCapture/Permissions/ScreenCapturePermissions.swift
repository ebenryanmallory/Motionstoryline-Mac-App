import Foundation
import AppKit

enum ScreenCapturePermissionsHelper {
    
    /// Opens System Settings to the Screen Recording privacy section
    static func openSystemSettingsPrivacyScreenRecording() {
        // Try macOS 13+ System Settings first, fallback to older System Preferences
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Provides user-friendly permission status information
    static func getPermissionStatusDescription() -> String {
        let hasPermission = CGPreflightScreenCaptureAccess()
        
        if hasPermission {
            return "Screen recording permission is granted."
        } else {
            return """
            Screen recording permission is required to capture screen content.
            
            To grant permission:
            1. Open System Settings > Privacy & Security > Screen Recording
            2. Enable Motion Storyline
            3. Restart the app if needed
            """
        }
    }
    
    /// Shows an alert with permission instructions
    static func showPermissionAlert(from window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = getPermissionStatusDescription()
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        if let window = window {
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn {
                    openSystemSettingsPrivacyScreenRecording()
                }
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openSystemSettingsPrivacyScreenRecording()
            }
        }
    }
    
    /// Checks if screen recording permission is currently granted
    static func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Verifies all required permissions for screen capture are in place
    static func verifyPermissionConfiguration() -> (hasEntitlement: Bool, hasUsageDescription: Bool, systemPermission: Bool) {
        // Check if running in development (simplified check)
        let bundle = Bundle.main
        let hasEntitlement = bundle.object(forInfoDictionaryKey: "com.apple.security.device.screen-recording") != nil
        let hasUsageDescription = bundle.object(forInfoDictionaryKey: "NSScreenRecordingUsageDescription") != nil
        let systemPermission = hasScreenRecordingPermission()
        
        return (hasEntitlement: hasEntitlement, hasUsageDescription: hasUsageDescription, systemPermission: systemPermission)
    }
}

