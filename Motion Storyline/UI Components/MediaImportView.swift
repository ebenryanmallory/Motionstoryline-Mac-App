import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// A view that allows users to import various media files
public struct MediaImportView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var selectedMediaType: MediaAsset.MediaType = .video
    @State private var selectedFile: URL?
    @State private var isImporting = false
    @State private var importProgress: Float = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var assetName: String = ""
    @State private var currentAsset: AVAsset?
    @State private var assetDuration: TimeInterval = 0
    @State private var thumbnailImage: NSImage?
    @State private var showFilePicker = false
    
    // Media processing and selection states
    @State private var trimStartTime: Double = 0
    @State private var trimEndTime: Double = 0
    @State private var showAudioWaveform = false
    @State private var extractAudioTrack = false
    
    // This would be provided by the host view
    var onImport: ((MediaAsset) -> Void)?
    var projectName: String
    
    public init(projectName: String, onImport: ((MediaAsset) -> Void)? = nil) {
        self.projectName = projectName
        self.onImport = onImport
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Media")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Main content
            VStack(spacing: 20) {
                // Media type selection
                Picker("Media Type", selection: $selectedMediaType) {
                    Text("Video").tag(MediaAsset.MediaType.video)
                    Text("Audio").tag(MediaAsset.MediaType.audio)
                    Text("Image").tag(MediaAsset.MediaType.image)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)
                
                // File selection area
                VStack {
                    if let selectedFile = self.selectedFile {
                        // Show selected file information
                        HStack(alignment: .top) {
                            // Thumbnail preview
                            if let thumbnailImage = thumbnailImage {
                                Image(nsImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 160, height: 120)
                                    .cornerRadius(4)
                                    .padding(.trailing)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 160, height: 120)
                                    .cornerRadius(4)
                                    .overlay(
                                        Image(systemName: selectedMediaType == .video ? "film" : 
                                                            selectedMediaType == .audio ? "waveform" : "photo")
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)
                                    )
                                    .padding(.trailing)
                            }
                            
                            // File details
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selectedFile.lastPathComponent)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                
                                if selectedMediaType == .video || selectedMediaType == .audio {
                                    Text("Duration: \(formatDuration(assetDuration))")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                TextField("Media Name", text: $assetName)
                                    .textFieldStyle(.roundedBorder)
                                    .padding(.top, 4)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        
                        // Media specific options
                        if selectedMediaType == .video {
                            videoImportOptions
                        } else if selectedMediaType == .audio {
                            audioImportOptions
                        }
                        
                        // Import action button
                        Button(action: importMedia) {
                            if isImporting {
                                ProgressView(value: importProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .frame(height: 20)
                            } else {
                                Text("Import Media")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                        .disabled(isImporting || assetName.isEmpty)
                        
                    } else {
                        // File selection prompt
                        VStack(spacing: 12) {
                            Image(systemName: selectedMediaType == .video ? "film" : 
                                               selectedMediaType == .audio ? "waveform" : "photo")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("Select a \(selectedMediaType.rawValue) file to import")
                                .font(.headline)
                            
                            Text(getMediaTypeDescription())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Choose File...") {
                                showFilePicker = true
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top)
                        }
                        .padding(.vertical, 60)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                .background(Color.secondary.opacity(0.05))
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .frame(width: 600, height: 400)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Import"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedContentTypes(),
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }
    
    private var videoImportOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Video Options")
                .font(.headline)
                .padding(.horizontal)
            
            Toggle("Extract audio track", isOn: $extractAudioTrack)
                .padding(.horizontal)
            
            // If we implement trimming, add controls here
            // This would include a timeline scrubber to set start/end times
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .padding(.horizontal)
    }
    
    private var audioImportOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audio Options")
                .font(.headline)
                .padding(.horizontal)
            
            Toggle("Show waveform visualization", isOn: $showAudioWaveform)
                .padding(.horizontal)
            
            // If we implement trimming, add controls here
            // This would include a waveform visualization with trim controls
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .padding(.horizontal)
    }
    
    private func allowedContentTypes() -> [UTType] {
        switch selectedMediaType {
        case .video:
            return [UTType.movie, UTType.mpeg4Movie, UTType.quickTimeMovie, UTType.avi]
        case .audio:
            return [UTType.audio, UTType.mp3, UTType.wav]
        case .image:
            return [UTType.image, UTType.jpeg, UTType.png, UTType.tiff]
        case .cameraRecording:
            return [UTType.movie]
        }
    }
    
    private func getMediaTypeDescription() -> String {
        switch selectedMediaType {
        case .video:
            return "Supported formats: MP4, MOV, AVI\nMax file size: 2GB"
        case .audio:
            return "Supported formats: MP3, WAV, AAC\nMax file size: 500MB"
        case .image:
            return "Supported formats: JPG, PNG, TIFF\nMax file size: 100MB"
        case .cameraRecording:
            return "Select a camera recording file"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let selectedFiles = try result.get()
            if let fileURL = selectedFiles.first {
                // Ensure the file is accessible
                if !fileURL.startAccessingSecurityScopedResource() {
                    showAlert(message: "Cannot access the selected file.")
                    return
                }
                
                // Store the file URL
                self.selectedFile = fileURL
                
                // Set default name from filename
                let filename = fileURL.deletingPathExtension().lastPathComponent
                self.assetName = filename
                
                // Create AVAsset for video/audio files
                if selectedMediaType == .video || selectedMediaType == .audio {
                    let asset = AVAsset(url: fileURL)
                    self.currentAsset = asset
                    
                    // Get duration
                    Task {
                        do {
                            let duration = try await asset.load(.duration).seconds
                            DispatchQueue.main.async {
                                self.assetDuration = duration
                                self.trimEndTime = duration
                            }
                            
                            // Generate thumbnail for video
                            if selectedMediaType == .video {
                                let imageGenerator = AVAssetImageGenerator(asset: asset)
                                imageGenerator.appliesPreferredTrackTransform = true
                                let time = CMTime(seconds: 0.5, preferredTimescale: 600)
                                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                                let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
                                
                                DispatchQueue.main.async {
                                    self.thumbnailImage = nsImage
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                showAlert(message: "Failed to load media: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
                // Remember to stop accessing the resource when done
                fileURL.stopAccessingSecurityScopedResource()
            }
        } catch {
            showAlert(message: "File selection failed: \(error.localizedDescription)")
        }
    }
    
    private func importMedia() {
        guard let fileURL = selectedFile else {
            showAlert(message: "No file selected")
            return
        }
        
        // Start the import process
        isImporting = true
        importProgress = 0.2
        
        // Create a temporary URL to copy the file to app's documents directory
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            showAlert(message: "Could not access documents directory")
            isImporting = false
            return
        }
        
        // Create a media directory if it doesn't exist
        let mediaDirectoryURL = documentsURL.appendingPathComponent("Media", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
        } catch {
            showAlert(message: "Failed to create media directory: \(error.localizedDescription)")
            isImporting = false
            return
        }
        
        // Generate a unique filename
        let fileExtension = fileURL.pathExtension
        let uniqueFilename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = mediaDirectoryURL.appendingPathComponent(uniqueFilename)
        
        do {
            // Copy the file to our app's documents directory
            if fileURL.startAccessingSecurityScopedResource() {
                try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                fileURL.stopAccessingSecurityScopedResource()
                
                importProgress = 0.7
                
                // Create the media asset
                let asset = MediaAsset(
                    name: assetName,
                    type: selectedMediaType,
                    url: destinationURL,
                    duration: assetDuration,
                    thumbnail: selectedMediaType == .video ? "video_thumbnail" : selectedMediaType == .audio ? "audio_thumbnail" : "image_thumbnail"
                )
                
                // If extract audio is enabled and this is a video, also create an audio asset
                if extractAudioTrack && selectedMediaType == .video, let currentAsset = self.currentAsset {
                    Task {
                        do {
                            let audioURL = try await extractAudio(from: currentAsset, to: mediaDirectoryURL)
                            let audioAsset = MediaAsset(
                                name: "\(assetName) - Audio",
                                type: .audio,
                                url: audioURL,
                                duration: assetDuration,
                                thumbnail: "audio_thumbnail"
                            )
                            
                            DispatchQueue.main.async {
                                // Call the import handler for both assets
                                self.onImport?(asset)
                                self.onImport?(audioAsset)
                                
                                self.importProgress = 1.0
                                self.isImporting = false
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        } catch {
                            DispatchQueue.main.async {
                                // Still import the video even if audio extraction fails
                                self.onImport?(asset)
                                
                                self.importProgress = 1.0
                                self.isImporting = false
                                self.presentationMode.wrappedValue.dismiss()
                                
                                self.showAlert(message: "Imported video, but failed to extract audio: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    // Call the import handler
                    self.onImport?(asset)
                    
                    importProgress = 1.0
                    isImporting = false
                    presentationMode.wrappedValue.dismiss()
                }
            } else {
                throw NSError(domain: "MediaImportView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not access the file"])
            }
        } catch {
            showAlert(message: "Failed to import media: \(error.localizedDescription)")
            isImporting = false
        }
    }
    
    /// Extract audio from a video asset and save as a separate audio file
    @MainActor
    private func extractAudio(from asset: AVAsset, to directory: URL) async throws -> URL {
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "MediaImportView", code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio track found in the video"])
        }
        
        // Create a unique filename for the audio
        let audioFilename = "\(UUID().uuidString).m4a"
        let audioURL = directory.appendingPathComponent(audioFilename)
        
        // Create audio export session
        let composition = AVMutableComposition()
        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "MediaImportView", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition audio track"])
        }
        
        // Add the audio track to the composition
        let audioTrack = audioTracks[0]
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        // Setup export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "MediaImportView", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = audioURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange
        
        // Perform the export
        await exportSession.export()
        
        // Check for errors
        if let error = exportSession.error {
            throw error
        }
        
        return audioURL
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

/// A preview for the media import view
struct MediaImportView_Previews: PreviewProvider {
    static var previews: some View {
        MediaImportView(projectName: "Sample Project") { asset in
            print("Imported: \(asset.name)")
        }
    }
} 