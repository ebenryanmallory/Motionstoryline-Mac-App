import SwiftUI
import Combine
import AppKit

/// A controller class to monitor keyboard events for the canvas
class KeyEventMonitorController: ObservableObject {
    private var keyEventMonitor: Any?
    
    func setupMonitor(onSpaceDown: @escaping () -> Void, onSpaceUp: @escaping () -> Void) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // Check for space bar
            if event.keyCode == 49 { // 49 is the keycode for space
                if event.type == .keyDown {
                    onSpaceDown()
                } else if event.type == .keyUp {
                    onSpaceUp()
                }
            }
            
            return event
        }
    }
    
    func teardownMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    deinit {
        teardownMonitor()
    }
}

// MARK: - Timeline Keyboard Shortcuts Extension
extension KeyEventMonitorController {
    /// Setup keyboard shortcuts for timeline navigation and keyframe manipulation
    func setupTimelineKeyboardShortcuts(
        animationController: AnimationController,
        selectedElement: CanvasElement?,
        selectedKeyframeTime: Binding<Double?>,
        onAddKeyframe: @escaping (Double) -> Void,
        onDeleteKeyframe: @escaping (Double) -> Void
    ) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak animationController, weak self] event in
            guard let animationController = animationController, let self = self else { return event }
            
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
                if selectedElement != nil {
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
                if let nextKeyframeTime = self.findNextKeyframeTime(after: animationController.currentTime, in: animationController) {
                    animationController.seek(to: nextKeyframeTime)
                }
                return nil // Consume the event
                
            // Shift + Tab key - jump to previous keyframe
            case 48 where event.modifierFlags.contains(.shift): // Shift+Tab
                if let prevKeyframeTime = self.findPreviousKeyframeTime(before: animationController.currentTime, in: animationController) {
                    animationController.seek(to: prevKeyframeTime)
                }
                return nil // Consume the event
                
            // P key - toggle playback (changed from space)
            case 35: // P key
                if animationController.isPlaying {
                    animationController.pause()
                } else {
                    animationController.play()
                }
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
    
    /// Find the next keyframe time after the specified time
    private func findNextKeyframeTime(after time: Double, in animationController: AnimationController) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes(from: animationController)
        return allKeyframeTimes.first { $0 > time }
    }
    
    /// Find the previous keyframe time before the specified time
    private func findPreviousKeyframeTime(before time: Double, in animationController: AnimationController) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes(from: animationController)
        return allKeyframeTimes.last { $0 < time }
    }
    
    /// Get all keyframe times from all tracks in the animation controller
    private func getAllKeyframeTimes(from animationController: AnimationController) -> [Double] {
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
}

// MARK: - Canvas Keyboard Shortcuts Extension
extension KeyEventMonitorController {
    /// Setup keyboard shortcuts for common canvas operations
    func setupCanvasKeyboardShortcuts(
        zoomIn: @escaping () -> Void,
        zoomOut: @escaping () -> Void,
        resetZoom: @escaping () -> Void,
        saveProject: @escaping () -> Void
    ) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Only process events if we have focus (not in a text field, etc.)
            guard !NSApp.isActive || !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            
            // Check for Command key (or Command+Shift for some shortcuts)
            let isCommandPressed = event.modifierFlags.contains(.command)
            
            if isCommandPressed {
                switch event.keyCode {
                // Plus key (Command+Plus: Zoom In)
                case 24: // Equal/Plus key
                    zoomIn()
                    return nil // Consume the event
                    
                // Minus key (Command+Minus: Zoom Out)  
                case 27: // Minus key
                    zoomOut()
                    return nil // Consume the event
                    
                // 0 key (Command+0: Reset Zoom)
                case 29: // 0 key
                    resetZoom()
                    return nil // Consume the event

                // S key (Command+S: Save Project)
                case 1: // S key
                    saveProject()
                    return nil // Consume the event
                    
                default:
                    break
                }
            }
            
            return event
        }
    }
} 