import SwiftUI
import Combine
import AppKit

// Helper class to handle animation and export functionality for DesignCanvas
class CanvasController: ObservableObject {
    @Published var canvasElements: [CanvasElement] = []
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var exportingError: Error? = nil
    @Published var selectedElementId: UUID? = nil
    @Published var selectedElement: CanvasElement? = nil
    @Published var isEditingText: Bool = false
    @Published var isProgrammaticChange: Bool = false
    
    var animationController: AnimationController
    
    init(animationController: AnimationController) {
        self.animationController = animationController
    }
    
    /// Handles the creation of a text element at the specified location
    func handleTextCreation(at location: CGPoint) {
        // Create a new text element
        let newText = CanvasElement(
            type: .text,
            position: location,
            size: CGSize(width: 200, height: 60),
            color: .black,
            text: "New Text",
            fontSize: 16.0,
            displayName: "Text Element"
        )
        canvasElements.append(newText)
        selectedElementId = newText.id
        selectedElement = newText
        isEditingText = true
    }
    
    /// Handles element selection
    func handleElementSelection(_ element: CanvasElement) {
        // Update selected element state
        selectedElementId = element.id
        selectedElement = element
        
        // Update animation data
        updateAnimationPropertiesForSelectedElement(element)
        
        // Force UI update
        isProgrammaticChange = true
        isProgrammaticChange = false
    }
    
    /// Updates the animation properties when an element is selected
    func updateAnimationPropertiesForSelectedElement(_ element: CanvasElement?) {
        guard let element = element else { return }
        
        print("Updating animation properties for: \(element.displayName)")
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = animationController.addTrack(id: positionTrackId) { [weak self] (newPosition: CGPoint) in
                guard let self = self else { return }
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].position = newPosition
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
        
        // Size track (using width as the animatable property for simplicity)
        let sizeTrackId = "\(idPrefix)_size"
        if animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> == nil {
            let track = animationController.addTrack(id: sizeTrackId) { [weak self] (newSize: CGSize) in
                guard let self = self else { return }
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    // If aspect ratio is locked, maintain it
                    if self.canvasElements[index].isAspectRatioLocked {
                        let ratio = self.canvasElements[index].size.height / self.canvasElements[index].size.width
                        self.canvasElements[index].size = CGSize(width: newSize.width, height: newSize.width * ratio)
                    } else {
                        self.canvasElements[index].size = newSize
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
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        if animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: rotationTrackId) { [weak self] (newRotation: Double) in
                guard let self = self else { return }
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].rotation = newRotation
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
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        if animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = animationController.addTrack(id: colorTrackId) { [weak self] (newColor: Color) in
                guard let self = self else { return }
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].color = newColor
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
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        if animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: opacityTrackId) { [weak self] (newOpacity: Double) in
                guard let self = self else { return }
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].opacity = newOpacity
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
    
    /// Internal method to handle the actual export process
    func exportProject(
        format: ExportFormat,
        width: Int,
        height: Int,
        frameRate: Double,
        outputURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async {
        self.isExporting = true
        self.exportProgress = 0
        
        // Show save panel if needed
        let savePanel = await NSSavePanel.createExportSavePanel(for: format, defaultURL: outputURL)
        let response = await savePanel.beginSheetModal(for: NSApp.keyWindow!)
        
        if response == .OK, let finalURL = await savePanel.url {
            do {
                // Create the composition
                let resolution = CGSize(width: CGFloat(width), height: CGFloat(height))
                let exporter = try CompositionExporter(canvasElements: self.canvasElements, canvasSize: resolution)
                
                // Configure the export
                let configuration = ExportConfiguration(
                    format: .video,
                    width: resolution.width,
                    height: resolution.height,
                    frameRate: frameRate,
                    outputURL: finalURL
                )
                
                // Export the video using a local variable to capture self
                let controller = self
                await exporter.export(with: configuration, progressHandler: { progress in
                    let capturedProgress = progress
                    Task { @MainActor in
                        controller.exportProgress = max(controller.exportProgress, Double(capturedProgress))
                        progressHandler(Double(capturedProgress))
                    }
                }, completion: { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let url):
                            print("Export completed successfully: \(url.path)")
                            controller.isExporting = false
                            progressHandler(1.0)
                        case .failure(let error):
                            print("Export failed: \(error)")
                            controller.isExporting = false
                        }
                    }
                })
            } catch {
                print("Failed to create composition: \(error)")
                self.isExporting = false
            }
        } else {
            // User cancelled
            self.isExporting = false
        }
    }
}
