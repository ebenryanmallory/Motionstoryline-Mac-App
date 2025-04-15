import SwiftUI
import AVFoundation

/// A view that displays multiple audio tracks with waveforms and controls
public struct MultiTrackAudioTimelineView: View {
    @ObservedObject var animationController: AnimationController
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    let scale: Double
    @Binding var offset: Double
    let audioAssets: [MediaAsset]
    @State private var selectedAudioTracks: Set<UUID> = []
    @State private var showAudioControls: Bool = false
    @State private var audioMarkerManager: AudioMarkerManager
    
    public init(
        animationController: AnimationController,
        currentTime: Binding<Double>,
        isPlaying: Binding<Bool>,
        scale: Double,
        offset: Binding<Double>,
        audioAssets: [MediaAsset],
        markerManager: AudioMarkerManager? = nil
    ) {
        self.animationController = animationController
        self._currentTime = currentTime
        self._isPlaying = isPlaying
        self.scale = scale
        self._offset = offset
        self.audioAssets = audioAssets.filter { $0.type == .audio }
        
        // Use provided marker manager or create new one
        if let manager = markerManager {
            self._audioMarkerManager = State(initialValue: manager)
        } else {
            self._audioMarkerManager = State(initialValue: AudioMarkerManager(animationController: animationController))
        }
        
        // Initially select all audio tracks
        let initialSelection = Set(audioAssets.filter { $0.type == .audio }.map { $0.id })
        self._selectedAudioTracks = State(initialValue: initialSelection)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView
            
            if audioAssets.filter({ $0.type == .audio }).isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // Audio tracks with waveforms
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(audioAssets.filter { $0.type == .audio && selectedAudioTracks.contains($0.id) }) { asset in
                                audioTrackRow(asset)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Divider before controls
                    Divider()
                    
                    // Expandable audio track controls
                    if showAudioControls {
                        AudioTrackControlsView(
                            mediaAssets: audioAssets,
                            currentTime: $currentTime,
                            isPlaying: $isPlaying
                        )
                        .frame(height: 200)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Audio Tracks")
                .font(.headline)
            
            Spacer()
            
            // Button to show track selector
            Menu {
                ForEach(audioAssets.filter { $0.type == .audio }) { asset in
                    Toggle(asset.name, isOn: Binding(
                        get: { selectedAudioTracks.contains(asset.id) },
                        set: { newValue in
                            if newValue {
                                selectedAudioTracks.insert(asset.id)
                            } else {
                                selectedAudioTracks.remove(asset.id)
                            }
                        }
                    ))
                }
                
                Divider()
                
                Button("Select All") {
                    selectedAudioTracks = Set(audioAssets.filter { $0.type == .audio }.map { $0.id })
                }
                
                Button("Deselect All") {
                    selectedAudioTracks.removeAll()
                }
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundColor(.blue)
            }
            .menuStyle(.borderlessButton)
            .help("Select audio tracks to display")
            
            // Toggle audio controls
            Button(action: {
                withAnimation {
                    showAudioControls.toggle()
                }
            }) {
                Image(systemName: showAudioControls ? "slider.horizontal.below.rectangle" : "slider.horizontal.3")
                    .foregroundColor(showAudioControls ? .blue : .primary)
            }
            .buttonStyle(.borderless)
            .help(showAudioControls ? "Hide audio controls" : "Show audio controls")
            
            // Add marker button
            Button(action: {
                audioMarkerManager.addMarker(at: currentTime, label: "Marker \(audioMarkerManager.markers.count + 1)")
                // Provide haptic feedback
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            }) {
                Image(systemName: "pin")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
            .help("Add marker at current time")
            
            // Create keyframes from markers
            Menu {
                Button("Position") {
                    createKeyframesFromMarkers(propertyType: .position)
                }
                Button("Scale") {
                    createKeyframesFromMarkers(propertyType: .scale)
                }
                Button("Rotation") {
                    createKeyframesFromMarkers(propertyType: .rotation)
                }
                Button("Opacity") {
                    createKeyframesFromMarkers(propertyType: .opacity)
                }
                
                Divider()
                
                Button("Delete All Markers") {
                    audioMarkerManager.clearMarkers()
                }
            } label: {
                Image(systemName: "key")
                    .foregroundColor(.blue)
            }
            .menuStyle(.borderlessButton)
            .help("Create keyframes from markers")
            .disabled(audioMarkerManager.markers.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            
            Text("No Audio Tracks")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Import audio files through the Media Browser")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
    
    private func audioTrackRow(_ asset: MediaAsset) -> some View {
        VStack(spacing: 0) {
            // Track header
            HStack {
                Text(asset.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                if let duration = asset.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Track waveform
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.2))
                    
                    // Waveform visualization
                    AudioWaveformView(
                        audioURL: asset.url,
                        waveformColor: Color.blue.opacity(0.7),
                        backgroundColor: .clear,
                        showRuler: false,
                        showPlaybackControls: true
                    )
                    .frame(height: geometry.size.height)
                    
                    // Display markers from the marker manager
                    AudioMarkerView(
                        markerManager: audioMarkerManager,
                        scale: scale,
                        offset: $offset,
                        trackHeight: geometry.size.height
                    )
                    
                    // Playhead
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: timeToPosition(currentTime, width: geometry.size.width), y: geometry.size.height / 2)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
            }
            .frame(height: 60)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.05))
        .cornerRadius(4)
    }
    
    // Helper to convert time to position
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        let scaledTime = time * scale
        let adjustedPosition = CGFloat(scaledTime - offset)
        return adjustedPosition
    }
    
    // Helper to format duration
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Create keyframes from markers for selected properties
    private func createKeyframesFromMarkers(propertyType: AnimatableProperty.PropertyType) {
        // Get selected elements from the animation controller
        guard let selectedPropertyId = getFirstPropertyIdOfType(propertyType) else { return }
        
        let interpolationType = EasingFunction.linear
        let count = audioMarkerManager.createKeyframesFromMarkers(
            propertyId: selectedPropertyId,
            propertyType: propertyType,
            interpolationType: interpolationType
        )
        
        // Provide haptic feedback if keyframes were created
        if count > 0 {
            // Success feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } else {
            // Error feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }
    
    // Find the first property ID of the given type
    private func getFirstPropertyIdOfType(_ propertyType: AnimatableProperty.PropertyType) -> String? {
        for trackId in animationController.getAllTracks() {
            // Check if this is a track of the type we're looking for
            switch propertyType {
            case .position:
                if animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> != nil {
                    return trackId
                }
            case .scale, .rotation, .opacity:
                if animationController.getTrack(id: trackId) as? KeyframeTrack<CGFloat> != nil {
                    return trackId
                }
            case .color:
                if animationController.getTrack(id: trackId) as? KeyframeTrack<Color> != nil {
                    return trackId
                }
            case .path:
                if animationController.getTrack(id: trackId) as? KeyframeTrack<[CGPoint]> != nil {
                    return trackId
                }
            default:
                // Handle any future property types that might be added
                continue
            }
        }
        return nil
    }
}

// MARK: - Preview
struct MultiTrackAudioTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample animation controller
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Sample tracks
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        
        // Sample audio assets
        let assets: [MediaAsset] = [
            MediaAsset(
                name: "Background Music",
                type: .audio,
                url: URL(string: "file:///music.mp3")!,
                duration: 120.5
            ),
            MediaAsset(
                name: "Voice Over",
                type: .audio,
                url: URL(string: "file:///voice.mp3")!,
                duration: 45.2
            ),
            MediaAsset(
                name: "Sound Effects",
                type: .audio,
                url: URL(string: "file:///sfx.mp3")!,
                duration: 10.0
            )
        ]
        
        return VStack {
            // With tracks
            MultiTrackAudioTimelineView(
                animationController: animationController,
                currentTime: .constant(1.5),
                isPlaying: .constant(false),
                scale: 1.0,
                offset: .constant(0.0),
                audioAssets: assets
            )
            .frame(height: 300)
            .border(Color.gray, width: 0.5)
            
            // Empty state
            MultiTrackAudioTimelineView(
                animationController: animationController,
                currentTime: .constant(1.5),
                isPlaying: .constant(false),
                scale: 1.0,
                offset: .constant(0.0),
                audioAssets: []
            )
            .frame(height: 150)
            .border(Color.gray, width: 0.5)
        }
        .padding()
    }
} 