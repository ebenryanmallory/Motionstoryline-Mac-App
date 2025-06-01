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