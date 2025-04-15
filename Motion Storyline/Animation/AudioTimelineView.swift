import SwiftUI
import AVFoundation
import Combine

/// A specialized timeline view for displaying audio tracks with waveform visualization
public struct AudioTimelineView: View {
    @ObservedObject var animationController: AnimationController
    let audioURL: URL
    let audioTrackId: String
    @Binding var currentTime: Double
    let scale: Double
    @Binding var offset: Double
    
    // Audio playback state
    @State private var isPlaying: Bool = false
    @State private var audioPlayer: AVPlayer?
    @State private var audioDuration: Double = 0.0
    @State private var timeObserver: Any?
    
    // Audio marker state
    @StateObject private var markerManager: AudioMarkerManager
    @State private var isAddingMarkers: Bool = false
    @State private var showMarkerOptions: Bool = false
    @State private var selectedPropertyForKeyframes: String? = nil
    @State private var selectedPropertyType: AnimatableProperty.PropertyType = .position
    
    public init(
        animationController: AnimationController,
        audioURL: URL,
        audioTrackId: String,
        currentTime: Binding<Double>,
        scale: Double,
        offset: Binding<Double>,
        markerManager: AudioMarkerManager? = nil
    ) {
        self.animationController = animationController
        self.audioURL = audioURL
        self.audioTrackId = audioTrackId
        self._currentTime = currentTime
        self.scale = scale
        self._offset = offset
        
        // Use provided marker manager or create a new one
        if let markerManager = markerManager {
            self._markerManager = StateObject(wrappedValue: markerManager)
        } else {
            self._markerManager = StateObject(wrappedValue: AudioMarkerManager(animationController: animationController))
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Audio track header
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.secondary)
                
                Text(audioURL.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Marker tools toggle
                Button(action: {
                    isAddingMarkers.toggle()
                }) {
                    Image(systemName: isAddingMarkers ? "pin.fill" : "pin")
                        .foregroundColor(isAddingMarkers ? .orange : .blue)
                }
                .buttonStyle(.borderless)
                .help(isAddingMarkers ? "Exit marker mode" : "Add beat markers")
                
                // Create keyframes from markers button
                Button(action: {
                    showMarkerOptions = true
                }) {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .help("Create keyframes from markers")
                .disabled(markerManager.markers.isEmpty)
                .popover(isPresented: $showMarkerOptions) {
                    KeyframeGenerationOptions(
                        animationController: animationController,
                        markerManager: markerManager,
                        selectedProperty: $selectedPropertyForKeyframes,
                        selectedPropertyType: $selectedPropertyType
                    )
                    .frame(width: 280, height: 200)
                    .padding()
                }
                
                // Standard playback controls
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .help(isPlaying ? "Pause audio" : "Play audio")
                
                Button(action: {
                    resetPlayback()
                }) {
                    Image(systemName: "backward.end.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                .help("Reset playback to beginning")
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Audio waveform with timeline
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.2))
                    
                    // Waveform visualization
                    AudioWaveformView(
                        audioURL: audioURL,
                        waveformColor: Color.blue.opacity(0.7),
                        backgroundColor: .clear,
                        showRuler: false,
                        showPlaybackControls: true
                    )
                    .frame(height: geometry.size.height)
                    
                    // Display markers
                    AudioMarkerView(
                        markerManager: markerManager,
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
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            if isAddingMarkers {
                                // Add a marker at the current time
                                markerManager.addMarker(at: currentTime, label: "Marker \(markerManager.markers.count + 1)")
                                // Provide haptic feedback
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isAddingMarkers {
                                let newTime = positionToTime(value.location.x, width: geometry.size.width)
                                currentTime = max(0, min(animationController.duration, newTime))
                                // Update animation timeline as well
                                animationController.currentTime = currentTime
                                seekAudio(to: currentTime)
                            }
                        }
                )
                .onAppear {
                    // Load existing markers if available
                    loadMarkersIfNeeded()
                }
            }
        }
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            cleanupAudioPlayer()
        }
    }
    
    // Set up audio player and time observer
    private func setupAudioPlayer() {
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Get audio duration
        let asset = AVAsset(url: audioURL)
        Task {
            do {
                audioDuration = try await asset.load(.duration).seconds
            } catch {
                audioDuration = animationController.duration
            }
        }
        
        // Add time observer to sync audio with animation
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: 600), queue: .main) { time in
            guard isPlaying else { return }
            
            // Update animation controller time from audio playback
            let seconds = time.seconds
            if seconds <= animationController.duration {
                self.currentTime = seconds
            } else {
                // Stop if we've reached the end
                self.isPlaying = false
                resetPlayback()
            }
        }
    }
    
    private func cleanupAudioPlayer() {
        if let timeObserver = timeObserver {
            audioPlayer?.removeTimeObserver(timeObserver)
        }
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            // Make sure we're at the right position
            seekAudio(to: currentTime)
            audioPlayer?.play()
        }
        isPlaying.toggle()
    }
    
    private func resetPlayback() {
        audioPlayer?.pause()
        isPlaying = false
        currentTime = 0
        seekAudio(to: 0)
    }
    
    private func seekAudio(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // Convert time to position in the timeline
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(((time - offset) * scale / animationController.duration) * Double(width))
    }
    
    // Convert position to time in the timeline
    private func positionToTime(_ position: CGFloat, width: CGFloat) -> Double {
        return (Double(position) / Double(width)) * (animationController.duration / scale) + offset
    }
    
    // Load markers from the animation controller if available
    private func loadMarkersIfNeeded() {
        // This would typically load markers from saved state
        // For now, we're just initializing with empty markers
    }
}

/// A view for selecting which property to create keyframes for from markers
struct KeyframeGenerationOptions: View {
    let animationController: AnimationController
    let markerManager: AudioMarkerManager
    @Binding var selectedProperty: String?
    @Binding var selectedPropertyType: AnimatableProperty.PropertyType
    @State private var keyframeInterpolation: EasingFunction = .linear
    @State private var feedbackMessage: String = ""
    @State private var showingFeedback: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Keyframes from Markers")
                .font(.headline)
            
            Divider()
            
            // Property selection
            VStack(alignment: .leading) {
                Text("Select Property:").font(.subheadline)
                
                Picker("Property", selection: $selectedProperty) {
                    Text("Select a property").tag(nil as String?)
                    
                    ForEach(animationController.getAllTracks(), id: \.self) { trackId in
                        Text(trackId).tag(trackId as String?)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            
            // Property type selection
            VStack(alignment: .leading) {
                Text("Property Type:").font(.subheadline)
                
                Picker("Type", selection: $selectedPropertyType) {
                    Text("Position").tag(AnimatableProperty.PropertyType.position)
                    Text("Size").tag(AnimatableProperty.PropertyType.size)
                    Text("Rotation").tag(AnimatableProperty.PropertyType.rotation)
                    Text("Color").tag(AnimatableProperty.PropertyType.color)
                    Text("Opacity").tag(AnimatableProperty.PropertyType.opacity)
                    Text("Scale").tag(AnimatableProperty.PropertyType.scale)
                    Text("Path").tag(AnimatableProperty.PropertyType.path)
                    Text("Custom").tag(AnimatableProperty.PropertyType.custom(valueType: [CGPoint].self))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            // Interpolation type
            VStack(alignment: .leading) {
                Text("Interpolation:").font(.subheadline)
                
                Picker("Interpolation", selection: $keyframeInterpolation) {
                    Text("Linear").tag(EasingFunction.linear)
                    Text("Ease In").tag(EasingFunction.easeIn)
                    Text("Ease Out").tag(EasingFunction.easeOut)
                    Text("Ease In/Out").tag(EasingFunction.easeInOut)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Spacer()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    selectedProperty = nil
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button("Create Keyframes") {
                    createKeyframes()
                }
                .buttonStyle(.bordered)
                .disabled(selectedProperty == nil)
            }
            
            // Feedback message
            if showingFeedback {
                Text(feedbackMessage)
                    .font(.caption)
                    .foregroundColor(feedbackMessage.contains("Error") ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }
    
    private func createKeyframes() {
        guard let propertyId = selectedProperty else { return }
        
        let count = markerManager.createKeyframesFromMarkers(
            propertyId: propertyId,
            propertyType: selectedPropertyType,
            interpolationType: keyframeInterpolation
        )
        
        // Show feedback
        feedbackMessage = count > 0 ? "Created \(count) keyframes" : "Error: No keyframes created"
        showingFeedback = true
        
        // Hide feedback after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingFeedback = false
        }
        
        // Provide haptic feedback
        if count > 0 {
            // Success feedback - use a success pattern
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } else {
            // Error feedback - use a warning pattern
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
        }
    }
}

// MARK: - Preview
struct AudioTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        
        return AudioTimelineView(
            animationController: animationController,
            audioURL: URL(string: "file:///nonexistent.mp3")!,
            audioTrackId: "audio1",
            currentTime: .constant(0.0),
            scale: 1.0,
            offset: .constant(0.0)
        )
        .frame(height: 120)
        .padding()
    }
} 