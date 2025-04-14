import SwiftUI
import AppKit

/// Ruler component for the timeline
struct TimelineRuler: View {
    let duration: Double
    @Binding var currentTime: Double
    let scale: Double
    @Binding var offset: Double
    let keyframeTimes: [Double]
    
    // Snap threshold in seconds
    private let snapThreshold: Double = 0.1
    
    // Convert time to position in the timeline
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(((time - offset) * scale / duration) * Double(width))
    }
    
    /// Convert position to time in the timeline
    private func positionToTime(_ position: CGFloat, width: CGFloat) -> Double {
        return (Double(position) / Double(width)) * (duration / scale) + offset
    }
    
    /// Snap to the closest significant time point (keyframe, whole second, or half second)
    private func snapToClosestTimePoint(_ time: Double) -> Double {
        // Points to snap to: keyframes, whole seconds, half seconds
        var snapPoints = keyframeTimes
        
        // Add whole and half second points
        for i in 0...Int(duration * 2) {
            let tickTime = Double(i) / 2.0
            if tickTime <= duration {
                snapPoints.append(tickTime)
            }
        }
        
        // Find the closest snap point
        if let closestPoint = snapPoints.min(by: { abs($0 - time) < abs($1 - time) }) {
            // Snap only if we're within threshold
            if abs(closestPoint - time) <= snapThreshold / scale {
                return closestPoint
            }
        }
        
        // If no snap point is close enough, return the original time
        return time
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                
                // Time markers
                ForEach(0...Int(duration * 2), id: \.self) { i in
                    let tickTime = Double(i) / 2.0
                    if tickTime <= duration {
                        let x = timeToPosition(tickTime, width: geometry.size.width)
                        let isWholeSec = i % 2 == 0
                        
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: isWholeSec ? 1 : 0.5, height: isWholeSec ? 10 : 5)
                            .position(x: x, y: isWholeSec ? 10 : 8)
                    }
                }
                
                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 30)
                    .position(x: timeToPosition(currentTime, width: geometry.size.width), y: 15)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newTime = positionToTime(value.location.x, width: geometry.size.width)
                        currentTime = max(0, min(duration, newTime))
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Pan/zoom functionality could be added here
                    }
            )
        }
    }
}

/// Component showing keyframes on the timeline
struct KeyframeTimelineView: View {
    @ObservedObject var animationController: AnimationController
    let propertyId: String
    let propertyType: AnimatableProperty.PropertyType
    @Binding var currentTime: Double
    @Binding var selectedKeyframeTime: Double?
    @Binding var newKeyframeTime: Double
    @Binding var isAddingKeyframe: Bool
    let scale: Double
    @Binding var offset: Double
    var onAddKeyframe: (Double) -> Void
    
    // Keyframe times for the current property
    private var keyframeTimes: [Double] {
        switch propertyType {
        case .position:
            if let track = animationController.getTrack(id: propertyId) as KeyframeTrack<CGPoint>? {
                return track.allKeyframes.map { $0.time }
            }
        case .size:
            if let track = animationController.getTrack(id: propertyId) as KeyframeTrack<CGFloat>? {
                return track.allKeyframes.map { $0.time }
            }
        case .rotation:
            if let track = animationController.getTrack(id: propertyId) as KeyframeTrack<Double>? {
                return track.allKeyframes.map { $0.time }
            }
        case .color:
            if let track = animationController.getTrack(id: propertyId) as KeyframeTrack<Color>? {
                return track.allKeyframes.map { $0.time }
            }
        default:
            break
        }
        return []
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background with gradient
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(NSColor.controlBackgroundColor),
                            Color(NSColor.controlBackgroundColor).opacity(0.8)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                
                // Line connecting keyframes
                if !keyframeTimes.isEmpty {
                    Path { path in
                        let sortedTimes = keyframeTimes.sorted()
                        if let firstTime = sortedTimes.first {
                            path.move(to: CGPoint(
                                x: timeToPosition(firstTime, width: geometry.size.width),
                                y: geometry.size.height / 2
                            ))
                            
                            for time in sortedTimes.dropFirst() {
                                path.addLine(to: CGPoint(
                                    x: timeToPosition(time, width: geometry.size.width),
                                    y: geometry.size.height / 2
                                ))
                            }
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                
                // Keyframe markers
                ForEach(keyframeTimes, id: \.self) { time in
                    let x = timeToPosition(time, width: geometry.size.width)
                    let isSelected = selectedKeyframeTime == time
                    
                    Circle()
                        .fill(isSelected ? Color.blue : Color.white)
                        .strokeBorder(Color.blue, lineWidth: 2)
                        .frame(width: isSelected ? 12 : 10, height: isSelected ? 12 : 10)
                        .position(x: x, y: geometry.size.height / 2)
                        .onTapGesture {
                            selectedKeyframeTime = time
                        }
                }
                
                // Area for double-click to add keyframe
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .onTapGesture(count: 2) {
                        // Since we can't get location directly from TapGesture,
                        // we'll use the current time as a sensible default
                        newKeyframeTime = animationController.currentTime
                        onAddKeyframe(animationController.currentTime)
                        isAddingKeyframe = true
                    }
                
                // Overlay for drag gestures - provides better positional information
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                // We can get location from DragGesture
                                let localX = value.location.x
                                let clickTime = positionToTime(localX, width: geometry.size.width)
                                
                                // Check if it's near an existing keyframe (for selection)
                                let nearestKeyframeTime = findNearestKeyframeTime(to: clickTime)
                                if let nearest = nearestKeyframeTime, abs(nearest - clickTime) < 0.2 {
                                    // Select the keyframe if clicking near it
                                    selectedKeyframeTime = nearest
                                } else if abs(value.startLocation.x - value.location.x) < 5 && abs(value.startLocation.y - value.location.y) < 5 {
                                    // If it's a tap (not much movement) and no keyframe nearby, add new one
                                    let clampedTime = max(0, min(animationController.duration, clickTime))
                                    newKeyframeTime = clampedTime
                                    onAddKeyframe(clampedTime)
                                    isAddingKeyframe = true
                                }
                            }
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    // Convert time to position in the timeline
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(((time - offset) * scale / animationController.duration) * Double(width))
    }
    
    // Convert position to time in the timeline
    private func positionToTime(_ position: CGFloat, width: CGFloat) -> Double {
        return (Double(position) / Double(width)) * (animationController.duration / scale) + offset
    }
    
    // Find the nearest keyframe time to a given time
    private func findNearestKeyframeTime(to time: Double) -> Double? {
        guard !keyframeTimes.isEmpty else { return nil }
        
        return keyframeTimes.min(by: { abs($0 - time) < abs($1 - time) })
    }
    
    // Helper to create a bezier curve that mimics easing functions
    private func getEasingCurve(fromX: CGFloat, toX: CGFloat, midY: CGFloat, ease: EasingFunction) -> (control1: CGPoint, control2: CGPoint) {
        let width = toX - fromX
        
        switch ease {
        case .linear:
            return (
                CGPoint(x: fromX + width * 0.33, y: midY),
                CGPoint(x: fromX + width * 0.66, y: midY)
            )
        case .easeIn:
            return (
                CGPoint(x: fromX + width * 0.1, y: midY),
                CGPoint(x: fromX + width * 0.7, y: midY)
            )
        case .easeOut:
            return (
                CGPoint(x: fromX + width * 0.3, y: midY),
                CGPoint(x: fromX + width * 0.9, y: midY)
            )
        case .easeInOut:
            return (
                CGPoint(x: fromX + width * 0.25, y: midY),
                CGPoint(x: fromX + width * 0.75, y: midY)
            )
        default:
            return (
                CGPoint(x: fromX + width * 0.33, y: midY),
                CGPoint(x: fromX + width * 0.66, y: midY)
            )
        }
    }
}

/// A view that displays a timeline with keyframes for a specific property
struct TimelineView: View {
    @ObservedObject var animationController: AnimationController
    let propertyId: String
    let propertyType: AnimatableProperty.PropertyType
    @Binding var selectedKeyframeTime: Double?
    @Binding var newKeyframeTime: Double
    @Binding var isAddingKeyframe: Bool
    @State var timelineScale: Double = 1.0
    @Binding var timelineOffset: Double
    var onAddKeyframe: (Double) -> Void
    
    // Computed property for keyframe times to pass to TimelineRuler
    private var keyframeTimes: [Double] {
        var times: Set<Double> = []
        
        let tracks = animationController.getAllTracks()
        for trackId in tracks {
            if let track = animationController.getTrack(id: trackId) as KeyframeTrack<CGPoint>? {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as KeyframeTrack<CGFloat>? {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as KeyframeTrack<Double>? {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as KeyframeTrack<Color>? {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        }
        
        return Array(times).sorted()
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Timeline ruler
            TimelineRuler(
                duration: animationController.duration,
                currentTime: $animationController.currentTime,
                scale: timelineScale,
                offset: $timelineOffset,
                keyframeTimes: keyframeTimes  // Pass keyframe times for snapping
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
            .frame(height: 80)
        }
    }
}

#if !DISABLE_PREVIEWS
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample animation controller for the preview
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Add some sample keyframes
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 300)))
        
        return TimelineView(
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
        .padding()
    }
}
#endif

