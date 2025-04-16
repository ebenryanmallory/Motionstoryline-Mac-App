import SwiftUI
import AVFoundation
import os.log // Add os framework for logging

/// A modal view that provides export options and controls for various export formats
struct ExportModal: View {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "ExportModal")
    
    // The AVAsset to be exported
    let asset: AVAsset
    
    // Canvas dimensions for default sizing
    let canvasWidth: Int
    let canvasHeight: Int
    
    // Callback for when the modal is dismissed
    let onDismiss: () -> Void
    
    // State for export configuration
    @State private var selectedFormat: ExportFormat = .video
    @State private var selectedProResProfile: VideoExporter.ProResProfile? = nil
    @State private var selectedImageFormat: ImageFormat = .png
    @State private var exportWidth: String
    @State private var exportHeight: String
    @State private var frameRate: String = "30"
    @State private var includeAudio: Bool = true
    @State private var jpegQuality: Double = 0.9
    
    // State for export progress
    @State private var isExporting = false
    @State private var exportConfiguration: ExportCoordinator.ExportConfiguration?
    
    init(asset: AVAsset, canvasWidth: Int, canvasHeight: Int, onDismiss: @escaping () -> Void) {
        self.asset = asset
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.onDismiss = onDismiss
        
        // Initialize dimensions with the canvas size
        _exportWidth = State(initialValue: String(canvasWidth))
        _exportHeight = State(initialValue: String(canvasHeight))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with title and close button
            HStack {
                Text("Export Project")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Format selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Export Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Format", selection: $selectedFormat) {
                    Text("MP4 Video").tag(ExportFormat.video)
                    Text("Animated GIF").tag(ExportFormat.gif)
                    Text("Image Sequence").tag(ExportFormat.imageSequence(.png))
                    // Disabled unsupported formats
                    // Text("Project File").tag(ExportFormat.projectFile)
                }
                .pickerStyle(.segmented)
            }
            
            // Format-specific options
            VStack(alignment: .leading, spacing: 16) {
                // Resolution settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolution")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("Width", text: $exportWidth)
                            .frame(width: 80)
                        Text("×")
                        TextField("Height", text: $exportHeight)
                            .frame(width: 80)
                        
                        Spacer()
                        
                        // Add some preset buttons
                        Button("HD") {
                            exportWidth = "1280"
                            exportHeight = "720"
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Full HD") {
                            exportWidth = "1920"
                            exportHeight = "1080"
                        }
                        .buttonStyle(.borderless)
                        
                        Button("4K") {
                            exportWidth = "3840"
                            exportHeight = "2160"
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                // Frame rate settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frame Rate")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("FPS", text: $frameRate)
                            .frame(width: 80)
                        Text("fps")
                        
                        Spacer()
                        
                        // Add some preset FPS buttons
                        Button("24") {
                            frameRate = "24"
                        }
                        .buttonStyle(.borderless)
                        
                        Button("30") {
                            frameRate = "30"
                        }
                        .buttonStyle(.borderless)
                        
                        Button("60") {
                            frameRate = "60"
                        }
                        .buttonStyle(.borderless)
                    }
                }
                
                // Format-specific settings
                switch selectedFormat {
                case .video:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Video Format")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Video Format", selection: $selectedProResProfile) {
                            Text("Standard MP4").tag(nil as VideoExporter.ProResProfile?)
                            Divider()
                            Text("ProRes 422 Proxy").tag(VideoExporter.ProResProfile.proRes422Proxy as VideoExporter.ProResProfile?)
                            Text("ProRes 422 LT").tag(VideoExporter.ProResProfile.proRes422LT as VideoExporter.ProResProfile?)
                            Text("ProRes 422").tag(VideoExporter.ProResProfile.proRes422 as VideoExporter.ProResProfile?)
                            Text("ProRes 422 HQ").tag(VideoExporter.ProResProfile.proRes422HQ as VideoExporter.ProResProfile?)
                            Text("ProRes 4444").tag(VideoExporter.ProResProfile.proRes4444 as VideoExporter.ProResProfile?)
                            Text("ProRes 4444 XQ").tag(VideoExporter.ProResProfile.proRes4444XQ as VideoExporter.ProResProfile?)
                        }
                        .pickerStyle(.menu)
                        
                        Toggle("Include Audio", isOn: $includeAudio)
                    }
                    
                case .gif:
                    Text("GIF exports are optimized for web sharing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .imageSequence:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image Format")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Image Format", selection: $selectedImageFormat) {
                            Text("PNG (Lossless)").tag(ImageFormat.png)
                            Text("JPEG (Smaller files)").tag(ImageFormat.jpeg)
                        }
                        .pickerStyle(.radioGroup)
                        
                        if selectedImageFormat == .jpeg {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("JPEG Quality: \(Int(jpegQuality * 100))%")
                                    .font(.caption)
                                
                                Slider(value: $jpegQuality, in: 0.1...1.0)
                            }
                        }
                    }
                    
                case .projectFile:
                    Text("Project files preserve all editing capabilities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .batchExport:
                    Text("Choose multiple export formats to process simultaneously")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Export button
            Button("Export") {
                startExport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(invalidExportSettings)
        }
        .padding()
        .frame(width: 480, height: 400)
        .sheet(item: $exportConfiguration) { config in
            ExportProgressView(
                configuration: config,
                asset: asset,
                onCompletion: { result in
                    // Handle export completion
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            os_log("Export completed successfully to: %{public}@", log: ExportModal.logger, type: .info, url.path)
                        case .failure(let error):
                            os_log("Export failed with error: %{public}@", log: ExportModal.logger, type: .error, error.localizedDescription)
                        }
                        // Dismiss the modal after handling the result
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.exportConfiguration = nil
                            onDismiss()
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if export settings are valid
    private var invalidExportSettings: Bool {
        guard let width = Int(exportWidth), width > 0,
              let height = Int(exportHeight), height > 0,
              let fps = Float(frameRate), fps > 0 else {
            os_log("Invalid export settings: width=%{public}@, height=%{public}@, fps=%{public}@", log: ExportModal.logger, type: .error, exportWidth, exportHeight, frameRate)
            return true
        }
        return false
    }
    
    // MARK: - Methods
    
    /// Start the export process based on current settings
    private func startExport() {
        // Validate settings
        guard let width = Int(exportWidth), width > 0,
              let height = Int(exportHeight), height > 0,
              let fps = Float(frameRate), fps > 0 else {
            os_log("Invalid export settings: width=%{public}@, height=%{public}@, fps=%{public}@", log: ExportModal.logger, type: .error, exportWidth, exportHeight, frameRate)
            return
        }
        
        os_log("Starting export with format: %{public}@, resolution: %{public}dx%{public}d, fps: %{public}f", log: ExportModal.logger, type: .info, String(describing: selectedFormat), width, height, fps)
        
        // Create a save panel to get the output location
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        
        // Configure save panel based on format
        switch selectedFormat {
        case .video:
            savePanel.title = "Export Video"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.allowedContentTypes = [.mpeg4Movie]
            savePanel.allowsOtherFileTypes = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "export.mp4"
            
        case .gif:
            savePanel.title = "Export Animated GIF"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.allowedContentTypes = [.gif]
            savePanel.allowsOtherFileTypes = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "animation.gif"
            
        case .imageSequence:
            savePanel.title = "Export Image Sequence"
            savePanel.nameFieldLabel = "Export To Folder:"
            savePanel.allowsOtherFileTypes = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "image_sequence"
            savePanel.prompt = "Export"
            
        case .projectFile:
            savePanel.title = "Export Project File"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.allowedContentTypes = [.fileURL]
            savePanel.allowsOtherFileTypes = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "project.msproj"
            
        case .batchExport:
            savePanel.title = "Export Multiple Formats"
            savePanel.nameFieldLabel = "Export To Folder:"
            savePanel.allowsOtherFileTypes = true
            savePanel.isExtensionHidden = false
            savePanel.nameFieldStringValue = "batch_export"
            savePanel.prompt = "Export"
        }
        
        os_log("Showing save panel for format: %{public}@", log: ExportModal.logger, type: .info, String(describing: selectedFormat))
        
        // Show save panel
        if savePanel.runModal() == .OK {
            guard let outputURL = savePanel.url else { 
                os_log("No output URL selected", log: ExportModal.logger, type: .error)
                return 
            }
            
            os_log("Selected output URL: %{public}@", log: ExportModal.logger, type: .info, outputURL.path)
            
            // Create the coordinator configuration
            let configuration = ExportCoordinator.ExportConfiguration(
                format: selectedFormat,
                width: width,
                height: height,
                frameRate: fps,
                outputURL: outputURL,
                proResProfile: selectedProResProfile,
                includeAudio: includeAudio,
                baseFilename: "frame",
                imageQuality: selectedFormat == .imageSequence(.jpeg) ? CGFloat(jpegQuality) : nil
            )
            
            // Store configuration and present the sheet
            os_log("Configured export with format: %{public}@", log: ExportModal.logger, type: .info, String(describing: configuration.format))
            
            // Set the configuration which will trigger the sheet presentation
            self.exportConfiguration = configuration
        } else {
            os_log("Export cancelled by user", log: ExportModal.logger, type: .info)
        }
    }
}

// Make ExportConfiguration identifiable to work with .sheet(item:)
extension ExportCoordinator.ExportConfiguration: Identifiable {
    public var id: String {
        // Create a unique identifier based on the configuration
        return "\(format)-\(width)x\(height)-\(outputURL.path)"
    }
}

#if !DISABLE_PREVIEWS
struct ExportModal_Previews: PreviewProvider {
    static var previews: some View {
        ExportModal(
            asset: AVAsset(url: URL(fileURLWithPath: "")),
            canvasWidth: 1920, 
            canvasHeight: 1080,
            onDismiss: {}
        )
    }
}
#endif 