import SwiftUI

/// A view that allows users to select social media export presets
public struct SocialMediaExportView: View {
    @State private var selectedPlatform: SocialMediaPlatform = .instagram
    @State private var selectedAspectRatio: AspectRatio = .square
    @State private var isExporting = false
    @State private var exportProgress: Float = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // This would be provided by the host view
    var onExport: ((VideoExporter.ExportConfiguration) -> Void)?
    var projectName: String
    
    public init(projectName: String, onExport: ((VideoExporter.ExportConfiguration) -> Void)? = nil) {
        self.projectName = projectName
        self.onExport = onExport
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            Text("Export for Social Media")
                .font(.headline)
            
            // Platform selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Platform")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Platform", selection: $selectedPlatform) {
                    ForEach(SocialMediaPlatform.allCases) { platform in
                        Text(platform.displayName).tag(platform)
                    }
                }
                .pickerStyle(.menu)
                
                Text(selectedPlatform.formatDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Aspect ratio selection (if applicable)
            VStack(alignment: .leading, spacing: 8) {
                Text("Aspect Ratio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Aspect Ratio", selection: $selectedAspectRatio) {
                    ForEach(AspectRatio.allCases) { aspectRatio in
                        Text(aspectRatio.displayNameWithDimensions(for: selectedPlatform)).tag(aspectRatio)
                    }
                }
                .pickerStyle(.menu)
                
                Text(selectedAspectRatio.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                
                HStack {
                    Text("Frame Rate:")
                        .foregroundColor(.secondary)
                    Text("\(Int(selectedPlatform.recommendedFrameRate)) fps")
                        .bold()
                }
                
                HStack {
                    Text("Bitrate:")
                        .foregroundColor(.secondary)
                    Text("\(selectedPlatform.recommendedBitrate / 1_000_000) Mbps")
                        .bold()
                }
            }
            .padding(.top, 8)
            
            // Export button
            if isExporting {
                VStack {
                    ProgressView(value: exportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    Text("Exporting... \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            } else {
                Button(action: exportVideo) {
                    Text("Export")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top)
            }
        }
        .padding()
        .frame(width: 400)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Export"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func exportVideo() {
        let fileName = "\(projectName)_\(selectedPlatform.fileNameSuffix(aspectRatio: selectedAspectRatio)).mp4"
        
        // Create URL in the user's Documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert(message: "Could not access documents directory")
            return
        }
        
        let outputURL = documentsURL.appendingPathComponent(fileName)
        
        // Create export configuration using our preset
        let configuration = selectedPlatform.createExportConfiguration(
            aspectRatio: selectedAspectRatio,
            outputURL: outputURL
        )
        
        // Set to exporting state
        isExporting = true
        exportProgress = 0.0
        
        // Call export handler
        onExport?(configuration)
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

/// A preview for the social media export view
struct SocialMediaExportView_Previews: PreviewProvider {
    static var previews: some View {
        SocialMediaExportView(projectName: "MyAnimation") { configuration in
            print("Would export with: \(configuration.width)x\(configuration.height)")
        }
    }
} 