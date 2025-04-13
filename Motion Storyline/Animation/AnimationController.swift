import SwiftUI

/// Defines different easing functions for keyframe interpolation
public enum EasingFunction: Hashable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case customCubicBezier(x1: Double, y1: Double, x2: Double, y2: Double)
    
    /// Explicitly implement hash(into:) to handle the customCubicBezier case
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .linear:
            hasher.combine(0) // Use a unique value for each case
        case .easeIn:
            hasher.combine(1)
        case .easeOut:
            hasher.combine(2)
        case .easeInOut:
            hasher.combine(3)
        case let .customCubicBezier(x1, y1, x2, y2):
            hasher.combine(4)
            hasher.combine(x1)
            hasher.combine(y1)
            hasher.combine(x2)
            hasher.combine(y2)
        }
    }
    
    /// Explicitly implement equality to ensure proper comparison of customCubicBezier case
    public static func == (lhs: EasingFunction, rhs: EasingFunction) -> Bool {
        switch (lhs, rhs) {
        case (.linear, .linear), 
             (.easeIn, .easeIn),
             (.easeOut, .easeOut),
             (.easeInOut, .easeInOut):
            return true
        case let (.customCubicBezier(lx1, ly1, lx2, ly2), 
                  .customCubicBezier(rx1, ry1, rx2, ry2)):
            return lx1 == rx1 && ly1 == ry1 && lx2 == rx2 && ly2 == ry2
        default:
            return false
        }
    }
    
    /// Apply the easing function to a normalized progress value (0-1)
    /// - Parameter t: Normalized progress (0-1)
    /// - Returns: Eased value
    func apply(to t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            let t1 = t - 1
            return t1 * t1 * t1 + 1
        case .easeInOut:
            if t < 0.5 {
                return 4 * t * t * t
            } else {
                let t1 = t - 1
                return 0.5 * t1 * t1 * t1 + 1
            }
        case .customCubicBezier(let x1, let y1, let x2, let y2):
            // A simple approximation of cubic bezier for this implementation
            // For production, consider a more accurate bezier curve implementation
            let t1 = 1 - t
            let a = 3 * t1 * t1 * t
            let b = 3 * t1 * t * t
            let c = t * t * t
            return a * x1 + b * x2 + c
        }
    }
}

/// A single keyframe in an animation
public struct Keyframe<T: Interpolatable> {
    /// The time position of this keyframe (in seconds)
    public let time: Double
    
    /// The value at this keyframe
    public let value: T
    
    /// The easing function used to interpolate to the next keyframe
    public let easingFunction: EasingFunction
    
    /// Create a new keyframe
    /// - Parameters:
    ///   - time: Time position in seconds
    ///   - value: The value at this keyframe
    ///   - easingFunction: The easing function used to interpolate to the next keyframe
    public init(time: Double, value: T, easingFunction: EasingFunction = .linear) {
        self.time = time
        self.value = value
        self.easingFunction = easingFunction
    }
}

/// Protocol for values that can be interpolated between keyframes
public protocol Interpolatable {
    /// Interpolate between two values
    /// - Parameters:
    ///   - to: Target value
    ///   - progress: Interpolation progress (0-1)
    /// - Returns: The interpolated value
    func interpolate(to: Self, progress: Double) -> Self
}

// MARK: - Default Interpolatable Implementations

extension Double: Interpolatable {
    public func interpolate(to: Double, progress: Double) -> Double {
        return self + (to - self) * progress
    }
}

extension CGFloat: Interpolatable {
    public func interpolate(to: CGFloat, progress: Double) -> CGFloat {
        return self + (to - self) * CGFloat(progress)
    }
}

extension CGPoint: Interpolatable {
    public func interpolate(to: CGPoint, progress: Double) -> CGPoint {
        return CGPoint(
            x: x + (to.x - x) * CGFloat(progress),
            y: y + (to.y - y) * CGFloat(progress)
        )
    }
}

extension Color: Interpolatable {
    public func interpolate(to: Color, progress: Double) -> Color {
        // This is a simplified implementation
        // For production, consider using a proper color space conversion
        let fromNSColor = NSColor(self)
        let toNSColor = NSColor(to)
        
        guard let fromRGB = fromNSColor.usingColorSpace(.sRGB),
              let toRGB = toNSColor.usingColorSpace(.sRGB) else {
            return self
        }
        
        let r = fromRGB.redComponent + (toRGB.redComponent - fromRGB.redComponent) * CGFloat(progress)
        let g = fromRGB.greenComponent + (toRGB.greenComponent - fromRGB.greenComponent) * CGFloat(progress)
        let b = fromRGB.blueComponent + (toRGB.blueComponent - fromRGB.blueComponent) * CGFloat(progress)
        let a = fromRGB.alphaComponent + (toRGB.alphaComponent - fromRGB.alphaComponent) * CGFloat(progress)
        
        return Color(NSColor(red: r, green: g, blue: b, alpha: a))
    }
}

/// Manages a collection of keyframes for a specific property
public class KeyframeTrack<T: Interpolatable> {
    /// Unique identifier for this track
    public let id: String
    
    /// The keyframes in this track, sorted by time
    private var keyframes: [Keyframe<T>] = []
    
    /// Create a new keyframe track
    /// - Parameter id: Unique identifier for this track
    public init(id: String) {
        self.id = id
    }
    
    /// Add a keyframe to the track
    /// - Parameter keyframe: The keyframe to add
    /// - Returns: True if the keyframe was added, false if a keyframe at the same time already exists
    @discardableResult
    public func add(keyframe: Keyframe<T>) -> Bool {
        // Check if there's already a keyframe at this time
        if keyframes.contains(where: { $0.time == keyframe.time }) {
            return false
        }
        
        // Add and sort
        keyframes.append(keyframe)
        keyframes.sort(by: { $0.time < $1.time })
        return true
    }
    
    /// Remove a keyframe at the specified time
    /// - Parameter time: The time to remove a keyframe from
    /// - Returns: True if a keyframe was removed, false if no keyframe was found
    @discardableResult
    public func removeKeyframe(at time: Double) -> Bool {
        let initialCount = keyframes.count
        keyframes.removeAll(where: { abs($0.time - time) < 0.001 }) // Small epsilon for floating point comparison
        return keyframes.count < initialCount
    }
    
    /// Get the value at a specific time
    /// - Parameter time: The time to evaluate
    /// - Returns: The interpolated value, or nil if no keyframes exist
    public func getValue(at time: Double) -> T? {
        // If no keyframes, return nil
        if keyframes.isEmpty {
            return nil
        }
        
        // If before first keyframe, return first keyframe value
        if time <= keyframes.first!.time {
            return keyframes.first!.value
        }
        
        // If after last keyframe, return last keyframe value
        if time >= keyframes.last!.time {
            return keyframes.last!.value
        }
        
        // Find the keyframes we're between
        for i in 0..<keyframes.count - 1 {
            let fromKeyframe = keyframes[i]
            let toKeyframe = keyframes[i + 1]
            
            if time >= fromKeyframe.time && time <= toKeyframe.time {
                // Calculate the normalized progress between these keyframes
                let range = toKeyframe.time - fromKeyframe.time
                let progress = (time - fromKeyframe.time) / range
                
                // Apply easing function
                let easedProgress = fromKeyframe.easingFunction.apply(to: progress)
                
                // Interpolate the value
                return fromKeyframe.value.interpolate(to: toKeyframe.value, progress: easedProgress)
            }
        }
        
        // Should never reach here
        return keyframes.last!.value
    }
    
    /// Get all keyframes in this track
    public var allKeyframes: [Keyframe<T>] {
        return keyframes
    }
}

/// Controls the animation playback state and timing
public class AnimationController: ObservableObject {
    /// Current playback position in seconds
    @Published var currentTime: Double = 0.0
    
    /// Total animation duration in seconds
    @Published var duration: Double = 5.0
    
    /// Whether the animation is currently playing
    @Published var isPlaying: Bool = false
    
    /// All keyframe tracks in this animation
    private var keyframeTracks: [String: Any] = [:]
    
    /// Callbacks to update animated properties
    private var propertyUpdateCallbacks: [String: (Any) -> Void] = [:]
    
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
        
        // Update playing state
        isPlaying = true
        
        // Create a new timer that fires 60 times per second
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
                
                // Update all animated properties
                self.updateAnimatedProperties()
            }
        }
    }
    
    /// Update all animated properties based on current time
    public func updateAnimatedProperties() {
        // Process each keyframe track
        for (trackId, track) in keyframeTracks {
            // Get the callback for this track
            guard let callback = propertyUpdateCallbacks[trackId] else {
                continue
            }
            
            // Handle different property types
            if let doubleTrack = track as? KeyframeTrack<Double> {
                if let value = doubleTrack.getValue(at: currentTime) {
                    callback(value)
                }
            } else if let cgfloatTrack = track as? KeyframeTrack<CGFloat> {
                if let value = cgfloatTrack.getValue(at: currentTime) {
                    callback(value)
                }
            } else if let pointTrack = track as? KeyframeTrack<CGPoint> {
                if let value = pointTrack.getValue(at: currentTime) {
                    callback(value)
                }
            } else if let colorTrack = track as? KeyframeTrack<Color> {
                if let value = colorTrack.getValue(at: currentTime) {
                    callback(value)
                }
            }
        }
    }
    
    /// Pause animation playback
    public func pause() {
        timer?.invalidate()
        timer = nil
        lastUpdateTime = nil
        isPlaying = false
    }
    
    /// Reset animation to beginning
    public func reset() {
        pause()
        currentTime = 0.0
        updateAnimatedProperties()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    // MARK: - Keyframe Track Management
    
    /// Add a keyframe track for a Double property
    /// - Parameters:
    ///   - id: Unique identifier for the track
    ///   - updateCallback: Callback to update the property value
    /// - Returns: The keyframe track
    public func addTrack<T: Interpolatable>(id: String, updateCallback: @escaping (T) -> Void) -> KeyframeTrack<T> {
        let track = KeyframeTrack<T>(id: id)
        keyframeTracks[id] = track
        propertyUpdateCallbacks[id] = { value in
            if let typedValue = value as? T {
                updateCallback(typedValue)
            }
        }
        return track
    }
    
    /// Get a keyframe track by id
    /// - Parameter id: The track id
    /// - Returns: The keyframe track, or nil if not found
    public func getTrack<T: Interpolatable>(id: String) -> KeyframeTrack<T>? {
        return keyframeTracks[id] as? KeyframeTrack<T>
    }
    
    /// Remove a keyframe track
    /// - Parameter id: The track id
    public func removeTrack(id: String) {
        keyframeTracks.removeValue(forKey: id)
        propertyUpdateCallbacks.removeValue(forKey: id)
    }
    
    /// Add a keyframe to a track
    /// - Parameters:
    ///   - trackId: The track id
    ///   - time: Time position in seconds
    ///   - value: The value at this keyframe
    ///   - easingFunction: The easing function
    /// - Returns: True if the keyframe was added
    @discardableResult
    public func addKeyframe<T: Interpolatable>(trackId: String, time: Double, value: T, easingFunction: EasingFunction = .linear) -> Bool {
        guard let track = getTrack(id: trackId) as KeyframeTrack<T>? else {
            return false
        }
        
        let keyframe = Keyframe(time: time, value: value, easingFunction: easingFunction)
        return track.add(keyframe: keyframe)
    }
    
    /// Remove a keyframe from a track
    /// - Parameters:
    ///   - trackId: The track id
    ///   - time: The time to remove a keyframe from
    /// - Returns: True if a keyframe was removed
    @discardableResult
    public func removeKeyframe(trackId: String, time: Double) -> Bool {
        guard let track = keyframeTracks[trackId] else {
            return false
        }
        
        if let doubleTrack = track as? KeyframeTrack<Double> {
            return doubleTrack.removeKeyframe(at: time)
        } else if let cgfloatTrack = track as? KeyframeTrack<CGFloat> {
            return cgfloatTrack.removeKeyframe(at: time)
        } else if let pointTrack = track as? KeyframeTrack<CGPoint> {
            return pointTrack.removeKeyframe(at: time)
        } else if let colorTrack = track as? KeyframeTrack<Color> {
            return colorTrack.removeKeyframe(at: time)
        }
        
        return false
    }
} 

#if !DISABLE_PREVIEWS
import SwiftUI

struct AnimationControllerPreview: View {
    @StateObject private var animationController = AnimationController()
    @State private var position = CGPoint(x: 100, y: 100)
    @State private var size = CGFloat(50)
    @State private var rotation = Double(0)
    @State private var color = Color.blue
    @State private var selectedEasing: EasingFunction = .linear
    @State private var showTimelineView = true
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Animation Preview")
                .font(.headline)
            
            // Animation canvas
            ZStack {
                // Background grid
                Rectangle()
                    .fill(Color(NSColor.textBackgroundColor))
                    .border(Color(NSColor.separatorColor))
                
                // Animated shape
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .position(position)
                    .rotationEffect(Angle(degrees: rotation))
            }
            .frame(height: 300)
            .onAppear {
                setupAnimation()
            }
            
            // Timeline visualization (optional)
            if showTimelineView {
                timelineView
                    .frame(height: 60)
                    .padding(.horizontal)
            }
            
            // Playback controls
            HStack(spacing: 20) {
                Button(action: {
                    animationController.reset()
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: [])
                .help("Reset Animation")
                
                Button(action: {
                    if animationController.isPlaying {
                        animationController.pause()
                    } else {
                        animationController.play()
                    }
                }) {
                    Image(systemName: animationController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help(animationController.isPlaying ? "Pause Animation" : "Play Animation")
                
                // Current time indicator
                Text(String(format: "%.2fs / %.2fs", animationController.currentTime, animationController.duration))
                    .monospacedDigit()
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Easing function selector
            VStack(alignment: .leading) {
                Text("Easing Function:")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Picker("Easing", selection: $selectedEasing) {
                    Text("Linear").tag(EasingFunction.linear)
                    Text("Ease In").tag(EasingFunction.easeIn)
                    Text("Ease Out").tag(EasingFunction.easeOut)
                    Text("Ease In Out").tag(EasingFunction.easeInOut)
                    Text("Custom Bezier").tag(EasingFunction.customCubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1.0))
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedEasing) { _ in
                    // Recreate animation with new easing
                    setupAnimation()
                }
            }
            .padding(.horizontal)
            
            // Options
            Toggle("Show Timeline", isOn: $showTimelineView)
                .padding(.horizontal)
                .toggleStyle(.switch)
        }
        .padding()
        .frame(width: 600)
    }
    
    private var timelineView: some View {
        ZStack(alignment: .leading) {
            // Background
            Rectangle()
                .fill(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            
            // Time markers
            ForEach(0...Int(animationController.duration), id: \.self) { second in
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(width: 1)
                    .position(x: timeToPosition(Double(second)), y: 30)
                
                Text("\(second)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .position(x: timeToPosition(Double(second)), y: 50)
            }
            
            // Keyframe markers
            Group {
                // Position keyframes
                ForEach(positionKeyframeTimes(), id: \.self) { time in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: timeToPosition(time), y: 15)
                }
                
                // Size keyframes
                ForEach(sizeKeyframeTimes(), id: \.self) { time in
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .position(x: timeToPosition(time), y: 25)
                }
                
                // Rotation keyframes
                ForEach(rotationKeyframeTimes(), id: \.self) { time in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .position(x: timeToPosition(time), y: 35)
                }
                
                // Color keyframes
                ForEach(colorKeyframeTimes(), id: \.self) { time in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .position(x: timeToPosition(time), y: 45)
                }
            }
            
            // Playhead
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .position(x: timeToPosition(animationController.currentTime), y: 30)
                .animation(.linear, value: animationController.currentTime)
        }
    }
    
    // Convert time to position in timeline view
    private func timeToPosition(_ time: Double) -> CGFloat {
        return 20 + CGFloat(time) * (560 / CGFloat(animationController.duration))
    }
    
    // Get position keyframe times
    private func positionKeyframeTimes() -> [Double] {
        guard let track = animationController.getTrack(id: "position") as KeyframeTrack<CGPoint>? else {
            return []
        }
        return track.allKeyframes.map { $0.time }
    }
    
    // Get size keyframe times
    private func sizeKeyframeTimes() -> [Double] {
        guard let track = animationController.getTrack(id: "size") as KeyframeTrack<CGFloat>? else {
            return []
        }
        return track.allKeyframes.map { $0.time }
    }
    
    // Get rotation keyframe times
    private func rotationKeyframeTimes() -> [Double] {
        guard let track = animationController.getTrack(id: "rotation") as KeyframeTrack<Double>? else {
            return []
        }
        return track.allKeyframes.map { $0.time }
    }
    
    // Get color keyframe times
    private func colorKeyframeTimes() -> [Double] {
        guard let track = animationController.getTrack(id: "color") as KeyframeTrack<Color>? else {
            return []
        }
        return track.allKeyframes.map { $0.time }
    }
    
    // Setup the animation with keyframes
    private func setupAnimation() {
        // Reset the controller
        animationController.reset()
        animationController.setup(duration: 5.0)
        
        // Remove any existing tracks
        animationController.removeTrack(id: "position")
        animationController.removeTrack(id: "size")
        animationController.removeTrack(id: "rotation")
        animationController.removeTrack(id: "color")
        
        // Create a position track
        // Create a position track
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in
            position = newPosition
        }
        
        // Add position keyframes
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100), easingFunction: selectedEasing))
        positionTrack.add(keyframe: Keyframe(time: 1.0, value: CGPoint(x: 300, y: 150), easingFunction: selectedEasing))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 400, y: 250), easingFunction: selectedEasing))
        positionTrack.add(keyframe: Keyframe(time: 4.0, value: CGPoint(x: 200, y: 200), easingFunction: selectedEasing))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 100), easingFunction: selectedEasing))
        
        // Create a size track
        let sizeTrack = animationController.addTrack(id: "size") { (newSize: CGFloat) in
            size = newSize
        }
        
        // Add size keyframes
        sizeTrack.add(keyframe: Keyframe(time: 0.0, value: 50.0, easingFunction: selectedEasing))
        sizeTrack.add(keyframe: Keyframe(time: 1.5, value: 100.0, easingFunction: selectedEasing))
        sizeTrack.add(keyframe: Keyframe(time: 3.0, value: 30.0, easingFunction: selectedEasing))
        sizeTrack.add(keyframe: Keyframe(time: 5.0, value: 50.0, easingFunction: selectedEasing))
        
        // Create a rotation track
        let rotationTrack = animationController.addTrack(id: "rotation") { (newRotation: Double) in
            rotation = newRotation
        }
        
        // Add rotation keyframes
        rotationTrack.add(keyframe: Keyframe(time: 0.0, value: 0.0, easingFunction: selectedEasing))
        rotationTrack.add(keyframe: Keyframe(time: 2.0, value: 180.0, easingFunction: selectedEasing))
        rotationTrack.add(keyframe: Keyframe(time: 4.0, value: 360.0, easingFunction: selectedEasing))
        rotationTrack.add(keyframe: Keyframe(time: 5.0, value: 0.0, easingFunction: selectedEasing))
        
        // Create a color track
        let colorTrack = animationController.addTrack(id: "color") { (newColor: Color) in
            color = newColor
        }
        // Add color keyframes
        colorTrack.add(keyframe: Keyframe(time: 0.0, value: Color.blue, easingFunction: selectedEasing))
        colorTrack.add(keyframe: Keyframe(time: 1.25, value: Color.purple, easingFunction: selectedEasing))
        colorTrack.add(keyframe: Keyframe(time: 2.5, value: Color.red, easingFunction: selectedEasing))
        colorTrack.add(keyframe: Keyframe(time: 3.75, value: Color.orange, easingFunction: selectedEasing))
        colorTrack.add(keyframe: Keyframe(time: 5.0, value: Color.blue, easingFunction: selectedEasing))
    }
}

struct AnimationControllerPreview_Previews: PreviewProvider {
    static var previews: some View {
        AnimationControllerPreview()
            .frame(width: 600, height: 600)
    }
}
#endif
