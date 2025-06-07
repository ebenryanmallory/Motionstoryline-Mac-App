import SwiftUI // For CGPoint, CGSize, Color
import Foundation // For TimeInterval

// Assuming AnimationController and CanvasElement are accessible (they are in the same module)

struct AnimationHelpers {
    static func applyAnimations(
        toElements initialElements: [CanvasElement],
        using animationController: AnimationController,
        at time: TimeInterval
    ) -> [CanvasElement] {
        var elementsAtTime = initialElements // Make a mutable copy

        for i in 0..<elementsAtTime.count {
            let element = elementsAtTime[i]
            let elementId = element.id.uuidString

            // Animate position
            let positionTrackId = "\(elementId)_position"
            if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint>,
               let positionValue = track.getValue(at: time) {
                elementsAtTime[i].position = positionValue
            }

            // Animate size (assuming size animation targets width, and height adjusts for aspect ratio)
            let sizeTrackId = "\(elementId)_size"
            if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat>, // Assuming CGFloat for width
               let newWidth = track.getValue(at: time) {
                if elementsAtTime[i].isAspectRatioLocked && element.size.width > 0 { // Avoid division by zero
                    let ratio = element.size.height / element.size.width
                    elementsAtTime[i].size = CGSize(width: newWidth, height: newWidth * ratio)
                } else {
                    elementsAtTime[i].size.width = newWidth
                }
            }
            
            // Animate height (if a separate height track exists)
            let heightTrackId = "\(elementId)_height"
            if let track = animationController.getTrack(id: heightTrackId) as? KeyframeTrack<CGFloat>,
               let newHeight = track.getValue(at: time) {
                if elementsAtTime[i].isAspectRatioLocked && element.size.height > 0 && !(animationController.getTrack(id: sizeTrackId) is KeyframeTrack<CGFloat>) {
                    let ratio = element.size.width / element.size.height
                    elementsAtTime[i].size = CGSize(width: newHeight * ratio, height: newHeight)
                } else if !elementsAtTime[i].isAspectRatioLocked {
                    elementsAtTime[i].size.height = newHeight
                }
            }


            // Animate rotation
            let rotationTrackId = "\(elementId)_rotation"
            if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double>,
               let rotationValue = track.getValue(at: time) {
                elementsAtTime[i].rotation = rotationValue
            }

            // Animate opacity
            let opacityTrackId = "\(elementId)_opacity"
            if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double>,
               let opacityValue = track.getValue(at: time) {
                elementsAtTime[i].opacity = opacityValue
            }

            // Animate color
            let colorTrackId = "\(elementId)_color"
            if let track = animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color>,
               let colorValue = track.getValue(at: time) {
                elementsAtTime[i].color = colorValue
            }

            // Animate path (if applicable)
            if element.type == .path {
                let pathTrackId = "\(elementId)_path"
                if let track = animationController.getTrack(id: pathTrackId) as? KeyframeTrack<[CGPoint]>,
                   let pathValue = track.getValue(at: time) {
                    elementsAtTime[i].path = pathValue
                }
            }
        }
        return elementsAtTime
    }
}
