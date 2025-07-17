import SwiftUI

/// Defines different easing functions for keyframe interpolation
public enum EasingFunction: Hashable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case bounce
    case elastic
    case spring
    case sine
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
        case .bounce:
            hasher.combine(4)
        case .elastic:
            hasher.combine(5)
        case .spring:
            hasher.combine(6)
        case .sine:
            hasher.combine(7)
        case let .customCubicBezier(x1, y1, x2, y2):
            hasher.combine(8)
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
             (.easeInOut, .easeInOut),
             (.bounce, .bounce),
             (.elastic, .elastic),
             (.spring, .spring),
             (.sine, .sine):
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
        case .bounce:
            // Simple bounce implementation
            if t < 1 / 2.75 {
                return 7.5625 * t * t
            } else if t < 2 / 2.75 {
                let t1 = t - 1.5 / 2.75
                return 7.5625 * t1 * t1 + 0.75
            } else if t < 2.5 / 2.75 {
                let t1 = t - 2.25 / 2.75
                return 7.5625 * t1 * t1 + 0.9375
            } else {
                let t1 = t - 2.625 / 2.75
                return 7.5625 * t1 * t1 + 0.984375
            }
        case .elastic:
            // Simple elastic implementation
            if t == 0 || t == 1 { return t }
            let p = 0.3
            let s = p / 4
            let t1 = t - 1
            return -pow(2, 10 * t1) * sin((t1 - s) * (2 * .pi) / p)
        case .spring:
            // Simple spring implementation
            let s = 1.70158
            let t1 = t - 1
            return t1 * t1 * ((s + 1) * t1 + s) + 1
        case .sine:
            // Simple sine implementation
            return sin(t * .pi / 2)
        case .customCubicBezier(let x1, _, let x2, _):
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

/// Protocol for all keyframe types to enable type-erased collections
public protocol KeyframeProtocol {
    /// The time position of this keyframe (in seconds)
    var time: Double { get }
    
    /// The easing function used to interpolate to the next keyframe
    var easingFunction: EasingFunction { get }
    
    /// The value at this keyframe as Any (for type-erased access)
    var anyValue: Any { get }
}

// Make Keyframe conform to KeyframeProtocol
extension Keyframe: KeyframeProtocol {
    public var anyValue: Any {
        return value
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

extension CGSize: Interpolatable {
    public func interpolate(to: CGSize, progress: Double) -> CGSize {
        return CGSize(
            width: width + (to.width - width) * CGFloat(progress),
            height: height + (to.height - height) * CGFloat(progress)
        )
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

// Add support for animating paths (arrays of CGPoints)
extension Array: Interpolatable where Element == CGPoint {
    public func interpolate(to: [CGPoint], progress: Double) -> [CGPoint] {
        // Handle cases where arrays have different lengths
        if self.isEmpty {
            return progress < 1.0 ? [] : to
        }
        
        if to.isEmpty {
            return progress > 0.0 ? [] : self
        }
        
        // Find the maximum number of points to interpolate
        let maxCount = Swift.max(self.count, to.count)
        var result: [CGPoint] = []
        
        // Interpolate all points
        for i in 0..<maxCount {
            if i < self.count && i < to.count {
                // Both arrays have a point at this index
                let fromPoint = self[i]
                let toPoint = to[i]
                result.append(fromPoint.interpolate(to: toPoint, progress: progress))
            } else if i < self.count {
                // Only "from" array has a point at this index
                result.append(self[i])
            } else if i < to.count {
                // Only "to" array has a point at this index
                result.append(to[i])
            }
        }
        
        return result
    }
}

extension Color: Interpolatable {
    public func interpolate(to: Color, progress: Double) -> Color {
        // This is a simplified implementation
        // For production, consider using a proper color space conversion
        #if canImport(AppKit)
        let fromNSColor = NSColor(self)
        let toNSColor = NSColor(to)
        #else
        // Fallback implementation if not on macOS
        return self.opacity(1 - progress) + to.opacity(progress)
        #endif
        
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


// Add support for String
extension String: Interpolatable {
    public func interpolate(to: String, progress: Double) -> String {
        // For strings, we don't have a meaningful way to interpolate between two values
        // So we just return either the start or end value based on the progress
        return progress < 0.5 ? self : to
    }
}

/// Manages a collection of keyframes for a specific property
public class KeyframeTrack<T: Interpolatable> {
    /// Unique identifier for this track
    public let id: String
    
    /// The keyframes in this track, sorted by time
    private var keyframes: [Keyframe<T>] = []
    
    /// Cache for frequently accessed keyframe indices
    private var cachedKeyframeIndices: [Double: Int] = [:]
    
    /// Last evaluated time for optimization
    private var lastEvaluatedTime: Double?
    
    /// Last evaluated value for optimization
    private var lastEvaluatedValue: T?
    
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
        
        // Clear caches on modification
        invalidateCache()
        return true
    }
    
    /// Remove a keyframe at the specified time
    /// - Parameter time: The time to remove a keyframe from
    /// - Returns: True if a keyframe was removed, false if no keyframe was found
    @discardableResult
    public func removeKeyframe(at time: Double) -> Bool {
        let initialCount = keyframes.count
        keyframes.removeAll(where: { abs($0.time - time) < 0.001 }) // Small epsilon for floating point comparison
        
        // Clear caches if a keyframe was removed
        if keyframes.count < initialCount {
            invalidateCache()
            return true
        }
        return false
    }
    
    /// Clear all caches when track is modified
    private func invalidateCache() {
        cachedKeyframeIndices.removeAll()
        lastEvaluatedTime = nil
        lastEvaluatedValue = nil
    }
    
    /// Find the keyframe index pair that surrounds the given time
    /// - Parameter time: The time to find surrounding keyframes for
    /// - Returns: The indices of the keyframes before and after the time
    private func findKeyframeIndices(for time: Double) -> (before: Int, after: Int)? {
        // Return cached result if available
        if let cachedIndex = cachedKeyframeIndices[time] {
            if cachedIndex < keyframes.count - 1 {
                return (cachedIndex, cachedIndex + 1)
            }
            return (cachedIndex, cachedIndex)
        }
        
        // Handle edge cases first
        if keyframes.isEmpty {
            return nil
        }
        
        // Before first keyframe
        if time <= keyframes.first!.time {
            cachedKeyframeIndices[time] = 0
            return (0, 0)
        }
        
        // After last keyframe
        if time >= keyframes.last!.time {
            let lastIndex = keyframes.count - 1
            cachedKeyframeIndices[time] = lastIndex
            return (lastIndex, lastIndex)
        }
        
        // Binary search for more efficient lookup
        var low = 0
        var high = keyframes.count - 1
        
        while low <= high {
            let mid = (low + high) / 2
            let midTime = keyframes[mid].time
            
            if abs(midTime - time) < 0.001 {
                // Exact match (within epsilon)
                cachedKeyframeIndices[time] = mid
                return (mid, mid)
            } else if midTime < time {
                if mid < keyframes.count - 1 && keyframes[mid + 1].time > time {
                    // Found the surrounding keyframes
                    cachedKeyframeIndices[time] = mid
                    return (mid, mid + 1)
                }
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        
        // If we get here, low should be the index after time
        let beforeIndex = max(0, low - 1)
        cachedKeyframeIndices[time] = beforeIndex
        return (beforeIndex, low)
    }
    
    /// Get the value at a specific time
    /// - Parameter time: The time to evaluate
    /// - Returns: The interpolated value, or nil if no keyframes exist
    public func getValue(at time: Double) -> T? {
        // If no keyframes, return nil
        if keyframes.isEmpty {
            return nil
        }
        
        // Check for temporal coherence - if time is the same as the last evaluated time, return the cached value
        if let lastTime = lastEvaluatedTime, let lastValue = lastEvaluatedValue, abs(lastTime - time) < 0.001 {
            return lastValue
        }
        
        // Find the keyframe indices
        guard let indices = findKeyframeIndices(for: time) else {
            return nil
        }
        
        let beforeIndex = indices.before
        let afterIndex = indices.after
        
        // If we're exactly on a keyframe (or before first/after last)
        if beforeIndex == afterIndex {
            let value = keyframes[beforeIndex].value
            lastEvaluatedTime = time
            lastEvaluatedValue = value
            return value
        }
        
        // Get the keyframes we're between
        let fromKeyframe = keyframes[beforeIndex]
        let toKeyframe = keyframes[afterIndex]
        
        // Calculate the normalized progress between these keyframes
        let range = toKeyframe.time - fromKeyframe.time
        let progress = (time - fromKeyframe.time) / range
        
        // Apply easing function
        let easedProgress = fromKeyframe.easingFunction.apply(to: progress)
        
        // Interpolate the value
        let interpolatedValue = fromKeyframe.value.interpolate(to: toKeyframe.value, progress: easedProgress)
        
        // Cache the result
        lastEvaluatedTime = time
        lastEvaluatedValue = interpolatedValue
        
        return interpolatedValue
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
        
        // Create a new timer that fires at least 30 times per second (using 60 for smoother animation)
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
        
        // Ensure the timer runs on the main thread with high priority for smoother animation
        RunLoop.main.add(timer!, forMode: .common)
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
            } else if let sizeTrack = track as? KeyframeTrack<CGSize> {
                if let value = sizeTrack.getValue(at: currentTime) {
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
    
    /// Seek to a specific time position
    /// - Parameter time: The time position in seconds
    public func seekToTime(_ time: Double) {
        // Ensure time is within bounds
        let boundedTime = max(0, min(duration, time))
        
        // Update current time
        currentTime = boundedTime
        
        // Update all animated properties at this time
        updateAnimatedProperties()
    }
    
    /// Seek to a specific time position (alias for seekToTime)
    /// - Parameter time: The time position in seconds
    public func seek(to time: Double) {
        seekToTime(time)
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
    
    /// Get a track by ID
    /// - Parameter id: The track ID to look for
    /// - Returns: The track if found, nil otherwise
    public func getTrack<T: Interpolatable>(id: String) -> KeyframeTrack<T>? {
        return keyframeTracks[id] as? KeyframeTrack<T>
    }
    
    /// Check if a track with the given ID exists
    /// - Parameter id: The track ID to check
    /// - Returns: True if the track exists, false otherwise
    public func hasTrack(id: String) -> Bool {
        return keyframeTracks[id] != nil
    }
    
    /// Remove a track by ID
    /// - Parameter id: The track id
    public func removeTrack(id: String) {
        keyframeTracks.removeValue(forKey: id)
        propertyUpdateCallbacks.removeValue(forKey: id)
    }

    /// Clear all tracks from the animation controller
    public func clearAllTracks() {
        let trackCount = keyframeTracks.count
        keyframeTracks.removeAll()
        propertyUpdateCallbacks.removeAll()
        print("AnimationController DEBUG: Cleared all \(trackCount) tracks")
    }
    
    /// Remove all animation tracks associated with a specific element
    /// - Parameter elementId: The ID of the element whose tracks should be removed
    public func removeTracksForElement(elementId: UUID) {
        let elementIdString = elementId.uuidString
        let allTracks = getAllTracks()
        
        // Find all tracks that belong to this element (they start with the element ID)
        let tracksToRemove = allTracks.filter { trackId in
            trackId.hasPrefix(elementIdString)
        }
        
        // Remove each track
        for trackId in tracksToRemove {
            removeTrack(id: trackId)
        }
        
        print("AnimationController: Removed \(tracksToRemove.count) tracks for element: \(elementIdString)")
        
        // Log the specific tracks that were removed for debugging
        if !tracksToRemove.isEmpty {
            print("   Removed tracks: \(tracksToRemove.joined(separator: ", "))")
        }
    }

    /// Get all tracks with their IDs and keyframes
    public func getAllTracksWithKeyframes() -> [(id: String, keyframes: [KeyframeProtocol])] {
        var result: [(id: String, keyframes: [KeyframeProtocol])] = []
        
        for (id, track) in keyframeTracks {
            if let doubleTrack = track as? KeyframeTrack<Double> {
                result.append((id: id, keyframes: doubleTrack.allKeyframes))
            } else if let cgFloatTrack = track as? KeyframeTrack<CGFloat> {
                result.append((id: id, keyframes: cgFloatTrack.allKeyframes))
            } else if let pointTrack = track as? KeyframeTrack<CGPoint> {
                result.append((id: id, keyframes: pointTrack.allKeyframes))
            } else if let colorTrack = track as? KeyframeTrack<Color> {
                result.append((id: id, keyframes: colorTrack.allKeyframes))
            } else if let sizeTrack = track as? KeyframeTrack<CGSize> {
                result.append((id: id, keyframes: sizeTrack.allKeyframes))
            } else if let pathTrack = track as? KeyframeTrack<[CGPoint]> {
                result.append((id: id, keyframes: pathTrack.allKeyframes))
            }
        }
        
        return result
    }

    /// Get all keyframe track IDs
    public func getAllTracks() -> [String] {
        return Array(keyframeTracks.keys)
    }

    /// Get all keyframe times from all tracks
    public func getAllKeyframeTimes() -> [Double] {
        var times: Set<Double> = []
        
        for trackId in getAllTracks() {
            if let track = getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = getTrack(id: trackId) as? KeyframeTrack<CGFloat> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = getTrack(id: trackId) as? KeyframeTrack<Double> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = getTrack(id: trackId) as? KeyframeTrack<Color> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = getTrack(id: trackId) as? KeyframeTrack<CGSize> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = getTrack(id: trackId) as? KeyframeTrack<[CGPoint]> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        }
        
        return Array(times).sorted()
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
        } else if let sizeTrack = track as? KeyframeTrack<CGSize> {
            return sizeTrack.removeKeyframe(at: time)
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
                .keyboardShortcut("p", modifiers: [])
                .help(animationController.isPlaying ? "Pause Animation (P)" : "Play Animation (P)")
                
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
                    Text("Bounce").tag(EasingFunction.bounce)
                    Text("Elastic").tag(EasingFunction.elastic)
                    Text("Spring").tag(EasingFunction.spring)
                    Text("Sine").tag(EasingFunction.sine)
                    Text("Custom Bezier").tag(EasingFunction.customCubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1.0))
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedEasing) {
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
