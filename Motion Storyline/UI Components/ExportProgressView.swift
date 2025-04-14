import SwiftUI
import AVFoundation

/// A view that manages the video export process and displays progress
public struct ExportProgressView: View {
    @StateObject private var exportManager = ExportManager()
    @State private var isExportCompleted = false
    @State private var exportResult: Result<URL, VideoExporter.ExportError>?
    
    let configuration: VideoExporter.ExportConfiguration
    let asset: AVAsset
    let onCompletion: ((Result<URL, VideoExporter.ExportError>) -> Void)?
    
    public init(
        configuration: VideoExporter.ExportConfiguration,
        asset: AVAsset,
        onCompletion: ((Result<URL, VideoExporter.ExportError>) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.asset = asset
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
                        Text("\(Int(exportManager.progress * 100))%")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                // Platform and format info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resolution: \(configuration.width) × \(configuration.height)")
                        if let profile = configuration.proResProfile {
                            Text("Format: ProRes \(profile.description)")
                        } else {
                            Text("Format: H.264 MP4")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Cancel button
                Button("Cancel") {
                    exportManager.cancelExport()
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
                                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                            }
                            .buttonStyle(.borderless)
                            
                            Button("Done") {
                                NSApp.stopModal()
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
                        
                        Button("Close") {
                            NSApp.stopModal()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            startExport()
        }
    }
    
    private func startExport() {
        Task {
            let result = await exportManager.export(
                with: configuration,
                asset: asset
            )
            
            DispatchQueue.main.async {
                self.exportResult = result
                self.isExportCompleted = true
                self.onCompletion?(result)
            }
        }
    }
}

/// A view model to manage export state and progress
@MainActor
public class ExportManager: ObservableObject, @unchecked Sendable {
    @Published public var progress: Float = 0.0
    private var exporter: VideoExporter?
    
    public init() {}
    
    public func export(
        with configuration: VideoExporter.ExportConfiguration,
        asset: AVAsset
    ) async -> Result<URL, VideoExporter.ExportError> {
        // Create the exporter
        let exporter = VideoExporter(asset: asset)
        self.exporter = exporter
        
        // Create a result continuation to bridge async callbacks
        return await withCheckedContinuation { continuation in
            Task {
                await exporter.export(with: configuration, progressHandler: { [weak self] newProgress in
                    // Update progress on the main thread
                    Task { @MainActor in
                        self?.progress = newProgress
                    }
                }, completion: { result in
                    continuation.resume(returning: result)
                })
            }
        }
    }
    
    public func cancelExport() {
        exporter?.cancelExport()
    }
}

#if !DISABLE_PREVIEWS
struct ExportProgressView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample configuration for preview
        let config = VideoExporter.ExportConfiguration(
            width: 1920,
            height: 1080,
            frameRate: 30.0,
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
    let config: VideoExporter.ExportConfiguration
    let asset: AVAsset
    @State private var isCompleted = false
    @State private var result: Result<URL, VideoExporter.ExportError>? = nil
    
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
                result = .success(URL(fileURLWithPath: "/tmp/my_export.mp4"))
            }
        }
        .environment(\._exportPreviewIsCompleted, isCompleted)
        .environment(\._exportPreviewResult, result)
    }
}

// Private environment values for preview
private struct ExportPreviewIsCompletedKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ExportPreviewResultKey: EnvironmentKey {
    static let defaultValue: Result<URL, VideoExporter.ExportError>? = nil
}

private extension EnvironmentValues {
    var _exportPreviewIsCompleted: Bool {
        get { self[ExportPreviewIsCompletedKey.self] }
        set { self[ExportPreviewIsCompletedKey.self] = newValue }
    }
    
    var _exportPreviewResult: Result<URL, VideoExporter.ExportError>? {
        get { self[ExportPreviewResultKey.self] }
        set { self[ExportPreviewResultKey.self] = newValue }
    }
}
#endif 