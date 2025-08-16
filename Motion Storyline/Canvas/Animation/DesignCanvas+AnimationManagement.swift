import SwiftUI
import Foundation

// MARK: - Animation Management Extension
extension DesignCanvas {
    
    // MARK: - Project Data Management
    
    internal func applyProjectData(projectData: ProjectData) {
        print("Project loaded successfully. Applying data...")
        isProgrammaticChange = true // Prevent marking as changed during state restoration

        // Apply loaded data
        self.canvasElements = projectData.elements
        self.canvasWidth = projectData.canvasWidth
        self.canvasHeight = projectData.canvasHeight
        
        // Set canvas dimensions in document model as single source of truth
        documentManager.canvasWidth = Double(projectData.canvasWidth)
        documentManager.canvasHeight = Double(projectData.canvasHeight)
        
        // Update grid settings to match loaded preferences
        showGrid = preferencesViewModel.showGrid
        gridSize = CGFloat(preferencesViewModel.gridSize)
        
        // Update the current project with loaded media assets
        if self.appState.selectedProject != nil {
            self.appState.selectedProject?.mediaAssets = projectData.mediaAssets
        }
        
        // Load and apply audio layers
        self.audioLayers = projectData.audioLayers
        self.audioLayerManager.clearAllAudioLayers()
        for audioLayer in projectData.audioLayers {
            self.audioLayerManager.addAudioLayer(audioLayer)
        }
        print("Loaded \(projectData.audioLayers.count) audio layers into timeline")
        
        // Rebuild AnimationController state
        self.animationController.reset()
        self.animationController.setup(duration: projectData.duration)
        
        // Reconstruct animation tracks and keyframes from saved data
        print("Reconstructing \(projectData.tracks.count) animation tracks...")
        for trackData in projectData.tracks {
            // Parse track ID to get element ID and property name
            let components = trackData.id.split(separator: "_", maxSplits: 1)
            guard components.count == 2, 
                  let elementID = UUID(uuidString: String(components[0])) else {
                print("Warning: Could not parse trackId \(trackData.id) into elementID and propertyName.")
                continue
            }
            
            let propertyName = String(components[1])
            
            // Find the element index for the update callback
            guard let elementIndex = self.canvasElements.firstIndex(where: { $0.id == elementID }) else {
                print("Warning: Element with ID \(elementID) not found for track \(trackData.id).")
                continue
            }
            
            // Create the appropriate track based on value type
            switch trackData.valueType {
            case "Double":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: Double) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        switch propertyName {
                        case "opacity": 
                            self.canvasElements[elementIndex].opacity = newValue
                        case "rotation": 
                            self.canvasElements[elementIndex].rotation = newValue
                        case "scale": 
                            self.canvasElements[elementIndex].scale = CGFloat(newValue)
                        default: 
                            print("Warning: Update callback for Double property \(propertyName) not implemented.")
                        }
                    }
                }
                // Add keyframes with proper easing restoration
                for keyframeData in trackData.keyframes {
                    if let value = Double(keyframeData.value) {
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } else {
                        print("Warning: Could not parse Double for keyframe value: \(keyframeData.value)")
                    }
                }
                
            case "CGFloat":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGFloat) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        switch propertyName {
                        case "size":
                            // Handle size as width scaling, maintaining aspect ratio if locked
                            let element = self.canvasElements[elementIndex]
                            if element.isAspectRatioLocked && element.size.width > 0 {
                                let ratio = element.size.height / element.size.width
                                self.canvasElements[elementIndex].size = CGSize(width: newValue, height: newValue * ratio)
                            } else {
                                self.canvasElements[elementIndex].size.width = newValue
                            }
                        case "fontSize":
                            self.canvasElements[elementIndex].fontSize = newValue
                        default:
                            print("Warning: Update callback for CGFloat property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    if let value = Double(keyframeData.value).map({ CGFloat($0) }) {
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } else {
                        print("Warning: Could not parse CGFloat for keyframe value: \(keyframeData.value)")
                    }
                }
                
            case "CGPoint":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGPoint) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "position" {
                            self.canvasElements[elementIndex].position = newValue
                        } else {
                            print("Warning: Update callback for CGPoint property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    do {
                        let value = try CanvasElement.decodeCGPoint(from: keyframeData.value)
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } catch {
                        print("Warning: Could not parse CGPoint for keyframe value: \(keyframeData.value). Error: \(error.localizedDescription)")
                    }
                }
                
            case "CGSize":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGSize) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "size" {
                            self.canvasElements[elementIndex].size = newValue
                        } else {
                            print("Warning: Update callback for CGSize property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    do {
                        let value = try CanvasElement.decodeCGSize(from: keyframeData.value)
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } catch {
                        print("Warning: Could not parse CGSize for keyframe value: \(keyframeData.value). Error: \(error.localizedDescription)")
                    }
                }
                
            case "Color":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: Color) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "color" {
                            self.canvasElements[elementIndex].color = newValue
                        } else {
                            print("Warning: Update callback for Color property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    let color = self.documentManager.colorFromString(keyframeData.value)
                    let easing = self.documentManager.easingFromString(keyframeData.easing)
                    track.add(keyframe: Keyframe(time: keyframeData.time, value: color, easingFunction: easing))
                }
                
            case "String":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: String) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "text" {
                            self.canvasElements[elementIndex].text = newValue
                        } else {
                            print("Warning: Update callback for String property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    let easing = self.documentManager.easingFromString(keyframeData.easing)
                    track.add(keyframe: Keyframe(time: keyframeData.time, value: keyframeData.value, easingFunction: easing))
                }
                
            case "[CGPoint]":
                // TODO: Implement path/custom shape support in CanvasElement
                print("Warning: [CGPoint] track type not yet supported. CanvasElement needs a path property.")
                
            default:
                print("Warning: Unsupported track valueType '\(trackData.valueType)' for track \(trackData.id) during project load.")
            }
        }
        
        // Notify the animation controller that tracks have been updated
        self.animationController.objectWillChange.send()
        print("Successfully reconstructed \(projectData.tracks.count) animation tracks with all keyframes and easing functions.")
        
        // Set animation controller for audio layer manager
        self.audioLayerManager.setAnimationController(self.animationController)
        
        // Set up audio layer change callback for document tracking
        self.audioLayerManager.onAudioLayerChanged = { actionName in
            Task { @MainActor in
                self.markDocumentAsChanged(actionName: actionName)
            }
        }

        // Configure DocumentManager with the newly loaded state
        // The projectURL is preserved during this configuration
        configureDocumentManager()

        // Update AppState
        if let projectURL = documentManager.projectURL {
            let rawName = projectURL.deletingPathExtension().lastPathComponent
            appState.currentProjectName = appState.cleanProjectName(rawName)
            print("Project name set to: \(appState.currentProjectName)")
        }
        appState.currentProjectURLToLoad = nil // Clear the request to load this URL

        // Reset UI states only when loading from file (not during undo/redo)
        if !isProgrammaticChange {
            self.selectedElementId = nil
            self.zoom = 1.0
            self.viewportOffset = .zero
            self.appState.currentTimelineScale = 1.0 // Reset timeline zoom
            self.appState.currentTimelineOffset = 0.0 // Reset timeline offset
            self.undoRedoManager.clearHistory() // Clear undo/redo history for the newly loaded project
            self.documentManager.hasUnsavedChanges = false // A freshly loaded project has no unsaved changes
        } else {
            print("🔄 Preserving UI state during programmatic change (undo/redo)")
        }

        self.isProgrammaticChange = false // Reset programmatic change flag
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("Project data applied and UI reset for loaded project.")
    }
    
    internal func configureDocumentManager() {
        documentManager.configure(
            canvasElements: self.canvasElements,
            animationController: self.animationController,
            canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight),
            currentProject: appState.selectedProject,
            audioLayers: self.audioLayers,
            preferencesViewModel: self.preferencesViewModel
        )
        print("🔧 DocumentManager configured with \(canvasElements.count) elements, \(animationController.getAllTracks().count) tracks, \(audioLayers.count) audio layers, hasUnsavedChanges: \(documentManager.hasUnsavedChanges)")
    }
}