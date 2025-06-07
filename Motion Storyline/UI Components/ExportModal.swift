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
    
    // Closures to get the latest data
    let getAnimationController: () -> AnimationController?
    let getCanvasElements: () -> [CanvasElement]?
    
    // Callback for when the modal is dismissed
    let onDismiss: () -> Void
    
    // State for export configuration
    @State private var selectedFormat: ExportFormat = .video
    @State private var selectedProResProfile: VideoExporter.ProResProfile? = nil
    @State private var selectedImageFormat: ImageFormat = .png
    @State private var exportWidth: String
    @State private var exportHeight: String
    @State private var frameRate: String = "60" // Default to 60 for 5s/300 frames
    @State private var numberOfFrames: String = "300" // Default to 300 (5s at 60fps)
    @State private var includeAudio: Bool = true
    @State private var jpegQuality: Double = 0.9
    
    // State for export progress
    @State private var isExporting = false
    @State private var exportConfiguration: ExportCoordinator.ExportConfiguration?
    
    // Helper: computed duration from numberOfFrames and frameRate
    private var calculatedDuration: Double {
        guard let frames = Int(numberOfFrames), let fps = Double(frameRate), fps > 0 else { return 0 }
        return Double(frames) / fps
    }
    
    // Combined initializer with default closures for animation data
    init(
        asset: AVAsset,
        canvasWidth: Int,
        canvasHeight: Int,
        getAnimationController: @escaping () -> AnimationController? = { nil }, // Default to nil
        getCanvasElements: @escaping () -> [CanvasElement]? = { nil },    // Default to nil
        onDismiss: @escaping () -> Void
    ) {
        self.asset = asset
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.getAnimationController = getAnimationController
        self.getCanvasElements = getCanvasElements
        self.onDismiss = onDismiss
        
        _exportWidth = State(initialValue: String(canvasWidth))
        _exportHeight = State(initialValue: String(canvasHeight))
    }
    
    var body: some View {
        ScrollView {
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
                // Number of frames settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Frames")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        TextField("Frames", text: $numberOfFrames)
                            .frame(width: 80)
                        Text("frames")
                        Spacer()
                        Button("300") { numberOfFrames = "300" }.buttonStyle(.borderless)
                        Button("150") { numberOfFrames = "150" }.buttonStyle(.borderless)
                        Button("600") { numberOfFrames = "600" }.buttonStyle(.borderless)
                    }
                    Text("Duration: \(String(format: "%.2f", calculatedDuration)) seconds @ \(frameRate) fps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Format-specific settings
                switch selectedFormat {
                case .video, .videoProRes: // Combine video and videoProRes as they share UI
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
        } // End ScrollView
        .padding()
        .frame(width: 480)
        .sheet(item: $exportConfiguration) { config in
            // Call the closures to get the latest data
            let currentAnimationController = getAnimationController()
            let currentCanvasElements = getCanvasElements()
            // Assuming canvasWidth/Height are still relevant for size, if not, these should also come from a closure or DesignDocument
            let currentCanvasSize = CGSize(width: self.canvasWidth, height: self.canvasHeight)

            ExportProgressView(
                configuration: config,
                asset: self.asset,
                animationController: currentAnimationController, // Pass fetched controller
                canvasElements: currentCanvasElements,       // Pass fetched elements
                canvasSize: currentCanvasSize,               // Pass size
                onCompletion: { result in
                    // Handle export completion
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            os_log("Export completed successfully: %{public}@", log: ExportModal.logger, type: .info, url.path)
                        case .failure(let error):
                            os_log("Export failed with error: %{public}@", log: ExportModal.logger, type: .error, error.localizedDescription)
                        }
                        // Dismiss the modal after handling the result
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.exportConfiguration = nil // Clear the configuration to dismiss the sheet
                            // self.onDismiss() // Consider if the main modal should also dismiss here
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
              let fps = Float(frameRate), fps > 0,
              let frames = Int(numberOfFrames), frames > 0 else {
            os_log("Invalid export settings: width=%{public}@, height=%{public}@, fps=%{public}@, frames=%{public}@", 
                   log: ExportModal.logger, type: .error, exportWidth, exportHeight, frameRate, numberOfFrames)
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
              let fps = Float(frameRate), fps > 0,
              let frames = Int(numberOfFrames), frames > 0 else {
            os_log("Invalid export settings: width=%{public}@, height=%{public}@, fps=%{public}@, frames=%{public}@", 
                   log: ExportModal.logger, type: .error, exportWidth, exportHeight, frameRate, numberOfFrames)
            return
        }
        
        os_log("Starting export with format: %{public}@, resolution: %{public}dx%{public}d, fps: %{public}f, frames: %{public}d", 
               log: ExportModal.logger, type: .info, String(describing: selectedFormat), width, height, fps, frames)
        
        // For image sequence, use NSOpenPanel in directory mode to select parent folder
        if case .imageSequence = selectedFormat {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.canCreateDirectories = true
            openPanel.title = "Select Export Folder"
            openPanel.prompt = "Choose"
            
            os_log("Showing open panel for parent directory selection", log: ExportModal.logger, type: .info)
            if openPanel.runModal() == .OK, let parentURL = openPanel.url {
                os_log("Selected parent directory: %{public}@", log: ExportModal.logger, type: .info, parentURL.path)
                // Suggest a default subfolder name
                let baseFolderName = "image_sequence"
                var exportFolderURL = parentURL.appendingPathComponent(baseFolderName)
                var suffix = 1
                let fileManager = FileManager.default
                // Ensure the export folder does not overwrite unless user agrees
                while fileManager.fileExists(atPath: exportFolderURL.path) {
                    let alert = NSAlert()
                    alert.messageText = "Folder Exists"
                    alert.informativeText = "The folder \(baseFolderName) already exists. Overwrite contents?"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Overwrite")
                    alert.addButton(withTitle: "Choose New Name")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        // Overwrite
                        do {
                            try fileManager.removeItem(at: exportFolderURL)
                            os_log("Removed existing folder for overwrite: %{public}@", log: ExportModal.logger, type: .info, exportFolderURL.path)
                        } catch {
                            os_log("Failed to remove existing folder: %{public}@", log: ExportModal.logger, type: .error, error.localizedDescription)
                            return
                        }
                        break
                    } else {
                        // Choose new name
                        suffix += 1
                        exportFolderURL = parentURL.appendingPathComponent("\(baseFolderName)_\(suffix)")
                    }
                }
                os_log("Final export folder: %{public}@", log: ExportModal.logger, type: .info, exportFolderURL.path)
                // Create the coordinator configuration
                let configuration = ExportCoordinator.ExportConfiguration(
                    format: selectedFormat,
                    width: width,
                    height: height,
                    frameRate: fps,
                    numberOfFrames: Int(numberOfFrames),
                    outputURL: exportFolderURL,
                    proResProfile: selectedProResProfile,
                    includeAudio: includeAudio,
                    baseFilename: "frame",
                    imageQuality: selectedFormat == .imageSequence(.jpeg) ? CGFloat(jpegQuality) : nil
                )
                // Store configuration and present the sheet
                os_log("Configured export with format: %{public}@", log: ExportModal.logger, type: .info, String(describing: configuration.format))
                self.exportConfiguration = configuration
            } else {
                os_log("No parent directory selected for image sequence export", log: ExportModal.logger, type: .error)
            }
            return
        }
        // --- Default logic for other formats ---
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
        default:
            break
        }
        os_log("Showing save panel for format: %{public}@", log: ExportModal.logger, type: .info, String(describing: selectedFormat))
        if savePanel.runModal() == .OK {
            guard let outputURL = savePanel.url else {
                os_log("No output URL selected", log: ExportModal.logger, type: .error)
                return
            }
            os_log("Selected output URL: %{public}@", log: ExportModal.logger, type: .info, outputURL.path)
            let configuration = ExportCoordinator.ExportConfiguration(
                format: selectedFormat,
                width: width,
                height: height,
                frameRate: fps,
                numberOfFrames: Int(numberOfFrames),
                outputURL: outputURL,
                proResProfile: selectedProResProfile,
                includeAudio: includeAudio,
                baseFilename: "frame",
                imageQuality: selectedFormat == .imageSequence(.jpeg) ? CGFloat(jpegQuality) : nil
            )
            os_log("Configured export with format: %{public}@", log: ExportModal.logger, type: .info, String(describing: configuration.format))
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