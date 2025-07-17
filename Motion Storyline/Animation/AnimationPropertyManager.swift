import SwiftUI
import Foundation

/// Manages animation properties for canvas elements
/// Handles creating and updating animation tracks when elements are selected
class AnimationPropertyManager {
    
    // MARK: - Properties
    
    private let animationController: AnimationController
    
    // MARK: - Initialization
    
    init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    // MARK: - Animation Property Management
    
    /// Updates the animation properties when an element is selected
    /// - Parameters:
    ///   - element: The selected element to set up animation properties for
    ///   - canvasElements: Binding to the canvas elements array for property updates
    func updateAnimationPropertiesForSelectedElement(
        _ element: CanvasElement?,
        canvasElements: Binding<[CanvasElement]>
    ) {
        guard let element = element else { return }
        
        print("Updating animation properties for: \(element.displayName)")
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        // Setup all animation tracks for this element
        setupPositionTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
        setupSizeTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
        setupRotationTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
        setupColorTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
        setupOpacityTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
        setupFontSizeTrack(for: element, idPrefix: idPrefix, canvasElements: canvasElements)
    }
    
    // MARK: - Private Track Setup Methods
    
    /// Sets up position animation track for an element
    private func setupPositionTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        let positionTrackId = "\(idPrefix)_position"
        
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = animationController.addTrack(id: positionTrackId) { (newPosition: CGPoint) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    canvasElements.wrappedValue[index].position = newPosition
                }
            }
            // Add initial keyframe at time 0 with current element position
            track.add(keyframe: Keyframe(time: 0.0, value: element.position))
        } else if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> {
            // Update the initial keyframe with current element position if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.position, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.position))
            }
        }
    }
    
    /// Sets up size animation track for an element
    private func setupSizeTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        let sizeTrackId = "\(idPrefix)_size"
        
        if animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> == nil {
            let track = animationController.addTrack(id: sizeTrackId) { (newSize: CGSize) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    // If aspect ratio is locked, maintain it
                    if canvasElements.wrappedValue[index].isAspectRatioLocked {
                        let ratio = canvasElements.wrappedValue[index].size.height / canvasElements.wrappedValue[index].size.width
                        canvasElements.wrappedValue[index].size = CGSize(width: newSize.width, height: newSize.width * ratio)
                    } else {
                        canvasElements.wrappedValue[index].size = newSize
                    }
                }
            }
            // Add initial keyframe at time 0 with current element size
            track.add(keyframe: Keyframe(time: 0.0, value: element.size))
        } else if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> {
            // Update the initial keyframe with current element size if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.size, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.size))
            }
        }
    }
    
    /// Sets up rotation animation track for an element
    private func setupRotationTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        let rotationTrackId = "\(idPrefix)_rotation"
        
        if animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: rotationTrackId) { (newRotation: Double) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    canvasElements.wrappedValue[index].rotation = newRotation
                }
            }
            // Add initial keyframe at time 0 with current element rotation
            track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
        } else if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> {
            // Update the initial keyframe with current element rotation if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
            }
        }
    }
    
    /// Sets up color animation track for an element
    private func setupColorTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        let colorTrackId = "\(idPrefix)_color"
        
        if animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = animationController.addTrack(id: colorTrackId) { (newColor: Color) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    canvasElements.wrappedValue[index].color = newColor
                }
            }
            // Add initial keyframe at time 0 with current element color
            track.add(keyframe: Keyframe(time: 0.0, value: element.color))
        } else if let track = animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> {
            // Update the initial keyframe with current element color if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.color, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.color))
            }
        }
    }
    
    /// Sets up opacity animation track for an element
    private func setupOpacityTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        let opacityTrackId = "\(idPrefix)_opacity"
        
        if animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: opacityTrackId) { (newOpacity: Double) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    canvasElements.wrappedValue[index].opacity = newOpacity
                }
            }
            // Add initial keyframe at time 0 with current element opacity
            track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
        } else if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> {
            // Update the initial keyframe with current element opacity if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
            }
        }
    }
    
    /// Sets up font size animation track for text elements
    private func setupFontSizeTrack(
        for element: CanvasElement,
        idPrefix: String,
        canvasElements: Binding<[CanvasElement]>
    ) {
        // Only set up font size track for text elements
        guard element.type == .text else { return }
        
        let fontSizeTrackId = "\(idPrefix)_fontSize"
        
        if animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> == nil {
            let track = animationController.addTrack(id: fontSizeTrackId) { (newFontSize: CGFloat) in
                if let index = canvasElements.wrappedValue.firstIndex(where: { $0.id == element.id }) {
                    canvasElements.wrappedValue[index].fontSize = newFontSize
                }
            }
            // Add initial keyframe at time 0 with current element font size
            track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
        } else if let track = animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> {
            // Update the initial keyframe with current element font size if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
            }
        }
    }
}