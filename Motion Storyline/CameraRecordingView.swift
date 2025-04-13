import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isAuthorized = false
    @Published var error: Error?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var timer: Timer?
    private var outputURL: URL?
    private var isConfigured = false
    private var isSettingUp = false
    
    override init() {
        super.init()
        
        // Don't automatically check permissions or setup capture session
        // We'll do this explicitly when the view appears
    }
    
    func configure() {
        // Only configure once and only if authorized
        guard !isConfigured && isAuthorized && !isSettingUp else { return }
        isConfigured = true
        isSettingUp = true
        
        // Setup capture session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    func checkPermissions() {
        // This is now handled by the view directly
    }
    
    func setupCaptureSession() {
        // Make sure we're on a background thread for setting up the capture session
        guard Thread.isMainThread == false else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.setupCaptureSession()
            }
            return
        }
        
        // Double-check authorization status before proceeding
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            DispatchQueue.main.async { [weak self] in
                self?.isAuthorized = false
                self?.error = NSError(
                    domain: "CameraManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Camera access not authorized"]
                )
                self?.isSettingUp = false
            }
            return
        }
        
        // Create a new capture session
        let session = AVCaptureSession()
        
        // Configure the session to prevent crashes
        session.beginConfiguration()
        
        // Use a lower quality preset to start with
        session.sessionPreset = .medium
        
        // Try to get the front camera first
        var videoDevice: AVCaptureDevice?
        
        do {
            // Safely try to get the built-in camera on Mac
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                videoDevice = frontCamera
                print("Found front-facing Mac camera")
            } else if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                videoDevice = backCamera
                print("Found rear-facing Mac camera")
            } else if let defaultCamera = AVCaptureDevice.default(for: .video) {
                videoDevice = defaultCamera
                print("Found default Mac camera")
            } else {
                print("No camera found on this Mac")
            }
            
            // Check if we found a camera
            guard let videoDevice = videoDevice else {
                throw NSError(
                    domain: "CameraManager",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No camera available on this Mac"]
                )
            }
            
            // Add video input
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("Added video input")
            } else {
                throw NSError(
                    domain: "CameraManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not add video input"]
                )
            }
            
            // Add audio input if authorized
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                if let audioDevice = AVCaptureDevice.default(for: .audio) {
                    do {
                        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                        if session.canAddInput(audioInput) {
                            session.addInput(audioInput)
                            print("Added audio input")
                        }
                    } catch {
                        print("Could not add audio input: \(error)")
                        // Continue without audio if it fails
                    }
                }
            }
            
            // Add video output
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                self.videoOutput = movieOutput
                print("Added video output")
            } else {
                throw NSError(
                    domain: "CameraManager",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Could not add video output"]
                )
            }
            
            // Commit the configuration
            session.commitConfiguration()
            print("Committed configuration")
            
            // Create preview layer
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            print("Created preview layer")
            
            // Update UI on main thread
            DispatchQueue.main.async { [weak self] in
                self?.previewLayer = previewLayer
                self?.captureSession = session
                print("Set preview layer and capture session")
                
                // Start the session on a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    print("Starting capture session")
                    session.startRunning()
                    
                    DispatchQueue.main.async {
                        self?.isSettingUp = false
                        print("Camera setup complete")
                    }
                }
            }
        } catch {
            // Handle any errors
            session.commitConfiguration()
            print("Camera setup error: \(error.localizedDescription)")
            
            DispatchQueue.main.async { [weak self] in
                self?.error = error
                self?.isSettingUp = false
            }
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput, !isRecording else { return }
        
        // Create a temporary file URL for the recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).mov"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Start recording
        videoOutput.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        outputURL = fileURL
        
        // Start timer to track recording duration
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.recordingTime += 0.1
        }
    }
    
    func stopRecording() {
        guard let videoOutput = videoOutput, isRecording else { return }
        
        videoOutput.stopRecording()
        timer?.invalidate()
        timer = nil
    }
    
    func cleanup() {
        // Stop recording if in progress
        if isRecording {
            stopRecording()
        }
        
        // Reset recording state
        isRecording = false
        recordingTime = 0
        
        // Clean up timer
        timer?.invalidate()
        timer = nil
        
        // Clear the preview layer on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer = nil
        }
        
        // Stop the capture session on a background thread
        if let captureSession = captureSession, captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak captureSession] in
                // Begin configuration to safely remove inputs and outputs
                captureSession?.beginConfiguration()
                
                // Remove all inputs
                for input in captureSession?.inputs ?? [] {
                    captureSession?.removeInput(input)
                }
                
                // Remove all outputs
                for output in captureSession?.outputs ?? [] {
                    captureSession?.removeOutput(output)
                }
                
                // Commit configuration
                captureSession?.commitConfiguration()
                
                // Stop running
                captureSession?.stopRunning()
            }
        }
        
        // Reset state
        captureSession = nil
        videoOutput = nil
        isConfigured = false
        
        // Clear any errors
        error = nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Recording started
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Recording finished
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTime = 0
            
            if let error = error {
                self.error = error
                return
            }
            
            // Handle the recorded video file
            self.handleRecordedVideo(at: outputFileURL)
        }
    }
    
    private func handleRecordedVideo(at url: URL) {
        // Here you would typically save the video to a more permanent location,
        // add it to the project, or provide options to share it
        
        // Create a notification to inform the app about the new recording
        let notificationCenter = NotificationCenter.default
        
        // First, copy the file to the app's documents directory for persistence
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projectsDirectory = documentsDirectory.appendingPathComponent("Projects")
        
        // Create the projects directory if it doesn't exist
        if !fileManager.fileExists(atPath: projectsDirectory.path) {
            try? fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
        }
        
        // Create a unique filename with timestamp
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ",", with: "")
        
        let destinationFilename = "Camera Recording - \(timestamp).mov"
        let destinationURL = projectsDirectory.appendingPathComponent(destinationFilename)
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            
            // Post notification with the URL of the saved recording
            notificationCenter.post(
                name: Notification.Name("NewCameraRecordingAvailable"),
                object: nil,
                userInfo: ["url": destinationURL, "filename": destinationFilename]
            )
            
            print("Recording saved to: \(destinationURL.path)")
        } catch {
            self.error = error
            print("Error saving recording: \(error.localizedDescription)")
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = CALayer() // Ensure there's a base layer
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = previewLayer else {
            // If no preview layer, ensure we have a clean base layer
            if nsView.layer == nil {
                nsView.wantsLayer = true
                nsView.layer = CALayer()
            }
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Update the frame
        previewLayer.frame = nsView.bounds
        
        // Only replace the layer if needed
        if nsView.layer != previewLayer {
            // First ensure the view wants a layer
            nsView.wantsLayer = true
            
            // Then safely assign the preview layer
            nsView.layer = previewLayer
        }
        
        CATransaction.commit()
    }
}

struct CameraRecordingView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingSettings = false
    @State private var isFullScreen = false
    @Binding var isPresented: Bool
    @State private var isViewReady = false
    @State private var permissionChecked = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { 
                    // Clean up before dismissing
                    cameraManager.cleanup()
                    isPresented = false 
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                if cameraManager.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(formatTime(cameraManager.recordingTime))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)
                }
                
                Spacer()
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(Color.clear)
            
            // Camera preview
            ZStack {
                if !permissionChecked {
                    Text("Checking camera permissions...")
                        .foregroundColor(.white)
                } else if !cameraManager.isAuthorized {
                    VStack {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .padding()
                        
                        Text("Camera access is required")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if cameraManager.error != nil {
                            Text(cameraManager.error!.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                        
                        Button("Open Settings") {
                            if let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                                NSWorkspace.shared.open(settingsURL)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                } else if !isViewReady {
                    Text("Initializing camera...")
                        .foregroundColor(.white)
                } else if let previewLayer = cameraManager.previewLayer {
                    CameraPreviewView(previewLayer: previewLayer)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    Text("Setting up camera...")
                        .foregroundColor(.white)
                }
                
                // Error message if any
                if let error = cameraManager.error, cameraManager.isAuthorized {
                    Text(error.localizedDescription)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 20) {
                Spacer()
                
                // Toggle fullscreen
                Button(action: { isFullScreen.toggle() }) {
                    Image(systemName: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                
                // Record button
                Button(action: {
                    if cameraManager.isRecording {
                        cameraManager.stopRecording()
                    } else {
                        cameraManager.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 64, height: 64)
                        
                        if cameraManager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .disabled(!cameraManager.isAuthorized || !isViewReady)
                
                // Microphone toggle (placeholder)
                Button(action: {}) {
                    Image(systemName: "mic")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .disabled(!cameraManager.isAuthorized || !isViewReady)
                
                Spacer()
            }
            .padding(.vertical, 24)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: isFullScreen ? nil : 480, height: isFullScreen ? nil : 360)
        .background(Color.black)
        .cornerRadius(isFullScreen ? 0 : 16)
        .onAppear {
            // First check permissions without setting up the camera
            checkPermissionsOnly()
        }
        .onDisappear {
            cameraManager.cleanup()
        }
        .sheet(isPresented: $showingSettings) {
            CameraSettingsView()
                .frame(width: 300, height: 200)
        }
    }
    
    private func checkPermissionsOnly() {
        // Check camera permissions without setting up the camera
        DispatchQueue.main.async {
            // First check if camera is available on this device
            let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .unspecified
            )
            
            guard !discoverySession.devices.isEmpty else {
                // No camera available on this device
                permissionChecked = true
                cameraManager.isAuthorized = false
                cameraManager.error = NSError(
                    domain: "CameraManager",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No camera available on this device."]
                )
                return
            }
            
            // Now check authorization status
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraManager.isAuthorized = true
                permissionChecked = true
                // Only now that we know we have permission, proceed with camera setup
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isViewReady = true
                    cameraManager.configure()
                }
            case .notDetermined:
                // Request permission
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraManager.isAuthorized = granted
                        permissionChecked = true
                        if granted {
                            // Only set up camera if permission granted
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isViewReady = true
                                cameraManager.configure()
                            }
                        }
                    }
                }
            case .denied, .restricted:
                cameraManager.isAuthorized = false
                permissionChecked = true
                cameraManager.error = NSError(
                    domain: "CameraManager",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Camera access denied. Please enable it in System Settings > Privacy & Security > Camera."]
                )
            @unknown default:
                cameraManager.isAuthorized = false
                permissionChecked = true
                cameraManager.error = NSError(
                    domain: "CameraManager",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown camera authorization status."]
                )
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let milliseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

struct CameraSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Camera Settings")
                .font(.headline)
            
            Divider()
            
            // Camera selection (placeholder)
            Picker("Camera", selection: .constant(0)) {
                Text("FaceTime HD Camera").tag(0)
            }
            .pickerStyle(.menu)
            
            // Resolution selection (placeholder)
            Picker("Resolution", selection: .constant(0)) {
                Text("720p").tag(0)
                Text("1080p").tag(1)
            }
            .pickerStyle(.menu)
            
            Spacer()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Preview
struct CameraRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        CameraRecordingView(isPresented: .constant(true))
            .frame(width: 480, height: 360)
    }
} 