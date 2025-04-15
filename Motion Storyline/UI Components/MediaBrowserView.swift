import SwiftUI
import AVKit

/// A view that displays and manages media assets in a project
public struct MediaBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var project: Project
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .dateAdded
    @State private var filterType: MediaAsset.MediaType? = nil
    @State private var selectedAsset: MediaAsset?
    @State private var isShowingImportSheet = false
    @State private var isShowingDeleteAlert = false
    @State private var previewPlayer: AVPlayer?
    @State private var isPreviewPlaying = false
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case name = "Name"
        case duration = "Duration"
        case type = "Type"
        
        var id: String { self.rawValue }
    }
    
    public init(project: Binding<Project>) {
        self._project = project
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Media Browser")
                    .font(.headline)
                
                Spacer()
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)
                .padding(.trailing, 8)
                
                // Filter and sort controls
                HStack(spacing: 8) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search media...", text: $searchText)
                    }
                    .padding(4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .frame(width: 150)
                    
                    // Media type filter
                    Picker("", selection: $filterType) {
                        Text("All").tag(nil as MediaAsset.MediaType?)
                        Text("Video").tag(MediaAsset.MediaType.video as MediaAsset.MediaType?)
                        Text("Audio").tag(MediaAsset.MediaType.audio as MediaAsset.MediaType?)
                        Text("Image").tag(MediaAsset.MediaType.image as MediaAsset.MediaType?)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    
                    // Sort order
                    Picker("", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    
                    // Import button
                    Button(action: { isShowingImportSheet = true }) {
                        Label("Import", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content area
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Assets list
                    mediaAssetsList(width: geometry.size.width * 0.4)
                    
                    // Preview area (if asset selected)
                    if let selectedAsset = selectedAsset {
                        Divider()
                        mediaPreviewView(asset: selectedAsset, width: geometry.size.width * 0.6)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingImportSheet) {
            MediaImportView(projectName: project.name) { newAsset in
                addAssetToProject(newAsset)
            }
        }
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text("Delete Asset"),
                message: Text("Are you sure you want to delete this media asset? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    if let selectedAsset = selectedAsset {
                        deleteAsset(selectedAsset)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            // Stop any playing media when view disappears
            previewPlayer?.pause()
        }
    }
    
    // MARK: - View Components
    
    private func mediaAssetsList(width: CGFloat) -> some View {
        let filteredAssets = project.mediaAssets.filter { asset in
            // Filter by type if a filter is selected
            if let filterType = filterType, asset.type != filterType {
                return false
            }
            
            // Filter by search text if present
            if !searchText.isEmpty {
                return asset.name.localizedCaseInsensitiveContains(searchText)
            }
            
            return true
        }
        
        let sortedAssets = sortAssets(filteredAssets)
        
        return List(sortedAssets, selection: $selectedAsset) { asset in
            MediaAssetRow(asset: asset, isSelected: selectedAsset?.id == asset.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAsset = asset
                    setupPreviewPlayer(for: asset)
                }
                .contextMenu {
                    Button(action: {
                        selectedAsset = asset
                        isShowingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    if asset.type == .video || asset.type == .audio {
                        Divider()
                        Button(action: {
                            // Implementation for "Add to Timeline" would go here
                        }) {
                            Label("Add to Timeline", systemImage: "timeline.selection")
                        }
                    }
                }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(width: width)
    }
    
    private func mediaPreviewView(asset: MediaAsset, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Text(asset.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: {
                    isShowingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Preview content
            VStack(spacing: 12) {
                // Media preview
                switch asset.type {
                case .video:
                    if let player = previewPlayer {
                        videoPreview(player: player)
                    } else {
                        loadingPreview()
                    }
                case .audio:
                    if let player = previewPlayer {
                        audioPreview(player: player)
                    } else {
                        loadingPreview()
                    }
                case .image:
                    imagePreview(url: asset.url)
                case .cameraRecording:
                    if let player = previewPlayer {
                        videoPreview(player: player)
                    } else {
                        loadingPreview()
                    }
                }
                
                // Media details
                mediaDetails(asset: asset)
            }
            .padding()
        }
        .frame(width: width)
    }
    
    private func videoPreview(player: AVPlayer) -> some View {
        VStack {
            VideoPlayer(player: player)
                .aspectRatio(16/9, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Video controls
            HStack {
                Button(action: {
                    if isPreviewPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPreviewPlaying.toggle()
                }) {
                    Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    player.seek(to: .zero)
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 8)
        }
    }
    
    private func audioPreview(player: AVPlayer) -> some View {
        VStack {
            // Audio waveform placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
            }
            
            // Audio controls
            HStack {
                Button(action: {
                    if isPreviewPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPreviewPlaying.toggle()
                }) {
                    Image(systemName: isPreviewPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    player.seek(to: .zero)
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 8)
        }
    }
    
    private func imagePreview(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: 300)
    }
    
    private func loadingPreview() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .aspectRatio(16/9, contentMode: .fit)
            
            ProgressView()
        }
    }
    
    private func mediaDetails(asset: MediaAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Media Type:")
                    .fontWeight(.medium)
                Text(asset.type.rawValue.capitalized)
                    .foregroundColor(.secondary)
            }
            
            if let duration = asset.duration {
                HStack {
                    Text("Duration:")
                        .fontWeight(.medium)
                    Text(formatDuration(duration))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Added:")
                    .fontWeight(.medium)
                Text(formatDate(asset.dateAdded))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Location:")
                    .fontWeight(.medium)
                Text(asset.url.lastPathComponent)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func setupPreviewPlayer(for asset: MediaAsset) {
        // Clear any existing player
        previewPlayer?.pause()
        previewPlayer = nil
        isPreviewPlaying = false
        
        // Only set up player for video or audio
        if asset.type == .video || asset.type == .audio || asset.type == .cameraRecording {
            let player = AVPlayer(url: asset.url)
            
            // Add observer for playback ended
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                isPreviewPlaying = false
                player.seek(to: .zero)
            }
            
            self.previewPlayer = player
        }
    }
    
    private func addAssetToProject(_ asset: MediaAsset) {
        // Add the asset to the project
        project.addMediaAsset(asset)
    }
    
    private func deleteAsset(_ asset: MediaAsset) {
        // Remove asset from project
        project.mediaAssets.removeAll { $0.id == asset.id }
        
        // Clear selection if deleted
        if selectedAsset?.id == asset.id {
            selectedAsset = nil
            previewPlayer?.pause()
            previewPlayer = nil
            isPreviewPlaying = false
        }
        
        // Try to delete file from disk
        do {
            try FileManager.default.removeItem(at: asset.url)
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    private func sortAssets(_ assets: [MediaAsset]) -> [MediaAsset] {
        switch sortOrder {
        case .name:
            return assets.sorted { $0.name < $1.name }
        case .dateAdded:
            return assets.sorted { $0.dateAdded > $1.dateAdded } // Newest first
        case .duration:
            return assets.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        case .type:
            return assets.sorted { $0.type.rawValue < $1.type.rawValue }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Row view for a media asset in the list
struct MediaAssetRow: View {
    let asset: MediaAsset
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconName(for: asset.type))
                .font(.title2)
                .foregroundColor(iconColor(for: asset.type))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                
                // Subtitle with info based on type
                HStack {
                    if let duration = asset.duration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    // Helper methods
    private func iconName(for type: MediaAsset.MediaType) -> String {
        switch type {
        case .video:
            return "film"
        case .audio:
            return "waveform"
        case .image:
            return "photo"
        case .cameraRecording:
            return "video"
        }
    }
    
    private func iconColor(for type: MediaAsset.MediaType) -> Color {
        switch type {
        case .video:
            return .blue
        case .audio:
            return .green
        case .image:
            return .orange
        case .cameraRecording:
            return .purple
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

struct MediaBrowserView_Previews: PreviewProvider {
    static var sampleProject: Project {
        var project = Project(
            name: "Sample Project", 
            thumbnail: "video_thumbnail", 
            lastModified: Date()
        )
        
        // Add some sample media assets
        let videoAsset = MediaAsset(
            name: "Introduction Video",
            type: .video,
            url: URL(string: "file:///sample/video.mp4")!,
            duration: 125.5,
            thumbnail: "video_thumbnail"
        )
        
        let audioAsset = MediaAsset(
            name: "Background Music",
            type: .audio,
            url: URL(string: "file:///sample/audio.mp3")!,
            duration: 210.0,
            thumbnail: "audio_thumbnail"
        )
        
        project.addMediaAsset(videoAsset)
        project.addMediaAsset(audioAsset)
        
        return project
    }
    
    static var previews: some View {
        MediaBrowserView(project: .constant(sampleProject))
            .frame(width: 800, height: 600)
    }
} 