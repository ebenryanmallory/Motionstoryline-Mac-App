import SwiftUI
import CoreGraphics
import AppKit

struct ScreenRecordingView: View {
    @Binding var isPresented: Bool
    var includeMicrophone: Bool = true
    var countdown: Bool = true
    @StateObject private var recorder = ScreenRecorderManager()
    @State private var isAuthorized: Bool = true
    @State private var isStarting: Bool = false
    @State private var hasCheckedPermissions: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold))
                }
                Spacer()
                if recorder.isRecording { Text("Recording…") }
                Spacer()
                Button(action: {}) { Image(systemName: "gear") }
            }
            .padding()

            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8))
                VStack(spacing: 16) {
                    if isAuthorized {
                        Text("Screen Recording Preview").foregroundColor(.white)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 32))
                                .foregroundColor(.yellow)
                            Text("Screen Recording Permission Required")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("To record your screen, enable screen recording permissions in System Settings > Privacy & Security > Screen Recording, then restart the app.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Open System Settings") {
                                ScreenCapturePermissionsHelper.openSystemSettingsPrivacyScreenRecording()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .frame(minWidth: 640, minHeight: 360)
            .padding()

            HStack(spacing: 20) {
                Spacer()
                if !isAuthorized && hasCheckedPermissions {
                    Button("Check Permissions") {
                        checkPermissions()
                    }
                    .buttonStyle(.bordered)
                }
                Button(recorder.isRecording ? "Stop" : (isStarting ? "Starting…" : "Record")) {
                    if recorder.isRecording { stopRecording() } else { startRecording() }
                }
                .disabled(isStarting == true || (!isAuthorized && hasCheckedPermissions))
                Spacer()
            }
            .padding(.vertical, 24)
        }
        .frame(width: 720, height: 520)
        .onAppear {
            checkPermissions()
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }

    private func checkPermissions() {
        recorder.requestPermissions { granted in
            isAuthorized = granted
            hasCheckedPermissions = true
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            if hasCheckedPermissions && !isAuthorized {
                checkPermissions()
            }
        }
    }

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    private func startRecording() {
        isStarting = true
        recorder.requestPermissions { granted in
            isAuthorized = granted
            guard granted else { isStarting = false; return }
            let options = ScreenCaptureOptions(
                source: .display(id: CGMainDisplayID()),
                includeMicrophone: includeMicrophone
            )
            recorder.start(options: options) { _ in
                isStarting = false
            }
        }
    }

    private func stopRecording() {
        recorder.stop { result in
            switch result {
            case .success(let url):
                NotificationCenter.default.post(name: Notification.Name("NewScreenRecordingAvailable"), object: nil, userInfo: ["url": url])
            case .failure:
                break
            }
        }
    }
}

