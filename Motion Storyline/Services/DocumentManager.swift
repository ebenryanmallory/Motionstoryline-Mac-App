import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import AVFoundation

/// Manages document operations such as exporting, saving, and loading
@MainActor
class DocumentManager: ObservableObject {
    // Export state
    @Published var isExporting = false
    @Published var exportProgress: Float = 0
    @Published var exportFormat: ExportFormat = .video
    @Published var selectedProResProfile: VideoExporter.ProResProfile = .proRes422HQ
    @Published var exportResolution: (width: Int, height: Int) = (1280, 720)
    @Published var exportFrameRate: Float = 30.0
    @Published var exportDuration: Double = 5.0
    @Published var exportingError: Error?
    
    // Notify when export is complete
    let exportCompletedSubject = PassthroughSubject<URL, Never>()
    var exportCompleted: AnyPublisher<URL, Never> {
        exportCompletedSubject.eraseToAnyPublisher()
    }
    
    // Project state
    private var canvasElements: [CanvasElement] = []
    private var animationController: AnimationController?
    private var canvasSize: CGSize = CGSize(width: 1280, height: 720)
    
    /// Set up the document manager with the current canvas state
    func configure(canvasElements: [CanvasElement], 
                  animationController: AnimationController,
                  canvasSize: CGSize) {
        self.canvasElements = canvasElements
        self.animationController = animationController
        self.canvasSize = canvasSize
    }
    
    /// Export the timeline to a video or image sequence
    func exportTimeline() {
        guard animationController != nil else {
            self.exportingError = NSError(domain: "DocumentManager", 
                                         code: 1, 
                                         userInfo: [NSLocalizedDescriptionKey: "Animation controller not configured"])
            return
        }
        
        isExporting = true
        exportProgress = 0
        
        // Create an export coordinator
        let coordinator = createExportCoordinator()
        
        // Set up export configuration
        let configuration = createExportConfiguration()
        
        // Start export
        Task {
            do {
                // Start the export process
                let exportURL = try await coordinator.export(
                    with: configuration,
                    progressHandler: { [weak self] progress in
                        Task { @MainActor in
                            self?.exportProgress = progress
                        }
                    }
                )
                
                // Handle successful export
                await MainActor.run {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.exportCompletedSubject.send(exportURL)
                    
                    // Show the exported file in Finder
                    NSWorkspace.shared.activateFileViewerSelecting([exportURL])
                    
                    // Provide haptic feedback for export completion
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                }
            } catch {
                // Handle export failure
                await MainActor.run {
                    self.isExporting = false
                    self.exportingError = error
                    
                    // Provide error haptic feedback
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                }
            }
        }
    }
    
    /// Save the current state of the project
    func saveCurrentState() -> Bool {
        // Debug check to make sure canvas elements are properly set
        print("Starting save with \(canvasElements.count) canvas elements")
        
        // Create a save panel to choose where to save the file
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.nameFieldStringValue = "Motion Storyline Project.storyline"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "storyline")!]
        savePanel.message = "Save your Motion Storyline project"
        
        let response = savePanel.runModal()
        
        guard response == .OK, let url = savePanel.url else {
            return false
        }
        
        // Create project data structure
        let projectData = createProjectData()
        
        // Verify that elements were properly included
        if projectData.elements.isEmpty && !canvasElements.isEmpty {
            print("WARNING: Project data has no elements despite \(canvasElements.count) canvas elements being available")
        }
        
        do {
            // Encode the project data as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projectData)
            
            // Debug info
            print("Serialized project data size: \(data.count) bytes")
            
            // Write to file
            try data.write(to: url)
            print("Successfully saved project to \(url.path)")
            
            // Provide haptic feedback on successful save
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            
            return true
        } catch {
            print("Error saving project: \(error.localizedDescription)")
            
            // More detailed error logging
            if let encodingError = error as? EncodingError {
                switch encodingError {
                case .invalidValue(let value, let context):
                    print("Encoding error: Invalid value \(value) at \(context.codingPath)")
                default:
                    print("Other encoding error: \(encodingError)")
                }
            }
            
            // Provide error haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            
            return false
        }
    }
    
    /// Load a saved project from a file URL
    func loadProject(from url: URL) throws -> (elements: [CanvasElement], tracksData: [TrackData], duration: Double, canvasWidth: CGFloat, canvasHeight: CGFloat, projectName: String)? {
        // Note: The NSOpenPanel logic is now handled by the caller (e.g., DesignCanvas)
        
        do {
            // Read the file data
            let data = try Data(contentsOf: url)
            
            // Decode the project data
            let decoder = JSONDecoder()
            let projectData = try decoder.decode(ProjectData.self, from: data)
            
            // Project data is now successfully decoded.
            // We will return the raw data for elements, tracks, duration, and canvas dimensions.
            // The AnimationController will be reconstructed in DesignCanvas.
            
            let projectName = url.deletingPathExtension().lastPathComponent
            return (projectData.elements, projectData.tracks, projectData.duration, projectData.canvasWidth, projectData.canvasHeight, projectName)
        } catch {
            print("Error loading project: \(error.localizedDescription)")
            // Propagate the error so the caller can handle it
            throw error 
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Create an export coordinator for handling the export process
    private func createExportCoordinator() -> ExportCoordinator {
        guard let asset = createAVAsset() else {
            fatalError("Failed to create asset for export")
        }
        
        return ExportCoordinator(
            asset: asset, 
            animationController: animationController!,
            canvasElements: canvasElements,
            canvasSize: canvasSize
        )
    }
    
    /// Create an AVAsset for the export process
    private func createAVAsset() -> AVAsset? {
        // This would be implemented based on how the app creates assets
        // For now, just return nil to indicate this needs implementation
        return nil
    }
    
    /// Create export configuration based on current settings
    private func createExportConfiguration() -> ExportCoordinator.ExportConfiguration {
        // Create the export directory URL first
        let outputDir = getExportDirectory()
        let filename = "Export_\(Date().timeIntervalSince1970)"
        let outputURL = outputDir.appendingPathComponent(filename)
        
        return ExportCoordinator.ExportConfiguration(
            format: exportFormat,
            width: exportResolution.width,
            height: exportResolution.height,
            frameRate: exportFrameRate,
            numberOfFrames: Int(exportDuration * Double(exportFrameRate)),
            outputURL: outputURL,
            proResProfile: selectedProResProfile,
            includeAudio: true,
            baseFilename: filename,
            imageQuality: 0.9
        )
    }
    
    /// Get the directory where exports should be saved
    private func getExportDirectory() -> URL {
        let fileManager = FileManager.default
        
        // Try to get the Desktop directory
        if let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first {
            let exportDirURL = desktopURL.appendingPathComponent("Motion Storyline Exports")
            
            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: exportDirURL.path) {
                do {
                    try fileManager.createDirectory(at: exportDirURL, withIntermediateDirectories: true)
                    return exportDirURL
                } catch {
                    print("Error creating export directory: \(error.localizedDescription)")
                }
            } else {
                return exportDirURL
            }
        }
        
        // Fallback to documents directory
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// Create project data structure for saving
    private func createProjectData() -> ProjectData {
        var tracks: [TrackData] = []
        
        // Debug info - print the number of canvas elements
        print("Creating project data with \(canvasElements.count) canvas elements")
        
        // Get all animation tracks
        guard let animationController = animationController else {
            print("Warning: No animation controller available when saving")
            return ProjectData(elements: canvasElements, tracks: [], duration: 5.0, canvasWidth: self.canvasSize.width, canvasHeight: self.canvasSize.height)
        }
        
        let trackIds = animationController.getAllTracks()
        print("Found \(trackIds.count) animation tracks to save")
        
        // Process each track and its keyframes
        for trackId in trackIds {
            var keyframes: [KeyframeData] = []
            var valueType = "Unknown"
            
            // Handle different track types
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
                valueType = "CGPoint"
                
                for keyframe in track.allKeyframes {
                    let point = keyframe.value
                    let valueString = "{\(point.x),\(point.y)}"
                    
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: valueString,
                        easing: easingToString(keyframe.easingFunction)
                    ))
                }
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Double> {
                valueType = "Double"
                
                for keyframe in track.allKeyframes {
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: "\(keyframe.value)",
                        easing: easingToString(keyframe.easingFunction)
                    ))
                }
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Color> {
                valueType = "Color"
                
                for keyframe in track.allKeyframes {
                    // Basic serialization of color - ideally you'd use a more robust method
                    keyframes.append(KeyframeData(
                        time: keyframe.time, 
                        value: "Color", // In the real implementation, you'd encode the actual color values
                        easing: easingToString(keyframe.easingFunction)
                    ))
                }
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGSize> {
                valueType = "CGSize"
                
                for keyframe in track.allKeyframes {
                    let size = keyframe.value
                    let valueString = "{\(size.width),\(size.height)}"
                    
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: valueString,
                        easing: easingToString(keyframe.easingFunction)
                    ))
                }
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<String> {
                valueType = "String"
                
                for keyframe in track.allKeyframes {
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: keyframe.value,
                        easing: easingToString(keyframe.easingFunction)
                    ))
                }
            }
            
            // Add track data if we found keyframes
            if !keyframes.isEmpty {
                tracks.append(TrackData(id: trackId, valueType: valueType, keyframes: keyframes))
                print("Added track \(trackId) with \(keyframes.count) keyframes of type \(valueType)")
            }
        }
        
        // Create and return the project data
        let projectData = ProjectData(
            elements: canvasElements,
            tracks: tracks,
            duration: animationController.duration,
            canvasWidth: self.canvasSize.width,
            canvasHeight: self.canvasSize.height
        )
        
        // Verification check
        print("Project data created with \(projectData.elements.count) elements and \(projectData.tracks.count) tracks")
        
        return projectData
    }
    
    /// Convert easing function to string representation
    private func easingToString(_ easing: EasingFunction) -> String {
        switch easing {
        case .linear: return "linear"
        case .easeIn: return "easeIn"
        case .easeOut: return "easeOut"
        case .easeInOut: return "easeInOut"
        case .bounce: return "bounce"
        case .elastic: return "elastic"
        case .spring: return "spring"
        case .sine: return "sine"
        case .customCubicBezier(let x1, let y1, let x2, let y2):
            return "customCubicBezier(\(x1),\(y1),\(x2),\(y2))"
        }
    }

    /// Convert string representation to easing function
    private func easingFromString(_ easingString: String) -> EasingFunction {
        switch easingString.lowercased() {
        case "linear": return .linear
        case "easein": return .easeIn
        case "easeout": return .easeOut
        case "easeinout": return .easeInOut
        case "bounce": return .bounce
        case "elastic": return .elastic
        case "spring": return .spring
        case "sine": return .sine
        // Basic parsing for customCubicBezier. Robust parsing would require regex or more complex string manipulation.
        // Example: "customCubicBezier(0.25,0.1,0.25,1.0)"
        case let str where str.hasPrefix("customcubicbezier("):
            let paramsString = str.dropFirst("customcubicbezier(".count).dropLast()
            let params = paramsString.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0 }
            if params.count == 4 {
                return .customCubicBezier(x1: params[0], y1: params[1], x2: params[2], y2: params[3])
            }
            return .linear // Fallback
        default: return .linear // Default to linear if string is unrecognized
        }
    }
}

// MARK: - Project Data Structures

/// Main project data structure
struct ProjectData: Codable {
    var elements: [CanvasElement]
    var tracks: [TrackData]
    var duration: Double
    var canvasWidth: CGFloat
    var canvasHeight: CGFloat
}

/// Data structure for animation tracks
struct TrackData: Codable {
    var id: String
    var valueType: String
    var keyframes: [KeyframeData]
}

/// Data structure for keyframes
struct KeyframeData: Codable {
    var time: Double
    var value: String
    var easing: String
} 