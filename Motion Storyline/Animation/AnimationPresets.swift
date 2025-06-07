import SwiftUI

/// Animation preset types available in the application
public enum AnimationPresetType: String, CaseIterable, Identifiable {
    case fade
    case slide
    case scale
    case rotate
    case bounce
    case custom
    
    public var id: String { self.rawValue }
    
    /// Display name for the preset type
    public var displayName: String {
        switch self {
        case .fade: return "Fade"
        case .slide: return "Slide"
        case .scale: return "Scale"
        case .rotate: return "Rotate"
        case .bounce: return "Bounce"
        case .custom: return "Custom"
        }
    }
    
    /// Icon for the preset type
    public var systemIcon: String {
        switch self {
        case .fade: return "circle.circle"
        case .slide: return "arrow.right"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .rotate: return "arrow.clockwise"
        case .bounce: return "waveform.path"
        case .custom: return "slider.horizontal.3"
        }
    }
}

/// Defines the direction for animation presets that have directional variants
public enum AnimationDirection: String, CaseIterable, Identifiable {
    case left
    case right
    case up
    case down
    case inward
    case outward
    
    public var id: String { self.rawValue }
    
    /// Display name for the direction
    public var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .up: return "Up"
        case .down: return "Down"
        case .inward: return "Inward"
        case .outward: return "Outward"
        }
    }
}

/// Animation preset configurator for applying preset animations to elements
public class AnimationPreset {
    
    /// Apply a fade animation preset to the animation controller
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - fadeIn: Whether to fade in (true) or fade out (false)
    ///   - easingFunction: The easing function to use
    public static func applyFade(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        fadeIn: Bool = true,
        easingFunction: EasingFunction = .easeInOut
    ) {
        let opacityTrackId = "\(elementId)_opacity"
        
        // Create opacity track if it doesn't exist
        let opacityTrack = animationController.getTrack(id: opacityTrackId) as KeyframeTrack<Double>?
            ?? animationController.addTrack(id: opacityTrackId) { (_: Double) in }
        
        // Add keyframes for fade in or out
        let startValue = fadeIn ? 0.0 : 1.0
        let endValue = fadeIn ? 1.0 : 0.0
        
        opacityTrack.add(keyframe: Keyframe(time: startTime, value: startValue, easingFunction: easingFunction))
        opacityTrack.add(keyframe: Keyframe(time: startTime + duration, value: endValue, easingFunction: easingFunction))
    }
    
    /// Apply a slide animation preset to the animation controller
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - direction: The direction to slide from
    ///   - distance: Distance to slide (in points)
    ///   - easingFunction: The easing function to use
    ///   - initialPosition: The initial position to slide to/from
    public static func applySlide(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        direction: AnimationDirection,
        distance: CGFloat = 200,
        easingFunction: EasingFunction = .easeOut,
        initialPosition: CGPoint
    ) {
        let positionTrackId = "\(elementId)_position"
        
        // Create position track if it doesn't exist
        let positionTrack = animationController.getTrack(id: positionTrackId) as KeyframeTrack<CGPoint>?
            ?? animationController.addTrack(id: positionTrackId) { (_: CGPoint) in }
        
        // Calculate start position based on direction
        var startPosition = initialPosition
        switch direction {
        case .left:
            startPosition.x = initialPosition.x + distance
        case .right:
            startPosition.x = initialPosition.x - distance
        case .up:
            startPosition.y = initialPosition.y + distance
        case .down:
            startPosition.y = initialPosition.y - distance
        case .inward, .outward:
            // Not applicable for slide, but included for API completeness
            break
        }
        
        // Add position keyframes
        positionTrack.add(keyframe: Keyframe(time: startTime, value: startPosition, easingFunction: easingFunction))
        positionTrack.add(keyframe: Keyframe(time: startTime + duration, value: initialPosition, easingFunction: easingFunction))
    }
    
    /// Apply a scale animation preset to the animation controller
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - direction: Scale direction (inward or outward)
    ///   - initialScale: The base scale value (1.0 is original size)
    ///   - targetScale: The target scale value
    ///   - easingFunction: The easing function to use
    public static func applyScale(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        direction: AnimationDirection = .inward,
        initialScale: CGFloat = 1.0,
        targetScale: CGFloat? = nil,
        easingFunction: EasingFunction = .easeOut
    ) {
        let scaleTrackId = "\(elementId)_scale"
        
        // Create scale track if it doesn't exist
        let scaleTrack = animationController.getTrack(id: scaleTrackId) as KeyframeTrack<CGFloat>?
            ?? animationController.addTrack(id: scaleTrackId) { (_: CGFloat) in }
        
        // Determine scale values based on direction
        let computedTargetScale: CGFloat
        if let targetScale = targetScale {
            computedTargetScale = targetScale
        } else {
            computedTargetScale = direction == .inward ? 0.0 : 2.0
        }
        
        let startScale = direction == .inward ? initialScale : computedTargetScale
        let endScale = direction == .inward ? computedTargetScale : initialScale
        
        // Add scale keyframes
        scaleTrack.add(keyframe: Keyframe(time: startTime, value: startScale, easingFunction: easingFunction))
        scaleTrack.add(keyframe: Keyframe(time: startTime + duration, value: endScale, easingFunction: easingFunction))
    }
    
    /// Apply a rotation animation preset to the animation controller
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - startAngle: Starting angle in degrees
    ///   - endAngle: Ending angle in degrees
    ///   - easingFunction: The easing function to use
    public static func applyRotation(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        startAngle: Double = 0.0,
        endAngle: Double = 360.0,
        easingFunction: EasingFunction = .easeInOut
    ) {
        let rotationTrackId = "\(elementId)_rotation"
        
        // Create rotation track if it doesn't exist
        let rotationTrack = animationController.getTrack(id: rotationTrackId) as KeyframeTrack<Double>?
            ?? animationController.addTrack(id: rotationTrackId) { (_: Double) in }
        
        // Add rotation keyframes
        rotationTrack.add(keyframe: Keyframe(time: startTime, value: startAngle, easingFunction: easingFunction))
        rotationTrack.add(keyframe: Keyframe(time: startTime + duration, value: endAngle, easingFunction: easingFunction))
    }
    
    /// Apply a bounce animation preset to the animation controller
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - direction: Direction to bounce
    ///   - intensity: Bounce intensity (higher means more bouncy)
    ///   - initialPosition: The initial position to bounce from
    public static func applyBounce(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        direction: AnimationDirection,
        intensity: CGFloat = 30.0,
        initialPosition: CGPoint
    ) {
        let positionTrackId = "\(elementId)_position"
        
        // Create position track if it doesn't exist
        let positionTrack = animationController.getTrack(id: positionTrackId) as KeyframeTrack<CGPoint>?
            ?? animationController.addTrack(id: positionTrackId) { (_: CGPoint) in }
        
        // Calculate bounce positions based on direction
        let bounceOffsets: [CGFloat] = [0, intensity, -intensity * 0.6, intensity * 0.3, -intensity * 0.15, 0]
        
        // Add position keyframes for bounce effect
        for (index, offset) in bounceOffsets.enumerated() {
            let time = startTime + (duration * Double(index) / Double(bounceOffsets.count - 1))
            var position = initialPosition
            
            switch direction {
            case .left, .right:
                position.x = initialPosition.x + (direction == .right ? offset : -offset)
            case .up, .down:
                position.y = initialPosition.y + (direction == .down ? offset : -offset)
            case .inward, .outward:
                // Not applicable for bounce in a specific direction
                break
            }
            
            positionTrack.add(keyframe: Keyframe(
                time: time,
                value: position, 
                easingFunction: index == bounceOffsets.count - 1 ? .linear : .easeOut
            ))
        }
    }
    
    /// Apply a combined animation preset with multiple effects
    /// - Parameters:
    ///   - animationController: The animation controller to apply the preset to
    ///   - elementId: The element to animate
    ///   - startTime: Start time of the animation in seconds
    ///   - duration: Duration of the animation in seconds
    ///   - presetType: The type of animation preset to apply
    ///   - direction: Direction for the animation (if applicable)
    ///   - initialPosition: The initial position for position-based animations
    ///   - initialScale: The initial scale for scale-based animations
    public static func applyPreset(
        animationController: AnimationController,
        elementId: String,
        startTime: Double,
        duration: Double,
        presetType: AnimationPresetType,
        direction: AnimationDirection = .right,
        initialPosition: CGPoint = .zero,
        initialScale: CGFloat = 1.0
    ) {
        switch presetType {
        case .fade:
            applyFade(
                animationController: animationController,
                elementId: elementId,
                startTime: startTime,
                duration: duration,
                fadeIn: true
            )
            
        case .slide:
            applySlide(
                animationController: animationController,
                elementId: elementId,
                startTime: startTime,
                duration: duration,
                direction: direction,
                initialPosition: initialPosition
            )
            
        case .scale:
            applyScale(
                animationController: animationController,
                elementId: elementId,
                startTime: startTime,
                duration: duration,
                direction: direction == .inward ? .inward : .outward,
                initialScale: initialScale
            )
            
        case .rotate:
            applyRotation(
                animationController: animationController,
                elementId: elementId,
                startTime: startTime,
                duration: duration
            )
            
        case .bounce:
            applyBounce(
                animationController: animationController,
                elementId: elementId,
                startTime: startTime,
                duration: duration,
                direction: direction,
                initialPosition: initialPosition
            )
            
        case .custom:
            // Custom presets would be configured elsewhere
            break
        }
    }
} 