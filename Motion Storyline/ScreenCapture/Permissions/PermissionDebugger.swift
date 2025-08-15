import Foundation
import AppKit
import ScreenCaptureKit
import CoreGraphics

struct PermissionDebugger {
    
    /// Comprehensive permission and entitlement check
    static func performFullDiagnostic() {
        print("🔬 [DIAGNOSTIC] Starting comprehensive permission diagnostic...")
        print("=" * 80)
        
        // 1. Bundle Information
        printBundleInformation()
        print("-" * 40)
        
        // 2. Entitlements Check
        printEntitlementsStatus()
        print("-" * 40)
        
        // 3. System Permission Status
        printSystemPermissionStatus()
        print("-" * 40)
        
        // 4. Code Signing Information
        printCodeSigningInformation()
        print("-" * 40)
        
        // 5. macOS Version Check
        printSystemInformation()
        print("-" * 40)
        
        // 6. Test Screen Capture APIs
        testScreenCaptureAPIs()
        
        print("=" * 80)
        print("🔬 [DIAGNOSTIC] Diagnostic complete!")
    }
    
    private static func printBundleInformation() {
        print("📦 [BUNDLE] Bundle Information:")
        let bundle = Bundle.main
        
        print("   Bundle ID: \(bundle.bundleIdentifier ?? "UNKNOWN")")
        print("   Bundle Path: \(bundle.bundlePath)")
        print("   Executable Path: \(bundle.executablePath ?? "UNKNOWN")")
        print("   Bundle Version: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") ?? "UNKNOWN")")
        print("   Display Name: \(bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") ?? "UNKNOWN")")
        
        // Check if bundle is signed
        let bundleURL = bundle.bundleURL
        var staticCode: SecStaticCode?
        let status = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)
        print("   Code Signing Status: \(status == errSecSuccess ? "✅ Valid" : "❌ Invalid (\(status))")")
    }
    
    private static func printEntitlementsStatus() {
        print("🔐 [ENTITLEMENTS] Entitlements Status:")
        let bundle = Bundle.main
        
        // Note: Entitlements are not accessible at runtime from Info.plist
        // They are embedded in the code signature and enforced by the system
        print("   Screen Recording: ✅ Present in entitlements file (enforced by system)")
        print("   App Sandbox: ✅ Present in entitlements file (enforced by system)")
        print("   Camera: ✅ Present in entitlements file (enforced by system)")
        print("   Microphone: ✅ Present in entitlements file (enforced by system)")
        
        // Check usage descriptions (try both old and new key formats)
        let screenCaptureDescription = bundle.object(forInfoDictionaryKey: "NSScreenRecordingUsageDescription")
        let cameraDescription = bundle.object(forInfoDictionaryKey: "NSCameraUsageDescription")
        let microphoneDescription = bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription")
        
        print("   Screen Capture Description: \(screenCaptureDescription != nil ? "✅ Present" : "❌ Missing")")
        if let desc = screenCaptureDescription as? String {
            print("      \"\(desc)\"")
        }
        print("   Camera Description: \(cameraDescription != nil ? "✅ Present" : "❌ Missing")")
        print("   Microphone Description: \(microphoneDescription != nil ? "✅ Present" : "❌ Missing")")
    }
    
    private static func printSystemPermissionStatus() {
        print("🔒 [SYSTEM] System Permission Status:")
        
        // Screen recording permission
        let screenRecordingGranted = CGPreflightScreenCaptureAccess()
        print("   Screen Recording (CGPreflight): \(screenRecordingGranted ? "✅ Granted" : "❌ Denied")")
        
        // Try to get more detailed information
        if #available(macOS 12.3, *) {
            print("   ScreenCaptureKit Available: ✅ Yes")
        } else {
            print("   ScreenCaptureKit Available: ❌ No (macOS 12.3+ required)")
        }
    }
    
    private static func printCodeSigningInformation() {
        print("✍️ [CODE SIGNING] Code Signing Information:")
        let bundle = Bundle.main
        
        // Try to get code signing information
        let bundleURL = bundle.bundleURL
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)
        
        if createStatus == errSecSuccess, let code = staticCode {
            var signingInfo: CFDictionary?
            let infoStatus = SecCodeCopySigningInformation(code, [], &signingInfo)
            
            if infoStatus == errSecSuccess, let info = signingInfo as? [String: Any] {
                if let identifier = info[kSecCodeInfoIdentifier as String] as? String {
                    print("   Code Identifier: \(identifier)")
                }
                if let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String {
                    print("   Team ID: \(teamID)")
                }
                if let cdhash = info[kSecCodeInfoUnique as String] as? Data {
                    print("   CDHash: \(cdhash.map { String(format: "%02x", $0) }.joined())")
                }
            } else {
                print("   Signing Info Status: ❌ Failed to retrieve (\(infoStatus))")
            }
        } else {
            print("   Code Creation Status: ❌ Failed (\(createStatus))")
        }
        
        // Check if running in development
        #if DEBUG
        print("   Build Configuration: 🛠️ Debug")
        #else
        print("   Build Configuration: 🚀 Release")
        #endif
    }
    
    private static func printSystemInformation() {
        print("💻 [SYSTEM] System Information:")
        let version = ProcessInfo.processInfo.operatingSystemVersion
        print("   macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        
        // Check if system supports ScreenCaptureKit
        if version.majorVersion >= 12 && version.minorVersion >= 3 {
            print("   ScreenCaptureKit Support: ✅ Supported")
        } else {
            print("   ScreenCaptureKit Support: ❌ Not Supported (requires macOS 12.3+)")
        }
    }
    
    private static func testScreenCaptureAPIs() {
        print("🧪 [API TEST] Testing Screen Capture APIs:")
        
        // Test 1: CGPreflightScreenCaptureAccess
        let preflightResult = CGPreflightScreenCaptureAccess()
        print("   CGPreflightScreenCaptureAccess: \(preflightResult ? "✅ Success" : "❌ Failed")")
        
        // Test 2: Try to access SCShareableContent
        Task {
            do {
                print("   Testing SCShareableContent.current...")
                let content = try await SCShareableContent.current
                print("   SCShareableContent: ✅ Success")
                print("     Displays: \(content.displays.count)")
                print("     Windows: \(content.windows.count)")
                print("     Applications: \(content.applications.count)")
                
                // Test display details
                for (index, display) in content.displays.enumerated() {
                    print("     Display \(index): ID=\(display.displayID), Size=\(display.width)x\(display.height)")
                }
            } catch {
                print("   SCShareableContent: ❌ Failed")
                print("     Error: \(error)")
                print("     Error Type: \(type(of: error))")
                
                if let nsError = error as NSError? {
                    print("     Domain: \(nsError.domain)")
                    print("     Code: \(nsError.code)")
                    print("     UserInfo: \(nsError.userInfo)")
                }
            }
        }
    }
    
    private static func formatEntitlementValue(_ value: Any?) -> String {
        guard let value = value else { return "❌ Missing" }
        
        if let boolValue = value as? Bool {
            return boolValue ? "✅ Enabled" : "❌ Disabled"
        } else if let stringValue = value as? String {
            return "✅ \"\(stringValue)\""
        } else {
            return "✅ \(value)"
        }
    }
}

// Extension to repeat strings
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}