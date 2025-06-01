import SwiftUI
import AVFoundation

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

// Preview
struct CameraRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        CameraRecordingView(isPresented: .constant(true))
            .frame(width: 480, height: 360)
    }
} 