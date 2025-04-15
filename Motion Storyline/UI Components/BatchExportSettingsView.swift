import SwiftUI
import AVFoundation

/// A view that allows users to configure batch export settings for multiple formats
public struct BatchExportSettingsView: View {
    // MARK: - State
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var batchExportManager = BatchExportManager()
    
    @State private var videoExportEnabled = true
    @State private var gifExportEnabled = false
    @State private var pngSequenceExportEnabled = false
    @State private var jpegSequenceExportEnabled = false
    @State private var projectFileExportEnabled = true
    
    @State private var videoResolution = Resolution.hd1080p
    @State private var videoFrameRate: Float = 30.0
    @State private var videoUseProRes = true
    @State private var videoProResProfile = VideoExporter.ProResProfile.proRes422HQ
    
    @State private var gifResolution = Resolution.hd720p
    @State private var gifFrameRate: Float = 15.0
    
    @State private var imageSequenceResolution = Resolution.hd1080p
    @State private var imageSequenceFrameRate: Float = 30.0
    @State private var jpegQuality: CGFloat = 0.9
    
    @State private var duration: TimeInterval = 5.0
    @State private var showingBatchExportView = false
    
    // MARK: - Properties
    
    let onCreateComposition: (Int, Int, TimeInterval, Float) async throws -> AVAsset
    let onDismiss: () -> Void
    let projectName: String
    
    public init(
        projectName: String,
        onCreateComposition: @escaping (Int, Int, TimeInterval, Float) async throws -> AVAsset,
        onDismiss: @escaping () -> Void
    ) {
        self.projectName = projectName
        self.onCreateComposition = onCreateComposition
        self.onDismiss = onDismiss
    }
    
    // MARK: - View
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Batch Export Settings")
                .font(.headline)
            
            // Format selection
            GroupBox("Export Formats") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Video", isOn: $videoExportEnabled)
                    Toggle("GIF", isOn: $gifExportEnabled)
                    Toggle("PNG Sequence", isOn: $pngSequenceExportEnabled)
                    Toggle("JPEG Sequence", isOn: $jpegSequenceExportEnabled)
                    Toggle("Project File", isOn: $projectFileExportEnabled)
                }
                .padding(.vertical, 4)
            }
            
            // Shared settings
            GroupBox("General Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Animation Duration:")
                        Spacer()
                        Text("\(String(format: "%.1f", duration))s")
                            .foregroundColor(.secondary)
                        Slider(value: $duration, in: 1...60)
                            .frame(width: 150)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Video-specific settings (shown only if video is enabled)
            if videoExportEnabled {
                GroupBox("Video Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resolution:")
                            Spacer()
                            Picker("", selection: $videoResolution) {
                                ForEach(Resolution.allCases, id: \.self) { resolution in
                                    Text(resolution.displayName).tag(resolution)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        HStack {
                            Text("Frame Rate:")
                            Spacer()
                            Picker("", selection: $videoFrameRate) {
                                Text("24 fps").tag(Float(24.0))
                                Text("30 fps").tag(Float(30.0))
                                Text("60 fps").tag(Float(60.0))
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        Toggle("Use ProRes", isOn: $videoUseProRes)
                        
                        if videoUseProRes {
                            HStack {
                                Text("ProRes Profile:")
                                Spacer()
                                Picker("", selection: $videoProResProfile) {
                                    Text("ProRes 422").tag(VideoExporter.ProResProfile.proRes422)
                                    Text("ProRes 422 HQ").tag(VideoExporter.ProResProfile.proRes422HQ)
                                    Text("ProRes 422 LT").tag(VideoExporter.ProResProfile.proRes422LT)
                                    Text("ProRes 4444").tag(VideoExporter.ProResProfile.proRes4444)
                                }
                                .labelsHidden()
                                .frame(width: 150)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // GIF-specific settings (shown only if GIF is enabled)
            if gifExportEnabled {
                GroupBox("GIF Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resolution:")
                            Spacer()
                            Picker("", selection: $gifResolution) {
                                ForEach([Resolution.hd720p, Resolution.hd540p, Resolution.custom(width: 480, height: 360)], id: \.self) { resolution in
                                    Text(resolution.displayName).tag(resolution)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        HStack {
                            Text("Frame Rate:")
                            Spacer()
                            Picker("", selection: $gifFrameRate) {
                                Text("10 fps").tag(Float(10.0))
                                Text("15 fps").tag(Float(15.0))
                                Text("24 fps").tag(Float(24.0))
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Image sequence settings (shown if either PNG or JPEG is enabled)
            if pngSequenceExportEnabled || jpegSequenceExportEnabled {
                GroupBox("Image Sequence Settings") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resolution:")
                            Spacer()
                            Picker("", selection: $imageSequenceResolution) {
                                ForEach(Resolution.allCases, id: \.self) { resolution in
                                    Text(resolution.displayName).tag(resolution)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        HStack {
                            Text("Frame Rate:")
                            Spacer()
                            Picker("", selection: $imageSequenceFrameRate) {
                                Text("24 fps").tag(Float(24.0))
                                Text("30 fps").tag(Float(30.0))
                                Text("60 fps").tag(Float(60.0))
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        
                        if jpegSequenceExportEnabled {
                            HStack {
                                Text("JPEG Quality:")
                                Spacer()
                                Text("\(Int(jpegQuality * 100))%")
                                    .foregroundColor(.secondary)
                                Slider(value: $jpegQuality, in: 0.5...1.0)
                                    .frame(width: 150)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                
                Spacer()
                
                Button("Configure Export") {
                    Task {
                        await configureBatchExport()
                        showingBatchExportView = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!anyFormatEnabled)
            }
        }
        .padding()
        .frame(width: 500)
        .sheet(isPresented: $showingBatchExportView) {
            BatchExportView(manager: batchExportManager)
        }
    }
    
    // MARK: - Helper Properties
    
    private var anyFormatEnabled: Bool {
        videoExportEnabled || gifExportEnabled || pngSequenceExportEnabled || 
        jpegSequenceExportEnabled || projectFileExportEnabled
    }
    
    // MARK: - Methods
    
    /// Configures the batch export manager with the selected export jobs
    private func configureBatchExport() async {
        // Get the base document directory URL for exports
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // Create a timestamped export folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let exportFolderName = "\(projectName)_export_\(timestamp)"
        let exportFolderURL = documentsURL.appendingPathComponent(exportFolderName)
        
        // Create the folder if it doesn't exist
        try? FileManager.default.createDirectory(at: exportFolderURL, withIntermediateDirectories: true)
        
        // Set up the batchExportManager
        batchExportManager.clearAllJobs()
        
        // Create the composition asset using the provided callback
        do {
            // We'll use the highest resolution and frame rate for the source composition
            let maxResolution = Resolution.allCases.max(by: { $0.pixelCount < $1.pixelCount }) ?? Resolution.hd1080p
            let maxFrameRate = [videoFrameRate, gifFrameRate, imageSequenceFrameRate].max() ?? 30.0
            
            // Create the composition
            let composition = try await onCreateComposition(
                maxResolution.width,
                maxResolution.height,
                duration,
                maxFrameRate
            )
            
            // Set the asset in the batch export manager
            batchExportManager.setAsset(composition)
            
            // Configure video export if enabled
            if videoExportEnabled {
                let videoFileExtension = videoUseProRes ? "mov" : "mp4"
                let videoFileName = "\(projectName)_video.\(videoFileExtension)"
                let videoOutputURL = exportFolderURL.appendingPathComponent(videoFileName)
                
                let videoConfiguration = VideoExporter.ExportConfiguration(
                    format: .video,
                    width: videoResolution.width,
                    height: videoResolution.height,
                    frameRate: videoFrameRate,
                    proResProfile: videoUseProRes ? videoProResProfile : nil,
                    outputURL: videoOutputURL
                )
                
                batchExportManager.addJob(format: .video, configuration: videoConfiguration)
            }
            
            // Configure GIF export if enabled
            if gifExportEnabled {
                let gifFileName = "\(projectName)_animation.gif"
                let gifOutputURL = exportFolderURL.appendingPathComponent(gifFileName)
                
                let gifConfiguration = VideoExporter.ExportConfiguration(
                    format: .gif,
                    width: gifResolution.width,
                    height: gifResolution.height,
                    frameRate: gifFrameRate,
                    outputURL: gifOutputURL
                )
                
                batchExportManager.addJob(format: .gif, configuration: gifConfiguration)
            }
            
            // Configure PNG sequence export if enabled
            if pngSequenceExportEnabled {
                let pngSequenceFolderName = "\(projectName)_png_sequence"
                let pngSequenceFolderURL = exportFolderURL.appendingPathComponent(pngSequenceFolderName)
                
                let pngConfiguration = VideoExporter.ExportConfiguration(
                    format: .imageSequence(.png),
                    width: imageSequenceResolution.width,
                    height: imageSequenceResolution.height,
                    frameRate: imageSequenceFrameRate,
                    outputURL: pngSequenceFolderURL,
                    baseFilename: projectName
                )
                
                batchExportManager.addJob(format: .imageSequence(.png), configuration: pngConfiguration)
            }
            
            // Configure JPEG sequence export if enabled
            if jpegSequenceExportEnabled {
                let jpegSequenceFolderName = "\(projectName)_jpeg_sequence"
                let jpegSequenceFolderURL = exportFolderURL.appendingPathComponent(jpegSequenceFolderName)
                
                let jpegConfiguration = VideoExporter.ExportConfiguration(
                    format: .imageSequence(.jpeg),
                    width: imageSequenceResolution.width,
                    height: imageSequenceResolution.height,
                    frameRate: imageSequenceFrameRate,
                    outputURL: jpegSequenceFolderURL,
                    baseFilename: projectName,
                    imageQuality: jpegQuality
                )
                
                batchExportManager.addJob(format: .imageSequence(.jpeg), configuration: jpegConfiguration)
            }
            
            // Configure project file export if enabled
            if projectFileExportEnabled {
                let projectFileName = "\(projectName).msproj"
                let projectFileURL = exportFolderURL.appendingPathComponent(projectFileName)
                
                // Project file export doesn't use the same configuration as media exports,
                // but we'll create a placeholder configuration to track it in the batch UI
                let projectConfiguration = VideoExporter.ExportConfiguration(
                    format: .projectFile,
                    width: 0,
                    height: 0,
                    frameRate: 0,
                    outputURL: projectFileURL
                )
                
                batchExportManager.addJob(format: .projectFile, configuration: projectConfiguration)
            }
            
            // After configuration is complete, show the batch export manager sheet
            // but don't start processing yet (that happens when user clicks "Start Export" in the batch UI)
        } catch {
            print("Error creating composition: \(error.localizedDescription)")
        }
    }
}

// MARK: - Resolution Enum

/// Represents common video resolutions
public enum Resolution: Hashable, CaseIterable {
    case hd540p
    case hd720p
    case hd1080p
    case uhd4K
    case custom(width: Int, height: Int)
    
    public var width: Int {
        switch self {
        case .hd540p: return 960
        case .hd720p: return 1280
        case .hd1080p: return 1920
        case .uhd4K: return 3840
        case .custom(let width, _): return width
        }
    }
    
    public var height: Int {
        switch self {
        case .hd540p: return 540
        case .hd720p: return 720
        case .hd1080p: return 1080
        case .uhd4K: return 2160
        case .custom(_, let height): return height
        }
    }
    
    public var pixelCount: Int {
        return width * height
    }
    
    public var displayName: String {
        switch self {
        case .hd540p: return "960x540 (540p)"
        case .hd720p: return "1280x720 (720p)"
        case .hd1080p: return "1920x1080 (1080p)"
        case .uhd4K: return "3840x2160 (4K)"
        case .custom(let width, let height): return "\(width)x\(height) (Custom)"
        }
    }
    
    public static var allCases: [Resolution] {
        [.hd540p, .hd720p, .hd1080p, .uhd4K]
    }
}

// MARK: - Preview

#if !DISABLE_PREVIEWS
struct BatchExportSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        BatchExportSettingsView(
            projectName: "Example Project",
            onCreateComposition: { width, height, duration, frameRate in
                // Return an empty asset for preview purposes
                return AVAsset()
            },
            onDismiss: {}
        )
    }
}
#endif 