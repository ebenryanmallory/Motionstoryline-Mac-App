import SwiftUI
import AVFoundation

/// A model representing an audio marker that can be used to create keyframes
public struct AudioMarker: Identifiable, Equatable {
    public let id = UUID()
    public var time: Double
    public var label: String
    public var color: Color
    
    public init(time: Double, label: String = "", color: Color = .blue) {
        self.time = time
        self.label = label
        self.color = color
    }
    
    public static func == (lhs: AudioMarker, rhs: AudioMarker) -> Bool {
        lhs.id == rhs.id
    }
}

/// A view model to manage audio markers and synchronize them with keyframes
public class AudioMarkerManager: ObservableObject {
    @Published public var markers: [AudioMarker] = []
    private let animationController: AnimationController
    
    public init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    /// Add a new marker at the specified time
    public func addMarker(at time: Double, label: String = "", color: Color = .blue) {
        let marker = AudioMarker(time: time, label: label, color: color)
        markers.append(marker)
        // Sort markers by time
        markers.sort { $0.time < $1.time }
    }
    
    /// Remove a marker
    public func removeMarker(_ marker: AudioMarker) {
        markers.removeAll { $0.id == marker.id }
    }
    
    /// Clear all markers
    public func clearMarkers() {
        markers.removeAll()
    }
    
    /// Create keyframes at marker positions for the specified property track
    public func createKeyframesFromMarkers(
        propertyId: String,
        propertyType: AnimatableProperty.PropertyType,
        interpolationType: EasingFunction = .linear
    ) -> Int {
        guard !markers.isEmpty else { return 0 }
        
        var keyframesAdded = 0
        
        // Get the current value at each marker time to create the keyframes
        for marker in markers {
            switch propertyType {
            case .position:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGPoint> {
                    // Get current value at this time
                    let value = track.getValue(at: marker.time) ?? .zero
                    
                    // Create keyframe with current value
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .size:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGFloat> {
                    let value = track.getValue(at: marker.time) ?? 0
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .rotation:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
                    let value = track.getValue(at: marker.time) ?? 0
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .color:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Color> {
                    let value = track.getValue(at: marker.time) ?? .black
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .opacity:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
                    let value = track.getValue(at: marker.time) ?? 1.0
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .scale:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGFloat> {
                    let value = track.getValue(at: marker.time) ?? 1.0
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            case .custom:
                if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<[CGPoint]> {
                    let value = track.getValue(at: marker.time) ?? []
                    let keyframe = Keyframe(time: marker.time, value: value, easingFunction: interpolationType)
                    if track.add(keyframe: keyframe) {
                        keyframesAdded += 1
                    }
                }
            }
        }
        
        return keyframesAdded
    }
    
    /// Create keyframes with specified values at marker positions
    public func createKeyframesWithValues<T: Interpolatable>(
        propertyId: String,
        values: [T],
        interpolationType: EasingFunction = .linear
    ) -> Int {
        guard !markers.isEmpty, let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<T> else {
            return 0
        }
        
        // Ensure we have enough values for all markers
        guard values.count >= markers.count else {
            return 0
        }
        
        var keyframesAdded = 0
        
        // Create keyframes with the provided values
        for (index, marker) in markers.enumerated() {
            let keyframe = Keyframe(time: marker.time, value: values[index], easingFunction: interpolationType)
            if track.add(keyframe: keyframe) {
                keyframesAdded += 1
            }
        }
        
        return keyframesAdded
    }
}

/// A view that displays audio markers on the timeline
public struct AudioMarkerView: View {
    @ObservedObject var markerManager: AudioMarkerManager
    let scale: Double
    @Binding var offset: Double
    let trackHeight: CGFloat
    
    public init(
        markerManager: AudioMarkerManager,
        scale: Double,
        offset: Binding<Double>,
        trackHeight: CGFloat = 100
    ) {
        self.markerManager = markerManager
        self.scale = scale
        self._offset = offset
        self.trackHeight = trackHeight
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render each marker
                ForEach(markerManager.markers) { marker in
                    MarkerLine(
                        color: marker.color,
                        height: trackHeight,
                        label: marker.label
                    )
                    .position(
                        x: timeToPosition(marker.time, width: geometry.size.width),
                        y: trackHeight / 2
                    )
                }
            }
            .frame(width: geometry.size.width, height: trackHeight)
        }
    }
    
    // Convert time to position in the timeline
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(((time - offset) * scale) * Double(width))
    }
}

/// A view representing a single marker line
struct MarkerLine: View {
    let color: Color
    let height: CGFloat
    let label: String
    
    var body: some View {
        VStack(spacing: 0) {
            // Label above the line if provided
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(2)
            }
            
            // Marker line
            Rectangle()
                .fill(color)
                .frame(width: 1.5, height: height - (label.isEmpty ? 0 : 20))
        }
    }
}

#if !DISABLE_PREVIEWS
// Preview for AudioMarkerView
struct AudioMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        let markerManager = AudioMarkerManager(animationController: animationController)
        markerManager.addMarker(at: 1.0, label: "Beat 1")
        markerManager.addMarker(at: 2.0, label: "Beat 2", color: .red)
        markerManager.addMarker(at: 3.5, label: "Beat 3", color: .green)
        
        return AudioMarkerView(
            markerManager: markerManager,
            scale: 1.0,
            offset: .constant(0.0)
        )
        .frame(height: 100)
        .background(Color.gray.opacity(0.1))
        .padding()
    }
}
#endif 