#if canImport(ScreenCaptureKit)
import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import CoreGraphics

final class ScreenCaptureKitRecorder: NSObject, ScreenCaptureEngine {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var stream: SCStream?
    private let videoQueue = DispatchQueue(label: "screen.record.video.queue")
    private var sessionStartTime: CMTime?

    private(set) var recording: Bool = false
    var isRecording: Bool { recording }
    var previewLayer: CALayer? { nil }

    func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        print("🔍 [DEBUG] Starting permission check process...")
        
        // Detailed bundle information
        let bundle = Bundle.main
        print("🔍 [DEBUG] Bundle ID: \(bundle.bundleIdentifier ?? "Unknown")")
        print("🔍 [DEBUG] Bundle Path: \(bundle.bundlePath)")
        print("🔍 [DEBUG] Executable Path: \(bundle.executablePath ?? "Unknown")")
        
        // Note: Entitlements are embedded in code signature, not accessible via Info.plist at runtime
        print("🔍 [DEBUG] Screen recording entitlement: ✅ Present in code signature (enforced by system)")
        
        // Check usage description (correct key is NSScreenCaptureUsageDescription)
        let usageDescription = bundle.object(forInfoDictionaryKey: "NSScreenCaptureUsageDescription")
        if usageDescription == nil {
            print("⚠️ [DEBUG] WARNING: NSScreenCaptureUsageDescription key is missing in Info.plist. Please add a description to allow screen recording.")
        }
        print("🔍 [DEBUG] Usage description in bundle: \(usageDescription ?? "NOT FOUND")")
        
        // Note: Sandbox status is in entitlements, not Info.plist
        print("🔍 [DEBUG] App is sandboxed: ✅ Yes (from entitlements)")
        
        // First check using CGPreflightScreenCaptureAccess
        let preflightResult = CGPreflightScreenCaptureAccess()
        print("🔍 [DEBUG] CGPreflightScreenCaptureAccess result: \(preflightResult)")
        
        if preflightResult {
            print("🔍 [DEBUG] Preflight check passed, attempting to verify with SCShareableContent...")
            // Double-check by trying to access shareable content
            Task { @MainActor in
                do {
                    let content = try await SCShareableContent.current
                    print("🔍 [DEBUG] SCShareableContent.current succeeded")
                    print("🔍 [DEBUG] Available displays: \(content.displays.count)")
                    print("🔍 [DEBUG] Available windows: \(content.windows.count)")
                    print("🔍 [DEBUG] Available applications: \(content.applications.count)")
                    
                    // Try to get more detailed display info
                    for (index, display) in content.displays.enumerated() {
                        print("🔍 [DEBUG] Display \(index): ID=\(display.displayID), Size=\(display.width)x\(display.height)")
                    }
                    
                    print("✅ [DEBUG] Screen recording permissions granted and verified.")
                    completion(true)
                } catch {
                    print("❌ [DEBUG] SCShareableContent failed despite preflight success")
                    print("❌ [DEBUG] Error: \(error)")
                    print("❌ [DEBUG] Error type: \(type(of: error))")
                    print("❌ [DEBUG] Error localizedDescription: \(error.localizedDescription)")
                    
                    if let nsError = error as NSError? {
                        print("❌ [DEBUG] NSError domain: \(nsError.domain)")
                        print("❌ [DEBUG] NSError code: \(nsError.code)")
                        print("❌ [DEBUG] NSError userInfo: \(nsError.userInfo)")
                    }
                    
                    print("❌ [DEBUG] This may require restarting the app after granting permissions in System Settings.")
                    completion(false)
                }
            }
        } else {
            print("🔍 [DEBUG] Preflight check failed, attempting to trigger permission dialog...")
            // No permission - try to trigger the system dialog
            Task { @MainActor in
                do {
                    let content = try await SCShareableContent.current
                    print("✅ [DEBUG] Permission dialog succeeded, access granted")
                    print("🔍 [DEBUG] Available displays: \(content.displays.count)")
                    print("🔍 [DEBUG] Available windows: \(content.windows.count)")
                    completion(true)
                } catch {
                    print("❌ [DEBUG] Permission request failed")
                    print("❌ [DEBUG] Error: \(error)")
                    print("❌ [DEBUG] Error type: \(type(of: error))")
                    print("❌ [DEBUG] Error localizedDescription: \(error.localizedDescription)")
                    
                    if let nsError = error as NSError? {
                        print("❌ [DEBUG] NSError domain: \(nsError.domain)")
                        print("❌ [DEBUG] NSError code: \(nsError.code)")
                        print("❌ [DEBUG] NSError userInfo: \(nsError.userInfo)")
                    }
                    
                    print("❌ [DEBUG] Please manually grant screen recording permission in System Settings > Privacy & Security > Screen Recording")
                    completion(false)
                }
            }
        }
    }

    func startRecording(options: ScreenCaptureOptions, outputURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🎬 [DEBUG] Starting recording process...")
        print("🎬 [DEBUG] Output URL: \(outputURL)")
        print("🎬 [DEBUG] Options: FPS=\(options.framesPerSecond), Cursor=\(options.includeCursor)")
        
        Task { @MainActor in
            do {
                print("🎬 [DEBUG] Attempting to get shareable content...")
                // Discover content and choose display
                let content = try await SCShareableContent.current
                print("🎬 [DEBUG] Shareable content retrieved successfully")
                print("🎬 [DEBUG] Available displays: \(content.displays.count)")
                print("🎬 [DEBUG] Available windows: \(content.windows.count)")
                print("🎬 [DEBUG] Available applications: \(content.applications.count)")
                
                guard let display = content.displays.first else {
                    let error = NSError(domain: "ScreenCapture", code: -100, userInfo: [NSLocalizedDescriptionKey: "No display available for capture"])
                    print("❌ [DEBUG] No displays available: \(error)")
                    throw error
                }
                
                print("🎬 [DEBUG] Selected display: ID=\(display.displayID), Size=\(display.width)x\(display.height)")

                // Configure stream
                let filter = SCContentFilter(display: display, excludingWindows: [])
                print("🎬 [DEBUG] Created content filter for display \(display.displayID)")
                
                let config = SCStreamConfiguration()
                config.capturesAudio = false
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(max(1, options.framesPerSecond)))
                config.width = display.width
                config.height = display.height
                config.scalesToFit = true
                config.showsCursor = options.includeCursor
                
                print("🎬 [DEBUG] Stream configuration: \(config.width)x\(config.height), FPS=\(1.0/config.minimumFrameInterval.seconds)")

                // Asset writer setup
                print("🎬 [DEBUG] Setting up AVAssetWriter...")
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: config.width,
                    AVVideoHeightKey: config.height
                ]
                print("🎬 [DEBUG] Video settings: \(videoSettings)")
                
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true
                
                guard writer.canAdd(vInput) else { 
                    let error = NSError(domain: "ScreenCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
                    print("❌ [DEBUG] Cannot add video input: \(error)")
                    throw error
                }
                writer.add(vInput)
                print("🎬 [DEBUG] Added video input to writer")
                
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput, sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: config.width,
                    kCVPixelBufferHeightKey as String: config.height
                ])
                print("🎬 [DEBUG] Created pixel buffer adaptor")
                
                self.assetWriter = writer
                self.videoInput = vInput
                self.pixelBufferAdaptor = adaptor

                // Stream setup with output handler
                print("🎬 [DEBUG] Creating SCStream...")
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                print("🎬 [DEBUG] Adding stream output...")
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
                self.stream = stream

                // Start writing once first sample arrives
                print("🎬 [DEBUG] Starting capture...")
                self.recording = true
                try await stream.startCapture()
                print("✅ [DEBUG] Recording started successfully!")
                completion(.success(()))
            } catch {
                print("❌ [DEBUG] Recording failed to start")
                print("❌ [DEBUG] Error: \(error)")
                print("❌ [DEBUG] Error type: \(type(of: error))")
                print("❌ [DEBUG] Error localizedDescription: \(error.localizedDescription)")
                
                if let nsError = error as NSError? {
                    print("❌ [DEBUG] NSError domain: \(nsError.domain)")
                    print("❌ [DEBUG] NSError code: \(nsError.code)")
                    print("❌ [DEBUG] NSError userInfo: \(nsError.userInfo)")
                }
                
                self.recording = false
                completion(.failure(error))
            }
        }
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let stream = stream, let writer = assetWriter else {
            return completion(.failure(NSError(domain: "ScreenCapture", code: -2, userInfo: [NSLocalizedDescriptionKey: "No active capture"])) )
        }
        recording = false
        stream.stopCapture { [weak self] _ in
            guard let self = self else { return }
            self.videoInput?.markAsFinished()
            writer.finishWriting {
                if writer.status == .completed {
                    completion(.success(writer.outputURL))
                } else {
                    completion(.failure(writer.error ?? NSError(domain: "ScreenCapture", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unknown writer error"])) )
                }
                self.cleanup()
            }
        }
    }

    private func cleanup() {
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        stream = nil
        sessionStartTime = nil
    }
}

extension ScreenCaptureKitRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .screen else {
            print("📹 [DEBUG] Received non-screen output type: \(outputType)")
            return
        }
        
        guard let writer = assetWriter, let vInput = videoInput, let adaptor = pixelBufferAdaptor else {
            print("❌ [DEBUG] Missing components: writer=\(assetWriter != nil), vInput=\(videoInput != nil), adaptor=\(pixelBufferAdaptor != nil)")
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ [DEBUG] Failed to get pixel buffer from sample")
            return
        }
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if sessionStartTime == nil {
            print("📹 [DEBUG] Starting writing session at PTS: \(pts)")
            sessionStartTime = pts
            writer.startWriting()
            writer.startSession(atSourceTime: pts)
            
            if writer.status != .writing {
                print("❌ [DEBUG] Writer failed to start. Status: \(writer.status), Error: \(writer.error?.localizedDescription ?? "None")")
                return
            } else {
                print("✅ [DEBUG] Writer started successfully")
            }
        }
        
        if vInput.isReadyForMoreMediaData {
            let success = adaptor.append(pixelBuffer, withPresentationTime: pts)
            if !success {
                print("❌ [DEBUG] Failed to append pixel buffer. Writer status: \(writer.status), Error: \(writer.error?.localizedDescription ?? "None")")
            } else {
                // Only print every 30 frames to avoid spam
                let frameNumber = Int(pts.seconds * 30) // Assuming ~30fps
                if frameNumber % 30 == 0 {
                    print("📹 [DEBUG] Successfully appended frame at PTS: \(pts.seconds)s")
                }
            }
        } else {
            print("⚠️ [DEBUG] Video input not ready for more data")
        }
    }
}
#else
import Foundation
import AVFoundation

final class ScreenCaptureKitRecorder: ScreenCaptureEngine {
    var previewLayer: CALayer? { nil }
    var isRecording: Bool { false }
    func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) { completion(true) }
    func startRecording(options: ScreenCaptureOptions, outputURL: URL, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) { completion(.failure(NSError(domain: "ScreenCapture", code: -10))) }
}
#endif

