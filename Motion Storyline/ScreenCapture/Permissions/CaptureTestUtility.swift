import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

struct CaptureTestUtility {
    
    /// Performs a complete end-to-end test of the screen capture process
    static func performEndToEndTest() {
        print("🧪 [TEST] Starting end-to-end screen capture test...")
        print("=" * 60)
        
        Task {
            await testCompleteFlow()
        }
    }
    
    @MainActor
    private static func testCompleteFlow() async {
        let recorder = ScreenCaptureKitRecorder()
        
        // Step 1: Test permissions
        print("📋 [TEST] Step 1: Testing permissions...")
        
        await withCheckedContinuation { continuation in
            recorder.requestPermissionsIfNeeded { granted in
                print("📋 [TEST] Permission result: \(granted ? "✅ Granted" : "❌ Denied")")
                continuation.resume()
            }
        }
        
        // Step 2: Try to get shareable content directly
        print("📋 [TEST] Step 2: Testing SCShareableContent access...")
        
        do {
            let content = try await SCShareableContent.current
            print("📋 [TEST] ✅ SCShareableContent access successful")
            print("📋 [TEST] Available displays: \(content.displays.count)")
            print("📋 [TEST] Available windows: \(content.windows.count)")
            
            // Step 3: Test display configuration
            if let display = content.displays.first {
                print("📋 [TEST] Step 3: Testing display configuration...")
                print("📋 [TEST] Selected display: ID=\(display.displayID), Size=\(display.width)x\(display.height)")
                
                // Step 4: Test stream creation
                print("📋 [TEST] Step 4: Testing stream creation...")
                await testStreamCreation(with: display)
            } else {
                print("📋 [TEST] ❌ No displays available for testing")
            }
            
        } catch {
            print("📋 [TEST] ❌ SCShareableContent access failed: \(error)")
            print("📋 [TEST] Error details: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("📋 [TEST] Domain: \(nsError.domain), Code: \(nsError.code)")
            }
        }
        
        print("=" * 60)
        print("🧪 [TEST] End-to-end test complete!")
    }
    
    @MainActor
    private static func testStreamCreation(with display: SCDisplay) async {
        do {
            // Create filter and configuration
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = false
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
            config.width = min(display.width, 1920) // Limit to reasonable size
            config.height = min(display.height, 1080)
            config.scalesToFit = true
            config.showsCursor = true
            
            print("📋 [TEST] Stream config: \(config.width)x\(config.height)")
            
            // Create stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            print("📋 [TEST] ✅ Stream created successfully")
            
            // Try to add output (this is where permission issues often surface)
            let outputHandler = TestStreamOutput()
            try stream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: DispatchQueue(label: "test.capture.queue"))
            print("📋 [TEST] ✅ Stream output added successfully")
            
            // Test starting capture briefly
            print("📋 [TEST] Step 5: Testing capture start...")
            try await stream.startCapture()
            print("📋 [TEST] ✅ Capture started successfully")
            
            // Let it run for 2 seconds to verify frames are coming through
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            print("📋 [TEST] Frames received: \(outputHandler.frameCount)")
            
            // Stop capture
            try await stream.stopCapture()
            print("📋 [TEST] ✅ Capture stopped successfully")
            
        } catch {
            print("📋 [TEST] ❌ Stream creation/testing failed: \(error)")
            print("📋 [TEST] Error details: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("📋 [TEST] Domain: \(nsError.domain), Code: \(nsError.code)")
                print("📋 [TEST] UserInfo: \(nsError.userInfo)")
            }
        }
    }
    
    /// Simple test for checking system-level permissions without ScreenCaptureKit
    static func testBasicPermissions() {
        print("🔍 [BASIC TEST] Testing basic system permissions...")
        
        // Test CGPreflightScreenCaptureAccess
        let preflightResult = CGPreflightScreenCaptureAccess()
        print("🔍 [BASIC TEST] CGPreflightScreenCaptureAccess: \(preflightResult ? "✅ Granted" : "❌ Denied")")
        
        // Test requesting permission if not granted
        if !preflightResult {
            print("🔍 [BASIC TEST] Requesting permission...")
            let requestResult = CGRequestScreenCaptureAccess()
            print("🔍 [BASIC TEST] CGRequestScreenCaptureAccess: \(requestResult ? "✅ Granted" : "❌ Denied")")
            
            // Check again after request
            let postRequestResult = CGPreflightScreenCaptureAccess()
            print("🔍 [BASIC TEST] Post-request CGPreflightScreenCaptureAccess: \(postRequestResult ? "✅ Granted" : "❌ Denied")")
        }
        
        // Test bundle info
        let bundle = Bundle.main
        print("🔍 [BASIC TEST] Bundle ID: \(bundle.bundleIdentifier ?? "Unknown")")
        print("🔍 [BASIC TEST] Screen recording entitlement: \(bundle.object(forInfoDictionaryKey: "com.apple.security.device.screen-recording") ?? "Missing")")
        print("🔍 [BASIC TEST] Usage description: \(bundle.object(forInfoDictionaryKey: "NSScreenRecordingUsageDescription") ?? "Missing")")
    }
}

// Simple stream output handler for testing
class TestStreamOutput: NSObject, SCStreamOutput {
    private(set) var frameCount = 0
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        frameCount += 1
        
        if frameCount == 1 {
            print("📋 [TEST] ✅ First frame received!")
        } else if frameCount % 30 == 0 {
            print("📋 [TEST] Frame count: \(frameCount)")
        }
    }
}

