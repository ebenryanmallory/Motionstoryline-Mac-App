import SwiftUI
import AppKit
import Combine
import Foundation

/// A view that displays a timeline with keyframes for a specific property
struct AnimationTimelineView: View {
    @ObservedObject var animationController: AnimationController
    let propertyId: String
    let propertyType: AnimatableProperty.PropertyType
    @Binding var selectedKeyframeTime: Double?
    @Binding var newKeyframeTime: Double
    @Binding var isAddingKeyframe: Bool
    @State var timelineScale: Double = 1.0
    @Binding var timelineOffset: Double
    var onAddKeyframe: (Double) -> Void
    
    // Audio options
    var audioURL: URL?  // For single track backward compatibility
    var showAudioWaveform: Bool = false
    var mediaAssets: [MediaAsset] = []  // For multiple audio tracks
    var audioLayerManager: AudioLayerManager? // New audio layer system
    @State private var showMultiTrackAudio: Bool = false
    @State private var showAudioMarkerTooltip: Bool = false
    @State private var audioMarkerManager: AudioMarkerManager?
    @State private var isPlaying: Bool = false
    
    // State for handling timeline height
    @State private var timelineHeight: CGFloat = 120
    
    // Computed property for keyframe times to pass to TimelineRuler
    private var keyframeTimes: [Double] {
        var times: Set<Double> = []
        
        // Focus on just getting keyframes for the current property
        switch propertyType {
        case .position:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGPoint> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        case .size:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGFloat> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        case .rotation:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        case .opacity:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        case .color:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Color> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        case .path:
            if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<[CGPoint]> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        default:
            break
        }
        
        return Array(times).sorted()
    }
    
    // Get audio marker times if available
    private var audioMarkerTimes: [Double] {
        audioMarkerManager?.markers.map { $0.time } ?? []
    }
    
    // Resize handle component for the timeline
    private var resizeHandle: some View {
        ZStack {
            // Background line/divider
            Divider()
            
            // Visual handle indicator
            HStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 20, height: 3)
                }
            }
            
            // Invisible hit area for the gesture
            Color.clear
                .contentShape(Rectangle())
                .frame(height: 12) // Larger hit area
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Calculate new height based on drag
                            let proposedHeight = timelineHeight - value.translation.height
                            
                            // Enforce constraints (min: 70, max: 400)
                            timelineHeight = min(400, max(70, proposedHeight))
                        }
                )
                .onHover { isHovering in
                    // Change cursor to vertical resize cursor when hovering
                    if isHovering {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
        .frame(height: 12)
        .padding(.vertical, 1)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Add resize handle at the top of the timeline
            resizeHandle
            
            // Timeline ruler
            TimelineRuler(
                duration: animationController.duration,
                currentTime: $animationController.currentTime,
                scale: timelineScale,
                offset: $timelineOffset,
                keyframeTimes: keyframeTimes,  // Pass keyframe times for snapping
                audioMarkerTimes: audioMarkerTimes  // Pass audio marker times
            )
            .frame(height: 30)
            
            // Keyframe timeline
            KeyframeTimelineView(
                animationController: animationController,
                propertyId: propertyId,
                propertyType: propertyType,
                currentTime: $animationController.currentTime,
                selectedKeyframeTime: $selectedKeyframeTime,
                newKeyframeTime: $newKeyframeTime,
                isAddingKeyframe: $isAddingKeyframe,
                scale: timelineScale,
                offset: $timelineOffset,
                onAddKeyframe: onAddKeyframe
            )
            .frame(height: timelineHeight - 70) // Adjust dynamically based on available space
            
            // Show audio layers if available
            if let audioLayerManager = audioLayerManager, !audioLayerManager.audioLayers.isEmpty {
                Divider()
                
                AudioLayerTimelineView(
                    audioLayerManager: audioLayerManager,
                    currentTime: $animationController.currentTime,
                    isPlaying: $isPlaying,
                    scale: timelineScale,
                    offset: $timelineOffset,
                    timelineDuration: animationController.duration
                )
                .frame(minHeight: 120, maxHeight: 300)
            }
            
            // Decide which audio visualization to show based on available data
            else if !mediaAssets.filter({ $0.type == .audio }).isEmpty && showMultiTrackAudio {
                // Show multi-track audio timeline
                Divider()
                
                MultiTrackAudioTimelineView(
                    animationController: animationController,
                    currentTime: $animationController.currentTime,
                    isPlaying: $isPlaying,
                    scale: timelineScale,
                    offset: $timelineOffset,
                    audioAssets: mediaAssets,
                    markerManager: audioMarkerManager
                )
                .frame(minHeight: 200, maxHeight: 400)
                .onAppear {
                    // Initialize audio marker manager if needed
                    if audioMarkerManager == nil {
                        audioMarkerManager = AudioMarkerManager(animationController: animationController)
                    }
                }
            } else if let audioURL = audioURL, showAudioWaveform {
                // Legacy single-track audio timeline (for backward compatibility)
                Divider()
                
                VStack(spacing: 0) {
                    if showAudioMarkerTooltip {
                        Text("Click the pin icon to add markers for audio beats, then use the key icon to create keyframes at those markers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                            .onAppear {
                                // Auto-dismiss after 6 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                                    showAudioMarkerTooltip = false
                                }
                            }
                    }
                    
                    AudioTimelineView(
                        animationController: animationController,
                        audioURL: audioURL,
                        audioTrackId: "audio_\(propertyId)",
                        currentTime: $animationController.currentTime,
                        scale: timelineScale,
                        offset: $timelineOffset,
                        markerManager: audioMarkerManager
                    )
                    .frame(height: 100)
                    .onAppear {
                        // Initialize audio marker manager if needed
                        if audioMarkerManager == nil {
                            audioMarkerManager = AudioMarkerManager(animationController: animationController)
                        }
                        
                        // Show the tooltip the first time audio is added
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            showAudioMarkerTooltip = true
                        }
                    }
                }
            }
        }
        // If we have audio assets, add a button to toggle multi-track audio view
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Show audio layer indicator if we have audio layers
                if let audioLayerManager = audioLayerManager, !audioLayerManager.audioLayers.isEmpty {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundColor(.blue)
                        Text("\(audioLayerManager.audioLayers.count)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .help("Audio Layers: \(audioLayerManager.audioLayers.count)")
                }
                
                if !mediaAssets.filter({ $0.type == .audio }).isEmpty {
                    Button(action: {
                        withAnimation {
                            showMultiTrackAudio.toggle()
                        }
                    }) {
                        Image(systemName: showMultiTrackAudio ? "waveform.circle.fill" : "waveform.circle")
                    }
                    .help(showMultiTrackAudio ? "Hide Audio Tracks" : "Show Audio Tracks")
                }
                
                // Add play/pause button
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        animationController.play()
                    } else {
                        animationController.pause()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle" : "play.circle")
                }
                .help(isPlaying ? "Pause" : "Play")
            }
        }
        .onAppear {
            // Set up synchronization with the animation controller's playback state
            isPlaying = animationController.isPlaying
        }
        .onChange(of: animationController.isPlaying) { oldValue, newIsPlaying in
            // Keep our local isPlaying in sync with the controller
            if isPlaying != newIsPlaying {
                isPlaying = newIsPlaying
            }
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            if newValue {
                // Start animation playback
                animationController.play()
                // Update audio synchronization by seeking to current time
                let currentTime = animationController.currentTime
                animationController.seekToTime(currentTime)
                
                // Start audio layer playback if available
                if let audioLayerManager = audioLayerManager {
                    audioLayerManager.currentTime = currentTime
                    audioLayerManager.play()
                }
            } else {
                // Pause animation playback
                animationController.pause()
                
                // Pause audio layer playback if available
                audioLayerManager?.pause()
            }
        }
        .onChange(of: animationController.currentTime) { oldValue, newTime in
            // Ensure the animation time is synchronized with audio time
            if !isPlaying && abs(newTime - animationController.currentTime) > 0.01 {
                animationController.seekToTime(newTime)
            }
            
            // Sync audio layers with timeline
            audioLayerManager?.seekToTime(newTime)
        }
        // Force the view to update when the property ID changes or when keyframes are added/removed
        .id("\(propertyId)_\(keyframeTimes.count)")
    }
}

#if !DISABLE_PREVIEWS
struct AnimationTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample animation controller for the preview
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Add some sample keyframes
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 300)))
        
        // Create a marker manager for the preview
        let markerManager = AudioMarkerManager(animationController: animationController)
        markerManager.addMarker(at: 1.0, label: "Beat 1")
        markerManager.addMarker(at: 3.0, label: "Beat 2", color: .orange)
        
        // Sample audio assets
        let audioAssets: [MediaAsset] = [
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
        
        return VStack(spacing: 20) {
            // Standard timeline
            AnimationTimelineView(
                animationController: animationController,
                propertyId: "position",
                propertyType: .position,
                selectedKeyframeTime: .constant(nil),
                newKeyframeTime: .constant(0.0),
                isAddingKeyframe: .constant(false),
                timelineOffset: .constant(0.0),
                onAddKeyframe: { _ in }
            )
            .frame(height: 120)
            
            // Timeline with single audio track (legacy)
            AnimationTimelineView(
                animationController: animationController,
                propertyId: "position",
                propertyType: .position,
                selectedKeyframeTime: .constant(nil),
                newKeyframeTime: .constant(0.0),
                isAddingKeyframe: .constant(false),
                timelineOffset: .constant(0.0),
                onAddKeyframe: { _ in },
                audioURL: URL(string: "file:///nonexistent.mp3"),
                showAudioWaveform: true
            )
            .frame(height: 220)
            
            // Timeline with multiple audio tracks
            AnimationTimelineView(
                animationController: animationController,
                propertyId: "position",
                propertyType: .position,
                selectedKeyframeTime: .constant(nil),
                newKeyframeTime: .constant(0.0),
                isAddingKeyframe: .constant(false),
                timelineOffset: .constant(0.0),
                onAddKeyframe: { _ in },
                mediaAssets: audioAssets
            )
            .frame(height: 400)
        }
        .padding()
    }
}
#endif 