import SwiftUI
import AVFoundation
import Combine

/// Manages multiple audio layers and their synchronization with the animation timeline
@MainActor
public class AudioLayerManager: ObservableObject {
    @Published public var audioLayers: [AudioLayer] = []
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0.0
    
    private var audioPlayers: [UUID: AVPlayer] = [:]
    private var timeObservers: [UUID: Any] = [:]
    private var animationController: AnimationController?
    
    public init() {}
    
    /// Set the animation controller for timeline synchronization
    public func setAnimationController(_ controller: AnimationController) {
        self.animationController = controller
    }
    
    /// Add an audio layer to the manager
    public func addAudioLayer(_ audioLayer: AudioLayer) {
        audioLayers.append(audioLayer)
        setupAudioPlayer(for: audioLayer)
    }
    
    /// Remove an audio layer from the manager
    public func removeAudioLayer(withId id: UUID) {
        // Clean up player and observer
        if let player = audioPlayers[id] {
            player.pause()
            if let observer = timeObservers[id] {
                player.removeTimeObserver(observer)
            }
        }
        audioPlayers.removeValue(forKey: id)
        timeObservers.removeValue(forKey: id)
        
        // Remove from layers
        audioLayers.removeAll { $0.id == id }
    }
    
    /// Update an existing audio layer
    public func updateAudioLayer(_ audioLayer: AudioLayer) {
        if let index = audioLayers.firstIndex(where: { $0.id == audioLayer.id }) {
            audioLayers[index] = audioLayer
            
            // Update player volume if needed
            if let player = audioPlayers[audioLayer.id] {
                player.volume = Float(audioLayer.isMuted ? 0.0 : audioLayer.volume)
            }
        }
    }
    
    /// Set up an audio player for a specific audio layer
    private func setupAudioPlayer(for audioLayer: AudioLayer) {
        let playerItem = AVPlayerItem(url: audioLayer.assetURL)
        let player = AVPlayer(playerItem: playerItem)
        player.volume = Float(audioLayer.isMuted ? 0.0 : audioLayer.volume)
        
        audioPlayers[audioLayer.id] = player
        
        // Add time observer for this player
        let timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.01, preferredTimescale: 600),
            queue: .main
        ) { _ in
            // This observer is mainly for individual player monitoring
            // Timeline synchronization is handled by seekToTime
        }
        
        timeObservers[audioLayer.id] = timeObserver
    }
    
    /// Start playback of all active audio layers
    public func play() {
        isPlaying = true
        
        for audioLayer in audioLayers {
            if audioLayer.shouldPlay(at: currentTime) {
                if let player = audioPlayers[audioLayer.id] {
                    let audioTime = audioLayer.audioTime(for: currentTime)
                    let cmTime = CMTime(seconds: audioTime, preferredTimescale: 600)
                    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    player.play()
                }
            }
        }
    }
    
    /// Pause playback of all audio layers
    public func pause() {
        isPlaying = false
        
        for player in audioPlayers.values {
            player.pause()
        }
    }
    
    /// Seek all audio layers to a specific timeline time
    public func seekToTime(_ timelineTime: TimeInterval) {
        currentTime = timelineTime
        
        for audioLayer in audioLayers {
            guard let player = audioPlayers[audioLayer.id] else { continue }
            
            if audioLayer.shouldPlay(at: timelineTime) {
                let audioTime = audioLayer.audioTime(for: timelineTime)
                let cmTime = CMTime(seconds: audioTime, preferredTimescale: 600)
                player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                
                // If we're playing, make sure this player is playing too
                if isPlaying && !audioLayer.isMuted {
                    player.play()
                }
            } else {
                // Audio shouldn't be playing at this time, pause it
                player.pause()
            }
        }
    }
    
    /// Get all audio layers that should be playing at a given time
    public func getActiveAudioLayers(at timelineTime: TimeInterval) -> [AudioLayer] {
        return audioLayers.filter { $0.shouldPlay(at: timelineTime) }
    }
    
    /// Clean up all audio players and observers
    public func cleanup() {
        for (id, player) in audioPlayers {
            player.pause()
            if let observer = timeObservers[id] {
                player.removeTimeObserver(observer)
            }
        }
        audioPlayers.removeAll()
        timeObservers.removeAll()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
}

/// Extension to integrate with AnimationController
extension AnimationController {
    /// Add audio layer manager support
    @MainActor
    public func setAudioLayerManager(_ manager: AudioLayerManager) {
        manager.setAnimationController(self)
        
        // Sync audio manager with animation controller state
        manager.currentTime = self.currentTime
        manager.isPlaying = self.isPlaying
    }
    
    /// Override play to include audio synchronization
    @MainActor
    public func playWithAudio(audioManager: AudioLayerManager) {
        audioManager.currentTime = self.currentTime
        audioManager.play()
        self.play()
    }
    
    /// Override pause to include audio synchronization
    @MainActor
    public func pauseWithAudio(audioManager: AudioLayerManager) {
        audioManager.pause()
        self.pause()
    }
    
    /// Override seek to include audio synchronization
    @MainActor
    public func seekToTimeWithAudio(_ time: TimeInterval, audioManager: AudioLayerManager) {
        self.seekToTime(time)
        audioManager.seekToTime(time)
    }
} 