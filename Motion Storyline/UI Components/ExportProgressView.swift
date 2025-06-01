import SwiftUI
import AVFoundation
import os.log

/// A view that manages the video export process and displays progress
public struct ExportProgressView: View {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "ExportProgressView")
    
    @StateObject private var exportManager = ExportManager()
    @State private var isExportCompleted = false
    @State private var exportResult: Result<URL, Error>?
    @Environment(\.dismiss) private var dismiss
    
    // Use the new coordinator's configuration type
    let configuration: ExportCoordinator.ExportConfiguration
    let asset: AVAsset
    
    // Add these properties to access canvas elements and animation
    let animationController: AnimationController?
    let canvasElements: [CanvasElement]?
    let canvasSize: CGSize?
    
    let onCompletion: ((Result<URL, Error>) -> Void)?
    
    init(
        configuration: ExportCoordinator.ExportConfiguration,
        asset: AVAsset,
        animationController: AnimationController? = nil,
        canvasElements: [CanvasElement]? = nil,
        canvasSize: CGSize? = nil,
        onCompletion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.asset = asset
        self.animationController = animationController
        self.canvasElements = canvasElements
        self.canvasSize = canvasSize
        self.onCompletion = onCompletion
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if !isExportCompleted {
                // Progress display
                VStack(spacing: 8) {
                    ProgressView(value: exportManager.progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .animation(.easeInOut, value: exportManager.progress)
                    
                    HStack {
                        Text("Exporting...")
                            .foregroundColor(.secondary)
                        Spacer()
                        if exportManager.progress > 0 {
                            Text("\(Int(exportManager.progress * 100))%")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        } else {
                            Text("Starting...")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                }
                
                // Platform and format info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resolution: \(configuration.width) × \(configuration.height)")
                        if case .video = configuration.format, let profile = configuration.proResProfile {
                            Text("Format: ProRes \(profile.description)")
                        } else if case .video = configuration.format {
                            Text("Format: H.264 MP4")
                        } else if case .imageSequence(let format) = configuration.format {
                            Text("Format: \(format.rawValue.uppercased()) Image Sequence")
                        } else if case .gif = configuration.format {
                            Text("Format: Animated GIF")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Cancel button
                Button("Cancel") {
                    os_log("User cancelled export", log: ExportProgressView.logger, type: .info)
                    exportManager.cancelExport()
                    // Ensure we dismiss after cancelling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isExportCompleted = true
                        self.exportResult = .failure(NSError(domain: "ExportProgressView", code: 1, 
                                                            userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"]))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            } else if let result = exportResult {
                // Export completed view
                switch result {
                case .success(let url):
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 40))
                        
                        Text("Export Completed")
                            .font(.headline)
                        
                        Text("Saved to: \(url.lastPathComponent)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("Show in Finder") {
                                os_log("Opening exported file in Finder: %{public}@", log: ExportProgressView.logger, type: .info, url.path)
                                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Done") {
                                os_log("User dismissed export completion view", log: ExportProgressView.logger, type: .info)
                                dismiss()
                                if let onCompletion = onCompletion {
                                    onCompletion(result)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top)
                    }
                    
                case .failure(let error):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 40))
                        
                        Text("Export Failed")
                            .font(.headline)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack {
                            Button("Try Again") {
                                os_log("User requested to retry export", log: ExportProgressView.logger, type: .info)
                                // Reset state to retry export
                                isExportCompleted = false
                                exportResult = nil
                                exportManager.progress = 0.0
                                // Start the export again
                                startExport()
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Close") {
                                os_log("User dismissed export failure view", log: ExportProgressView.logger, type: .info)
                                dismiss()
                                if let onCompletion = onCompletion {
                                    onCompletion(result)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top)
                    }
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            os_log("ExportProgressView appeared with configuration: %{public}@, to %{public}@", log: ExportProgressView.logger, type: .info, String(describing: configuration.format), configuration.outputURL.path)
            startExport()
        }
    }
    
    private func startExport() {
        os_log("Starting export process", log: ExportProgressView.logger, type: .info)
        
        Task {
            do {
                // Verify the asset is ready for export
                if let tracks = try? await asset.loadTracks(withMediaType: .video), tracks.isEmpty {
                    os_log("No video tracks found in asset", log: ExportProgressView.logger, type: .error)
                    throw NSError(domain: "ExportProgressView", code: 2, 
                                  userInfo: [NSLocalizedDescriptionKey: "No video tracks found in asset"])
                }
                
                os_log("Beginning export operation", log: ExportProgressView.logger, type: .info)
                
                // Create coordinator with or without animation data
                let coordinator: ExportCoordinator
                
                if let animationController = animationController,
                   let canvasElements = canvasElements,
                   let canvasSize = canvasSize {
                    // Use the fully-configured coordinator with animation data
                    os_log("Creating ExportCoordinator with actual animation data", log: ExportProgressView.logger, type: .info)
                    coordinator = ExportCoordinator(
                        asset: asset,
                        animationController: animationController,
                        canvasElements: canvasElements,
                        canvasSize: canvasSize
                    )
                } else {
                    // Fallback to the basic coordinator
                    os_log("Creating basic ExportCoordinator without animation data", log: ExportProgressView.logger, type: .info)
                    coordinator = ExportCoordinator(asset: asset)
                }
                
                let url = try await coordinator.export(
                    with: configuration,
                    progressHandler: { [weak exportManager] progress in
                        DispatchQueue.main.async {
                            exportManager?.progress = progress
                        }
                    }
                )
                
                os_log("Export operation completed successfully", log: ExportProgressView.logger, type: .info)
                
                // Only update UI if not already completed (avoid race conditions)
                DispatchQueue.main.async {
                    if !self.isExportCompleted {
                        self.exportResult = .success(url)
                        self.isExportCompleted = true
                    }
                }
            } catch {
                os_log("Export process threw error: %{public}@", log: ExportProgressView.logger, type: .error, error.localizedDescription)
                
                // Only update UI if not already completed (avoid race conditions)
                DispatchQueue.main.async {
                    if !self.isExportCompleted {
                        self.exportResult = .failure(error)
                        self.isExportCompleted = true
                        self.onCompletion?(.failure(error))
                    }
                }
            }
        }
    }
}

/// A view model to manage export state and progress
@MainActor
public class ExportManager: ObservableObject {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "ExportManager")
    
    @Published public var progress: Float = 0.0
    private var cancellationFlag = false
    
    public init() {}
    
    public func cancelExport() {
        os_log("Export cancelled by user", log: ExportManager.logger, type: .info)
        cancellationFlag = true
    }
    
    public var isCancelled: Bool {
        return cancellationFlag
    }
}

#if !DISABLE_PREVIEWS
struct ExportProgressView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample configuration for preview
        let config = ExportCoordinator.ExportConfiguration(
            format: .video,
            width: 1920,
            height: 1080,
            frameRate: 30.0,
            numberOfFrames: 300,
            outputURL: URL(fileURLWithPath: "/tmp/preview_export.mp4")
        )
        
        // Create a blank asset for preview
        let asset = AVAsset(url: URL(fileURLWithPath: ""))
        
        ExportProgressView(
            configuration: config,
            asset: asset
        )
        
        // Also show a completed state preview
        VStack {
            Text("Success State Preview:").padding()
            
            // Using a separate view for completed state
            CompletedExportPreview(config: config, asset: asset)
        }
    }
}

// Helper view to show completed state in preview
private struct CompletedExportPreview: View {
    let config: ExportCoordinator.ExportConfiguration
    let asset: AVAsset
    @State private var isCompleted = false
    @State private var result: Result<URL, Error>? = nil
    
    var body: some View {
        ExportProgressView(
            configuration: config,
            asset: asset
        )
        .onAppear {
            // Simulate a completed export
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Simulate success state
                isCompleted = true
                result = .success(config.outputURL)
            }
        }
    }
}

// Private environment values for preview
private struct ExportPreviewIsCompletedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ExportPreviewResultKey: EnvironmentKey {
    static let defaultValue: Result<URL, Error>? = nil
}

private extension EnvironmentValues {
    var _exportPreviewIsCompleted: Bool {
        get { self[ExportPreviewIsCompletedKey.self] }
        set { self[ExportPreviewIsCompletedKey.self] = newValue }
    }
    
    var _exportPreviewResult: Result<URL, Error>? {
        get { self[ExportPreviewResultKey.self] }
        set { self[ExportPreviewResultKey.self] = newValue }
    }
}
#endif 