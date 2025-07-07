import SwiftUI
import AVKit
import AVFoundation

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
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    @State private var draggedAsset: MediaAsset?
    @State private var showSuccessNotification = false
    @State private var notificationMessage = ""
    @State private var isNotificationError = false
    var onAddElementToCanvas: ((CanvasElement) -> Void)?
    var onAddAudioToTimeline: ((AudioLayer) -> Void)?
    var onMediaAssetImported: (() -> Void)? // Callback for when media assets are imported
    var currentTimelineTime: TimeInterval = 0.0 // Current frame time for audio start position
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case name = "Name"
        case duration = "Duration"
        case type = "Type"
        
        var id: String { self.rawValue }
    }
    
    public init(project: Binding<Project>, onAddElementToCanvas: ((CanvasElement) -> Void)? = nil, onAddAudioToTimeline: ((AudioLayer) -> Void)? = nil, onMediaAssetImported: (() -> Void)? = nil, currentTimelineTime: TimeInterval = 0.0) {
        self._project = project
        self.onAddElementToCanvas = onAddElementToCanvas
        self.onAddAudioToTimeline = onAddAudioToTimeline
        self.onMediaAssetImported = onMediaAssetImported
        self.currentTimelineTime = currentTimelineTime
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Media Browser")
                    .font(.headline)
                    .accessibilityIdentifier("media-browser-title")
                    .accessibilityLabel("Media Browser")
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Filter and sort controls
                HStack(spacing: 8) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search media...", text: $searchText)
                            .accessibilityIdentifier("media-search-field")
                            .accessibilityLabel("Search media files")
                            .accessibilityHint("Type to filter media assets by name")
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
                    .accessibilityIdentifier("media-type-filter")
                    .accessibilityLabel("Filter by media type")
                    .accessibilityHint("Select a media type to filter the list, or choose All to show all media")
                    
                    // Sort order
                    Picker("", selection: $sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                    .accessibilityIdentifier("media-sort-order")
                    .accessibilityLabel("Sort media files")
                    .accessibilityHint("Choose how to sort the media list: by date, name, duration, or type")
                    
                    // Import button
                    Button(action: { isShowingImportSheet = true }) {
                        Label("Import", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("media-import-button")
                    .accessibilityLabel("Import Media")
                    .accessibilityHint("Opens the media import dialog to add new video, audio, or image files to your project")
                }
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)
                .padding(.leading, 8)
                .accessibilityIdentifier("media-browser-close")
                .accessibilityLabel("Close Media Browser")
                .accessibilityHint("Closes the media browser and returns to the main editor")
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
        .overlay(
            Group {
                if showSuccessNotification {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: isNotificationError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundColor(isNotificationError ? .red : .green)
                            Text(notificationMessage)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
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
        .onChange(of: showSuccessNotification) { isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessNotification = false
                    }
                }
            }
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
            MediaAssetRow(
                asset: asset, 
                isSelected: selectedAsset?.id == asset.id,
                isDragging: isDragging && draggedAsset?.id == asset.id,
                dragOffset: draggedAsset?.id == asset.id ? dragOffset : .zero
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAsset = asset
                    setupPreviewPlayer(for: asset)
                }
                .gesture(
                    DragGesture(coordinateSpace: .global)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                draggedAsset = asset
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleDragEnd(for: asset, at: value.location)
                            isDragging = false
                            draggedAsset = nil
                            dragOffset = .zero
                        }
                )
                .accessibilityIdentifier("media-asset-\(asset.id)")
                .accessibilityLabel("\(asset.name), \(asset.type.rawValue)")
                .accessibilityHint("Double tap to select and preview this \(asset.type.rawValue) file. Drag to add to canvas or timeline")
                .accessibilityAddTraits(.isButton)
                .contextMenu {
                    Button(action: {
                        selectedAsset = asset
                        isShowingDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .accessibilityLabel("Delete \(asset.name)")
                    .accessibilityHint("Permanently removes this media file from the project")
                    
                    if asset.type == .video || asset.type == .image {
                        Divider()
                        Button(action: {
                            let newElement: CanvasElement
                            let defaultPosition = CGPoint(x: 200, y: 200) // Or some other default
                            let elementSize = asset.dimensions ?? CGSize(width: 300, height: 200)

                            if asset.type == .image {
                                newElement = CanvasElement.image(at: defaultPosition, assetURL: asset.url, displayName: asset.name, size: elementSize)
                            } else { // .video
                                newElement = CanvasElement.video(
                                    at: defaultPosition, 
                                    assetURL: asset.url, 
                                    displayName: asset.name, 
                                    size: elementSize,
                                    videoDuration: asset.duration
                                )
                            }
                            onAddElementToCanvas?(newElement)
                            dismiss() // Dismiss the browser after adding
                        }) {
                            Label("Add to Canvas", systemImage: "plus.square.on.square")
                        }
                        .accessibilityLabel("Add \(asset.name) to Canvas")
                        .accessibilityHint("Adds this \(asset.type.rawValue) as a new element on the design canvas")
                    } else if asset.type == .audio {
                        Divider()
                        Button(action: {
                            // Create an audio layer from the asset
                            if let audioLayer = AudioLayer.from(mediaAsset: asset, startTime: currentTimelineTime) {
                                onAddAudioToTimeline?(audioLayer)
                                
                                // Show success notification
                                withAnimation {
                                    notificationMessage = "\(asset.name) added to timeline"
                                    isNotificationError = false
                                    showSuccessNotification = true
                                }
                                
                                dismiss() // Dismiss the browser after adding
                            } else {
                                // Show error notification if AudioLayer creation fails
                                withAnimation {
                                    notificationMessage = "Failed to add \(asset.name) to timeline"
                                    isNotificationError = true
                                    showSuccessNotification = true
                                }
                            }
                        }) {
                            Label("Add to Timeline", systemImage: "timeline.selection")
                        }
                        .accessibilityLabel("Add \(asset.name) to Timeline")
                        .accessibilityHint("Adds this audio track to the timeline for animation synchronization")
                    }
                }
        }
        .listStyle(.bordered(alternatesRowBackgrounds: true))
        .frame(width: width)
        .accessibilityIdentifier("media-assets-list")
        .accessibilityLabel("Media Assets List")
        .accessibilityHint("List of imported media files. Select an item to preview it.")
    }
    
    private func mediaPreviewView(asset: MediaAsset, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Text(asset.name)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityIdentifier("media-preview-title")
                    .accessibilityLabel("Now previewing: \(asset.name)")
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button(action: {
                    isShowingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("media-preview-delete")
                .accessibilityLabel("Delete \(asset.name)")
                .accessibilityHint("Permanently removes this media file from the project")
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
                .accessibilityIdentifier("video-preview-player")
                .accessibilityLabel("Video preview")
                .accessibilityHint("Video player showing the selected video file")
            
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
                .accessibilityIdentifier("video-play-pause")
                .accessibilityLabel(isPreviewPlaying ? "Pause video" : "Play video")
                .accessibilityHint("Controls video playback")
                
                Button(action: {
                    player.seek(to: .zero)
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("video-restart")
                .accessibilityLabel("Restart video")
                .accessibilityHint("Seeks to the beginning of the video")
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
            .accessibilityIdentifier("audio-preview-waveform")
            .accessibilityLabel("Audio waveform visualization")
            .accessibilityHint("Visual representation of the audio file")
            
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
                .accessibilityIdentifier("audio-play-pause")
                .accessibilityLabel(isPreviewPlaying ? "Pause audio" : "Play audio")
                .accessibilityHint("Controls audio playback")
                
                Button(action: {
                    player.seek(to: .zero)
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("audio-restart")
                .accessibilityLabel("Restart audio")
                .accessibilityHint("Seeks to the beginning of the audio")
            }
            .padding(.top, 8)
        }
    }
    
    private func imagePreview(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .accessibilityLabel("Loading image")
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .accessibilityLabel("Image preview")
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                    .accessibilityLabel("Failed to load image")
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(maxHeight: 300)
        .accessibilityIdentifier("image-preview")
        .accessibilityHint("Preview of the selected image file")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Media Type: \(asset.type.rawValue.capitalized)")
            
            if let duration = asset.duration {
                HStack {
                    Text("Duration:")
                        .fontWeight(.medium)
                    Text(formatDuration(duration))
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Duration: \(formatDuration(duration))")
            }
            
            HStack {
                Text("Added:")
                    .fontWeight(.medium)
                Text(formatDate(asset.dateAdded))
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Added: \(formatDate(asset.dateAdded))")
            
            HStack {
                Text("Location:")
                    .fontWeight(.medium)
                Text(asset.url.lastPathComponent)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Location: \(asset.url.lastPathComponent)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .accessibilityIdentifier("media-details")
        .accessibilityLabel("Media file details")
        .accessibilityHint("Information about the selected media file")
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
        
        // Notify that a media asset was imported
        onMediaAssetImported?()
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
    
    private func handleDragEnd(for asset: MediaAsset, at location: CGPoint) {
        // Handle drag and drop similar to the context menu actions
        let defaultPosition = CGPoint(x: 200, y: 200)
        let elementSize = asset.dimensions ?? CGSize(width: 300, height: 200)
        
        if asset.type == .video || asset.type == .image {
            let newElement: CanvasElement
            
            if asset.type == .image {
                newElement = CanvasElement.image(at: defaultPosition, assetURL: asset.url, displayName: asset.name, size: elementSize)
            } else { // .video
                newElement = CanvasElement.video(
                    at: defaultPosition, 
                    assetURL: asset.url, 
                    displayName: asset.name, 
                    size: elementSize,
                    videoDuration: asset.duration
                )
            }
            
            onAddElementToCanvas?(newElement)
            
            // Show success notification
            withAnimation {
                notificationMessage = "\(asset.name) added to canvas"
                isNotificationError = false
                showSuccessNotification = true
            }
            
        } else if asset.type == .audio {
            // Create an audio layer from the asset
            if let audioLayer = AudioLayer.from(mediaAsset: asset, startTime: currentTimelineTime) {
                onAddAudioToTimeline?(audioLayer)
                
                // Show success notification
                withAnimation {
                    notificationMessage = "\(asset.name) added to timeline"
                    isNotificationError = false
                    showSuccessNotification = true
                }
            } else {
                // Show error notification if AudioLayer creation fails
                withAnimation {
                    notificationMessage = "Failed to add \(asset.name) to timeline"
                    isNotificationError = true
                    showSuccessNotification = true
                }
            }
        }
        
        // Note: We don't dismiss the media browser as per requirements
    }
}

/// Row view for a media asset in the list
struct MediaAssetRow: View {
    let asset: MediaAsset
    let isSelected: Bool
    let isDragging: Bool
    let dragOffset: CGSize
    
    init(asset: MediaAsset, isSelected: Bool, isDragging: Bool = false, dragOffset: CGSize = .zero) {
        self.asset = asset
        self.isSelected = isSelected
        self.isDragging = isDragging
        self.dragOffset = dragOffset
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconName(for: asset.type))
                .font(.title2)
                .foregroundColor(iconColor(for: asset.type))
                .frame(width: 24)
                .accessibilityHidden(true) // Icon is decorative, info is in text
            
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
        .opacity(isDragging ? 0.6 : 1.0)
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .offset(dragOffset)
        .shadow(radius: isDragging ? 8 : 0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    // Accessibility description
    private var accessibilityDescription: String {
        var description = "\(asset.name), \(asset.type.rawValue)"
        if let duration = asset.duration {
            description += ", duration \(formatDuration(duration))"
        }
        if isSelected {
            description += ", selected"
        }
        return description
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