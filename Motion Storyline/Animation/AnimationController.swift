import SwiftUI

/// Controls the animation playback state and timing
public class AnimationController: ObservableObject {
    /// Current playback position in seconds
    @Published var currentTime: Double = 0.0
    
    /// Total animation duration in seconds
    @Published var duration: Double = 5.0
    
    private var timer: Timer?
    private var lastUpdateTime: Date?
    
    /// Set up the animation controller with a specific duration
    /// - Parameter duration: The animation duration in seconds
    public func setup(duration: Double) {
        self.duration = duration
        self.currentTime = 0.0
    }
    
    /// Start animation playback
    public func play() {
        // Stop any existing timer
        timer?.invalidate()
        
        // Record the current time for accurate timing
        lastUpdateTime = Date()
        
        // Create a new timer that fires 60 times per second
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Calculate elapsed time since last update
            let now = Date()
            if let lastUpdate = self.lastUpdateTime {
                let elapsed = now.timeIntervalSince(lastUpdate)
                self.lastUpdateTime = now
                
                // Update the current time
                self.currentTime += elapsed
                
                // Loop back to the beginning if we reach the end
                if self.currentTime >= self.duration {
                    self.currentTime = 0.0
                }
            }
        }
    }
    
    /// Pause animation playback
    public func pause() {
        timer?.invalidate()
        timer = nil
        lastUpdateTime = nil
    }
    
    /// Reset animation to beginning
    public func reset() {
        pause()
        currentTime = 0.0
    }
    
    deinit {
        timer?.invalidate()
    }
} 