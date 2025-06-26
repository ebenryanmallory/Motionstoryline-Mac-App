import SwiftUI
import Foundation

/// Manages timeline-related operations for the animation system
class TimelineManager: ObservableObject {
    @Published var timelineHeight: CGFloat
    @Published var timelineOffset: Double
    @Published var timelineScale: Double
    @Published var isPlaying: Bool = false
    
    private var animationController: AnimationController
    private var keyEventMonitor: Any?
    
    init(animationController: AnimationController, 
         timelineHeight: CGFloat = 120,
         timelineOffset: Double = 0.0,
         timelineScale: Double = 1.0) {
        self.animationController = animationController
        self.timelineHeight = timelineHeight
        self.timelineOffset = timelineOffset
        self.timelineScale = timelineScale
    }
    
    /// Toggle timeline playback state
    func toggleTimeline() {
        isPlaying.toggle()
        if isPlaying {
            animationController.play()
            // Provide play haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        } else {
            animationController.pause()
            // Provide pause haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
    }
    
    /// Add a new keyframe point at the specified time
    func addNewPoint(at time: Double, 
                    trackId: String, 
                    value: Any, 
                    easingFunction: EasingFunction = .linear) {
        
        // Handle different value types
        if let pointValue = value as? CGPoint {
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
                track.add(keyframe: Keyframe(time: time, value: pointValue, easingFunction: easingFunction))
            } else {
                // Create new track if it doesn't exist
                let track = animationController.addTrack(id: trackId) { (newValue: CGPoint) in }
                track.add(keyframe: Keyframe(time: time, value: pointValue, easingFunction: easingFunction))
            }
        } else if let doubleValue = value as? Double {
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Double> {
                track.add(keyframe: Keyframe(time: time, value: doubleValue, easingFunction: easingFunction))
            } else {
                let track = animationController.addTrack(id: trackId) { (newValue: Double) in }
                track.add(keyframe: Keyframe(time: time, value: doubleValue, easingFunction: easingFunction))
            }
        } else if let colorValue = value as? Color {
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Color> {
                track.add(keyframe: Keyframe(time: time, value: colorValue, easingFunction: easingFunction))
            } else {
                let track = animationController.addTrack(id: trackId) { (newValue: Color) in }
                track.add(keyframe: Keyframe(time: time, value: colorValue, easingFunction: easingFunction))
            }
        }
        
        // Provide haptic feedback for keyframe creation
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
    
    /// Delete a keyframe point at the specified time from a track
    func deletePoint(at time: Double, trackId: String) {
        // Try to find the track and delete the keyframe at the specified time
        if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
            track.removeKeyframe(at: time)
        } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Double> {
            track.removeKeyframe(at: time)
        } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Color> {
            track.removeKeyframe(at: time)
        }
        
        // Provide haptic feedback for keyframe deletion
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
    

    
    /// Get all keyframe times from all tracks in the animation controller
    func getAllKeyframeTimes() -> [Double] {
        var times: Set<Double> = []
        
        let tracks = animationController.getAllTracks()
        for trackId in tracks {
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGFloat> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Double> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Color> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<[CGPoint]> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        }
        
        return Array(times).sorted()
    }
    
    /// Find the next keyframe time after the specified time
    func findNextKeyframeTime(after time: Double) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes()
        return allKeyframeTimes.first { $0 > time }
    }
    
    /// Find the previous keyframe time before the specified time
    func findPreviousKeyframeTime(before time: Double) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes()
        return allKeyframeTimes.last { $0 < time }
    }
    
    /// Setup keyboard shortcuts for timeline navigation
    func setupTimelineKeyboardShortcuts(
        selectedElement: Binding<CanvasElement?>,
        selectedKeyframeTime: Binding<Double?>,
        onAddKeyframe: @escaping (Double) -> Void,
        onDeleteKeyframe: @escaping (Double) -> Void
    ) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Only process events if we have focus (not in a text field, etc.)
            guard !NSApp.isActive || !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            
            switch event.keyCode {
            // Left arrow key - move back by 0.1 seconds
            case 123:
                let newTime = max(0, animationController.currentTime - 0.1)
                animationController.seek(to: newTime)
                return nil // Consume the event
                
            // Right arrow key - move forward by 0.1 seconds
            case 124:
                let newTime = min(animationController.duration, animationController.currentTime + 0.1)
                animationController.seek(to: newTime)
                return nil // Consume the event
                
            // K key - add keyframe at current time
            case 40: // K key
                if selectedElement.wrappedValue != nil {
                    onAddKeyframe(animationController.currentTime)
                }
                return nil // Consume the event
                
            // Delete or Backspace key - delete selected keyframe
            case 51, 117: // Backspace or Delete
                if let time = selectedKeyframeTime.wrappedValue {
                    onDeleteKeyframe(time)
                    selectedKeyframeTime.wrappedValue = nil
                }
                return nil // Consume the event
                
            // Tab key - jump to next keyframe
            case 48: // Tab
                if let nextKeyframeTime = self.findNextKeyframeTime(after: animationController.currentTime) {
                    animationController.seek(to: nextKeyframeTime)
                }
                return nil // Consume the event
                
            // Shift + Tab key - jump to previous keyframe
            case 48 where event.modifierFlags.contains(.shift): // Shift+Tab
                if let prevKeyframeTime = self.findPreviousKeyframeTime(before: animationController.currentTime) {
                    animationController.seek(to: prevKeyframeTime)
                }
                return nil // Consume the event
                
            // P key - toggle playback
            case 35: // P key
                self.toggleTimeline()
                return nil // Consume the event
                
            // Home key - go to beginning of timeline
            case 115: // Home
                animationController.seek(to: 0)
                return nil // Consume the event
                
            // End key - go to end of timeline
            case 119: // End
                animationController.seek(to: animationController.duration)
                return nil // Consume the event
                
            default:
                break
            }
            
            return event
        }
    }
    
    deinit {
        if let keyEventMonitor = keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
        }
    }
} 