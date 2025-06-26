import SwiftUI
import AVFoundation

/// A sheet view that presents export options and manages the export process
public struct ExportOptionsSheet: View {
    @State private var currentStep: ExportStep = .selectPlatform
    @State private var selectedPlatform: SocialMediaPlatform = .instagram
    @State private var selectedAspectRatio: AspectRatio = .square
    @State private var exportConfig: VideoExporter.ExportConfiguration?
    
    let asset: AVAsset
    let projectName: String
    let onClose: () -> Void
    
    public init(asset: AVAsset, projectName: String, onClose: @escaping () -> Void) {
        self.asset = asset
        self.projectName = projectName
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Export Project")
                        .font(.headline)
                        .accessibilityIdentifier("export-options-title")
                        .accessibilityLabel("Export Project")
                        .accessibilityAddTraits(.isHeader)
                    Text(projectName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("export-project-name")
                        .accessibilityLabel("Project name: \(projectName)")
                }
                
                Spacer()
                
                if currentStep == .selectPlatform {
                    Button("Cancel") {
                        onClose()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("export-cancel-button")
                    .accessibilityLabel("Cancel Export")
                    .accessibilityHint("Closes the export dialog without exporting")
                }
            }
            .padding()
            .accessibilityElement(children: .contain)
            
            // Divider
            Divider()
                .accessibilityHidden(true) // Dividers are decorative
            
            // Content
            VStack {
                switch currentStep {
                case .selectPlatform:
                    PlatformSelectionView { configuration in
                        self.exportConfig = configuration
                        self.currentStep = .exporting
                    }
                    
                case .exporting:
                    if let config = exportConfig {
                        ExportProgressView(
                            configuration: convertToCoordinatorConfig(config),
                            asset: asset,
                            onCompletion: { result in
                                switch result {
                                case .success:
                                    // Keep the success view visible
                                    break
                                case .failure:
                                    // Keep the error view visible
                                    break
                                }
                            }
                        )
                        .accessibilityIdentifier("export-progress-view")
                        .accessibilityLabel("Export Progress")
                        .accessibilityHint("Shows the current export progress and status")
                    } else {
                        Text("Invalid export configuration")
                            .foregroundColor(.red)
                            .accessibilityIdentifier("export-error-message")
                            .accessibilityLabel("Export Error: Invalid export configuration")
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
            .padding()
        }
        .frame(width: 450)
        .background(Color(NSColor.windowBackgroundColor))
        .accessibilityIdentifier("export-options-sheet")
        .accessibilityLabel("Export Options")
        .accessibilityHint("Configure export settings for your project")
    }
    
    /// Platform selection view
    private struct PlatformSelectionView: View {
        @State private var selectedPlatform: SocialMediaPlatform = .instagram
        @State private var selectedAspectRatio: AspectRatio = .square
        let onExport: (VideoExporter.ExportConfiguration) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                // Platform selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Platform")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("platform-selection-label")
                        .accessibilityLabel("Platform Selection")
                        .accessibilityAddTraits(.isHeader)
                    
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(SocialMediaPlatform.allCases) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("platform-picker")
                    .accessibilityLabel("Select Platform")
                    .accessibilityHint("Choose the social media platform for optimized export settings")
                    
                    Text(selectedPlatform.formatDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("platform-description")
                        .accessibilityLabel("Platform description: \(selectedPlatform.formatDescription)")
                }
                
                // Aspect ratio selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aspect Ratio")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("aspect-ratio-label")
                        .accessibilityLabel("Aspect Ratio Selection")
                        .accessibilityAddTraits(.isHeader)
                    
                    Picker("Aspect Ratio", selection: $selectedAspectRatio) {
                        ForEach(AspectRatio.allCases) { aspectRatio in
                            Text(aspectRatio.displayNameWithDimensions(for: selectedPlatform)).tag(aspectRatio)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("aspect-ratio-picker")
                    .accessibilityLabel("Select Aspect Ratio")
                    .accessibilityHint("Choose the aspect ratio for your export")
                    
                    Text(selectedAspectRatio.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("aspect-ratio-description")
                        .accessibilityLabel("Aspect ratio description: \(selectedAspectRatio.description)")
                }
                
                // Resolution info
                VStack(alignment: .leading, spacing: 4) {
                    let dimensions = selectedPlatform.recommendedDimensions(forAspectRatio: selectedAspectRatio)
                    
                    HStack {
                        Text("Resolution:")
                            .foregroundColor(.secondary)
                        Text("\(dimensions.width) × \(dimensions.height)")
                            .bold()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Resolution: \(dimensions.width) by \(dimensions.height) pixels")
                    
                    HStack {
                        Text("Frame Rate:")
                            .foregroundColor(.secondary)
                        Text("\(Int(selectedPlatform.recommendedFrameRate)) fps")
                            .bold()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Frame Rate: \(Int(selectedPlatform.recommendedFrameRate)) frames per second")
                    
                    HStack {
                        Text("Bitrate:")
                            .foregroundColor(.secondary)
                        Text("\(selectedPlatform.recommendedBitrate / 1_000_000) Mbps")
                            .bold()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Bitrate: \(selectedPlatform.recommendedBitrate / 1_000_000) megabits per second")
                }
                .accessibilityIdentifier("export-settings-info")
                .accessibilityLabel("Export Settings Information")
                .accessibilityHint("Shows the recommended settings for the selected platform and aspect ratio")
                .padding(.top, 8)
                
                Spacer()
                
                // Export button
                Button(action: {
                    createAndExport()
                }) {
                    Text("Export")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("export-start-button")
                .accessibilityLabel("Start Export")
                .accessibilityHint("Begins exporting your project with the selected settings")
            }
        }
        
        private func createAndExport() {
            // Create file name with platform and aspect ratio
            let fileName = "export_\(selectedPlatform.fileNameSuffix(aspectRatio: selectedAspectRatio)).mp4"
            
            // Create URL in the user's Documents directory
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            
            let outputURL = documentsURL.appendingPathComponent(fileName)
            
            // Create export configuration using our preset
            let configuration = selectedPlatform.createExportConfiguration(
                aspectRatio: selectedAspectRatio,
                outputURL: outputURL
            )
            
            // Pass configuration to callback
            onExport(configuration)
        }
    }
    
    /// Convert VideoExporter.ExportConfiguration to ExportCoordinator.ExportConfiguration
    private func convertToCoordinatorConfig(_ config: VideoExporter.ExportConfiguration) -> ExportCoordinator.ExportConfiguration {
        return ExportCoordinator.ExportConfiguration(
            format: config.format,
            width: config.width,
            height: config.height,
            frameRate: config.frameRate,
            numberOfFrames: config.numberOfFrames,
            outputURL: config.outputURL,
            proResProfile: config.proResProfile,
            includeAudio: config.includeAudio,
            baseFilename: config.baseFilename ?? "frame",
            imageQuality: config.imageQuality
        )
    }
    
    /// Steps in the export process
    private enum ExportStep {
        case selectPlatform
        case exporting
    }
}

#if !DISABLE_PREVIEWS
struct ExportOptionsSheet_Previews: PreviewProvider {
    static var previews: some View {
        ExportOptionsSheet(
            asset: AVAsset(url: URL(fileURLWithPath: "")),
            projectName: "My Animation",
            onClose: {}
        )
    }
}
#endif 