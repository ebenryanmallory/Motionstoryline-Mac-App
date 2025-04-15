import SwiftUI
import AVFoundation
import Combine

/// AudioTrackState tracks the state of an individual audio track
public class AudioTrackState: ObservableObject, Identifiable {
    public let id: UUID
    public let name: String
    public let url: URL
    
    @Published var volume: Double = 1.0
    @Published var isMuted: Bool = false
    @Published var isSolo: Bool = false
    
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var statusObserver: AnyCancellable?
    
    public init(id: UUID, name: String, url: URL) {
        self.id = id
        self.name = name
        self.url = url
        setupPlayer()
    }
    
    private func setupPlayer() {
        player = AVPlayer(url: url)
        
        // Observe player status
        statusObserver = player?.publisher(for: \.status)
            .sink { [weak self] status in
                if status == .readyToPlay {
                    self?.player?.volume = Float(self?.isMuted ?? false ? 0.0 : self?.volume ?? 1.0)
                }
            }
    }
    
    public func play(from time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
    }
    
    public func pause() {
        player?.pause()
    }
    
    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    public func updateVolume() {
        if isMuted {
            player?.volume = 0.0
        } else {
            player?.volume = Float(volume)
        }
    }
    
    public func toggleMute() {
        isMuted.toggle()
        updateVolume()
    }
    
    public func toggleSolo() {
        isSolo.toggle()
    }
    
    deinit {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        statusObserver?.cancel()
        player = nil
    }
}

/// AudioTrackControlsManager handles multiple audio tracks and their playback
public class AudioTrackControlsManager: ObservableObject {
    @Published var trackStates: [AudioTrackState] = []
    @Published var currentTime: Double = 0.0
    @Published var isPlaying: Bool = false
    
    public init() {}
    
    public func addTrack(from mediaAsset: MediaAsset) {
        // Only add if not already in the list
        guard !trackStates.contains(where: { $0.id == mediaAsset.id }) else { return }
        let trackState = AudioTrackState(id: mediaAsset.id, name: mediaAsset.name, url: mediaAsset.url)
        trackStates.append(trackState)
    }
    
    public func removeTrack(id: UUID) {
        trackStates.removeAll { $0.id == id }
    }
    
    public func play() {
        // Apply solo logic - if any track is soloed, only play soloed tracks
        let hasSoloedTracks = trackStates.contains { $0.isSolo }
        
        for track in trackStates {
            if hasSoloedTracks {
                // If any track is soloed, only play the soloed tracks
                if track.isSolo {
                    track.play(from: currentTime)
                } else {
                    track.pause()
                }
            } else {
                // Otherwise play all tracks that aren't muted
                if !track.isMuted {
                    track.play(from: currentTime)
                }
            }
        }
        
        isPlaying = true
    }
    
    public func pause() {
        for track in trackStates {
            track.pause()
        }
        isPlaying = false
    }
    
    public func seek(to time: Double) {
        currentTime = time
        for track in trackStates {
            track.seek(to: time)
        }
    }
    
    public func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func toggleSolo(for trackId: UUID) {
        guard let index = trackStates.firstIndex(where: { $0.id == trackId }) else { return }
        trackStates[index].toggleSolo()
        
        // If we're playing, update which tracks should be heard
        if isPlaying {
            pause()
            play()
        }
    }
    
    public func toggleMute(for trackId: UUID) {
        guard let index = trackStates.firstIndex(where: { $0.id == trackId }) else { return }
        trackStates[index].toggleMute()
    }
    
    public func updateVolume(for trackId: UUID, volume: Double) {
        guard let index = trackStates.firstIndex(where: { $0.id == trackId }) else { return }
        trackStates[index].volume = volume
        trackStates[index].updateVolume()
    }
}

/// A view that provides controls for multiple audio tracks
public struct AudioTrackControlsView: View {
    @StateObject private var manager: AudioTrackControlsManager
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    
    public init(mediaAssets: [MediaAsset], currentTime: Binding<Double>, isPlaying: Binding<Bool>) {
        self._manager = StateObject(wrappedValue: AudioTrackControlsManager())
        self._currentTime = currentTime
        self._isPlaying = isPlaying
        
        // Filter for only audio assets
        let audioAssets = mediaAssets.filter { $0.type == .audio }
        
        // Add tracks to manager
        for asset in audioAssets {
            manager.addTrack(from: asset)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if manager.trackStates.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.trackStates) { track in
                            audioTrackControlRow(track)
                            Divider()
                        }
                    }
                }
            }
        }
        .onChange(of: currentTime) { newValue in
            manager.seek(to: newValue)
        }
        .onChange(of: isPlaying) { newValue in
            if newValue != manager.isPlaying {
                manager.isPlaying = newValue
                if newValue {
                    manager.play()
                } else {
                    manager.pause()
                }
            }
        }
        .onChange(of: manager.isPlaying) { newValue in
            isPlaying = newValue
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Audio Tracks")
                .font(.headline)
            
            Spacer()
            
            Button(action: {
                manager.togglePlayback()
            }) {
                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.borderless)
            .help(manager.isPlaying ? "Pause All Tracks" : "Play All Tracks")
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
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
    
    private func audioTrackControlRow(_ track: AudioTrackState) -> some View {
        VStack(spacing: 8) {
            HStack {
                // Track name
                Text(track.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                // Solo button
                Button(action: {
                    manager.toggleSolo(for: track.id)
                }) {
                    Image(systemName: track.isSolo ? "headphones.circle.fill" : "headphones.circle")
                        .foregroundColor(track.isSolo ? .yellow : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Solo")
                
                // Mute button
                Button(action: {
                    manager.toggleMute(for: track.id)
                }) {
                    Image(systemName: track.isMuted ? "speaker.slash.circle.fill" : "speaker.circle")
                        .foregroundColor(track.isMuted ? .red : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Mute")
            }
            
            // Volume slider
            HStack {
                Image(systemName: "speaker.wave.1")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Slider(
                    value: Binding(
                        get: { track.volume },
                        set: { newValue in
                            manager.updateVolume(for: track.id, volume: newValue)
                        }
                    ),
                    in: 0...1
                )
                .disabled(track.isMuted)
                
                Image(systemName: "speaker.wave.3")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("\(Int(track.volume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.1))
    }
}

// MARK: - Previews
struct AudioTrackControlsView_Previews: PreviewProvider {
    static var previews: some View {
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
        
        VStack {
            AudioTrackControlsView(
                mediaAssets: assets,
                currentTime: .constant(0.0),
                isPlaying: .constant(false)
            )
            .frame(width: 350, height: 300)
            .border(Color.gray, width: 0.5)
            
            Spacer()
                .frame(height: 20)
            
            AudioTrackControlsView(
                mediaAssets: [],
                currentTime: .constant(0.0),
                isPlaying: .constant(false)
            )
            .frame(width: 350, height: 200)
            .border(Color.gray, width: 0.5)
        }
        .padding()
    }
} 