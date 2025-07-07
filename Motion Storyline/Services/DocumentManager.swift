import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine
import AVFoundation

/// Manages document operations such as exporting, saving, and loading
@MainActor
class DocumentManager: ObservableObject {
    // Project state
    @Published var projectURL: URL? = nil // Single canonical project file location
    @Published var hasUnsavedChanges: Bool = false
    
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
    
    private var canvasElements: [CanvasElement] = []
    private var animationController: AnimationController?
    private var canvasSize: CGSize = CGSize(width: 1280, height: 720)
    private var currentProject: Project?
    private var audioLayers: [AudioLayer] = []
    private var preferencesViewModel: PreferencesViewModel?
    
    // Canvas size properties as single source of truth
    @Published var canvasWidth: Double = 1280
    @Published var canvasHeight: Double = 720
    
    // Public read-only access for debugging and validation
    var currentElementCount: Int { canvasElements.count }
    var currentTrackCount: Int { animationController?.getAllTracks().count ?? 0 }
    var currentAudioLayerCount: Int { audioLayers.count }
    var currentAudioLayers: [AudioLayer] { audioLayers }
    
    /// Set up the document manager with the current canvas state. This is typically called when DesignCanvas state changes.
    func configure(canvasElements: [CanvasElement], 
                  animationController: AnimationController,
                  canvasSize: CGSize,
                  currentProject: Project? = nil,
                  audioLayers: [AudioLayer] = [],
                  preferencesViewModel: PreferencesViewModel? = nil) {
        print("DocumentManager.configure called with \(canvasElements.count) elements and \(audioLayers.count) audio layers")
        
        self.canvasElements = canvasElements
        self.animationController = animationController
        self.canvasSize = canvasSize
        self.currentProject = currentProject
        self.audioLayers = audioLayers
        self.preferencesViewModel = preferencesViewModel
        
        // Initialize canvas size properties as single source of truth
        self.canvasWidth = Double(canvasSize.width)
        self.canvasHeight = Double(canvasSize.height)
        
        print("🔧 DocumentManager configured with \(canvasElements.count) elements, \(animationController.getAllTracks().count) tracks, \(audioLayers.count) audio layers, canvas size: \(canvasSize), hasUnsavedChanges: \(hasUnsavedChanges)")
    }
    
    /// Update only the audio layers without affecting other state
    func updateAudioLayers(_ audioLayers: [AudioLayer]) {
        self.audioLayers = audioLayers
        print("DocumentManager audio layers updated: \(audioLayers.count) layers")
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
    
    /// Exports the project to a new location chosen by the user ("Export As...").
    /// This creates an external copy without affecting the internal working file.
    /// Updates `projectURL` for future exports.
    func exportProjectAs() -> Bool {
        // Debug check to make sure canvas elements are properly set
        print("Initiating Export As... with \(canvasElements.count) canvas elements and \(audioLayers.count) audio layers")
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = true
        savePanel.nameFieldStringValue = projectURL?.lastPathComponent ?? "Motion Storyline Project.storyline"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "storyline")!]
        savePanel.message = "Export your Motion Storyline project"
        if let existingDir = projectURL?.deletingLastPathComponent() {
            savePanel.directoryURL = existingDir
        }
        
        let response = savePanel.runModal()
        
        guard response == .OK, let url = savePanel.url else {
            print("Export As cancelled by user or save panel failed.")
            return false
        }
        
        if performSaveInternal(to: url) {
            self.projectURL = url
            print("Project successfully exported to \(url.path)")
            return true
        } else {
            print("Failed to export project to \(url.path) during Export As operation.")
            return false
        }
    }

    /// Saves the internal working file. Always uses projectURL.
    /// Resets `hasUnsavedChanges` on success.
    func saveWorkingFile() -> Bool {
        // Validate that we have current data before saving
        if canvasElements.isEmpty {
            print("⚠️ WARNING: DocumentManager has no canvas elements to save!")
        }
        
        if let url = projectURL {
            print("💾 Saving working file to: \(url.path)")
            print("💾 Saving \(canvasElements.count) elements, \(animationController?.getAllTracks().count ?? 0) animation tracks, and \(audioLayers.count) audio layers")
            
            if performSaveInternal(to: url) {
                self.hasUnsavedChanges = false
                print("✅ Working file successfully saved to \(url.path)")
                return true
            } else {
                print("❌ Failed to save working file to \(url.path)")
                return false
            }
        } else {
            print("❌ No project URL set, cannot save working file")
            return false
        }
    }
    
    /// Exports to the current project location.
    /// This updates the external exported copy with current state.
    func exportToFile() -> Bool {
        guard let url = projectURL else {
            print("No project URL set, cannot export to file")
            return false
        }
        
        print("Exporting to existing project location: \(url.path) with \(canvasElements.count) elements and \(audioLayers.count) audio layers")
        if performSaveInternal(to: url) {
            print("Project successfully exported to \(url.path)")
            return true
        } else {
            print("Failed to export project to \(url.path)")
            return false
        }
    }
    
    /// Legacy method for backward compatibility - now delegates to working file save
    /// Resets `hasUnsavedChanges` on success.
    @available(*, deprecated, message: "Use saveWorkingFile() or exportProjectAs() instead")
    func saveProject() -> Bool {
        return saveWorkingFile()
    }

    /// Private helper function to perform the actual saving logic without showing a panel.
    private func performSaveInternal(to url: URL) -> Bool {
        // Debug check to make sure canvas elements are properly set
        print("💾 Starting save operation with \(canvasElements.count) canvas elements and \(audioLayers.count) audio layers")
        print("💾 Animation controller has \(animationController?.getAllTracks().count ?? 0) tracks")
        
        // Create project data structure
        let projectData = createProjectData()
        
        // Verify that elements were properly included
        if projectData.elements.isEmpty && !canvasElements.isEmpty {
            print("⚠️ WARNING: Project data has no elements despite \(canvasElements.count) canvas elements being available")
            print("⚠️ This indicates a serious state synchronization issue!")
            return false
        }
        
        print("💾 Created project data with \(projectData.elements.count) elements, \(projectData.tracks.count) tracks, and \(projectData.audioLayers.count) audio layers")
        
        do {
            // Encode the project data as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(projectData)
            
            // Debug info
            print("💾 Serialized project data size: \(data.count) bytes")
            
            // Write to file
            try data.write(to: url)
            print("✅ Successfully saved project to \(url.path)")
            
            // Provide haptic feedback on successful save
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            
            return true
        } catch {
            print("❌ Error performing save to \(url.path): \(error.localizedDescription)")
            
            // More detailed error logging
            if let encodingError = error as? EncodingError {
                switch encodingError {
                case .invalidValue(let value, let context):
                    print("❌ Encoding error: Invalid value \(value) at \(context.codingPath)")
                default:
                    print("❌ Other encoding error: \(encodingError)")
                }
            }
            
            // Provide error haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            
            return false
        }
    }
    
    /// Load a saved project from a file URL.
    /// Updates `projectURL` and resets `hasUnsavedChanges` on success.
    /// Also updates the PreferencesViewModel with the loaded canvas dimensions.
    func loadProject(from url: URL) throws -> (elements: [CanvasElement], tracksData: [TrackData], duration: Double, canvasWidth: CGFloat, canvasHeight: CGFloat, mediaAssets: [MediaAsset], audioLayers: [AudioLayer], projectName: String)? {
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
            
            // Successfully loaded, update document manager state
            self.projectURL = url
            self.hasUnsavedChanges = false // Project is clean right after loading
            
            // Update DocumentManager's canvas size properties as single source of truth
            self.canvasWidth = Double(projectData.canvasWidth)
            self.canvasHeight = Double(projectData.canvasHeight)
            self.canvasSize = CGSize(width: projectData.canvasWidth, height: projectData.canvasHeight)
            print("📐 Updated DocumentManager with loaded canvas dimensions: \(projectData.canvasWidth)x\(projectData.canvasHeight)")
            
            // Update preferences with loaded canvas preferences (grid settings, etc.)
            if let preferencesViewModel = preferencesViewModel {
                // Load canvas preferences if they exist
                if let canvasPreferences = projectData.canvasPreferences {
                    preferencesViewModel.showGrid = canvasPreferences.showGrid
                    preferencesViewModel.gridSize = canvasPreferences.gridSize
                    preferencesViewModel.gridColorR = canvasPreferences.gridColorR
                    preferencesViewModel.gridColorG = canvasPreferences.gridColorG
                    preferencesViewModel.gridColorB = canvasPreferences.gridColorB
                    preferencesViewModel.gridColorA = canvasPreferences.gridColorA
                    preferencesViewModel.canvasBgColorR = canvasPreferences.canvasBgColorR
                    preferencesViewModel.canvasBgColorG = canvasPreferences.canvasBgColorG
                    preferencesViewModel.canvasBgColorB = canvasPreferences.canvasBgColorB
                    preferencesViewModel.canvasBgColorA = canvasPreferences.canvasBgColorA
                    print("🎨 Updated preferences with loaded canvas preferences: showGrid=\(canvasPreferences.showGrid), gridSize=\(canvasPreferences.gridSize)")
                }
            }
            
            // Configure the document manager with the loaded data if it's supposed to hold it directly
            // Or, ensure the caller (DesignCanvas) calls configure() with this data.
            // For now, DesignCanvas is responsible for calling configure().
            // self.canvasElements = projectData.elements // This would be redundant if DesignCanvas configures
            // self.canvasSize = CGSize(width: projectData.canvasWidth, height: projectData.canvasHeight)
            // self.animationController = ... // Rebuilding AnimationController is complex here, better done in DesignCanvas

            print("Project successfully loaded from \(url.path)")
            return (projectData.elements, projectData.tracks, projectData.duration, projectData.canvasWidth, projectData.canvasHeight, projectData.mediaAssets, projectData.audioLayers, projectName)
        } catch {
            print("Error loading project: \(error.localizedDescription)")
            // Propagate the error so the caller can handle it
            self.projectURL = nil
            self.hasUnsavedChanges = false // Or true, depending on desired state after failed load
            throw error 
        }
    }
    
    // MARK: - Undo/Redo State Management

    /// Serializes the current project state into Data for undo/redo.
    func getCurrentProjectStateData() -> Data? {
        // Ensure animationController is available, otherwise state is incomplete
        guard self.animationController != nil else {
            print("Warning: AnimationController not available during state serialization for undo/redo.")
            // Depending on strictness, you might return nil or a partially valid state.
            // For robust undo, a complete state is preferred.
            return nil 
        }
        let projectData = createProjectData() // Uses current canvasElements, animationController, canvasSize
        do {
            let encoder = JSONEncoder()
            // No need for prettyPrinted for internal undo/redo states
            return try encoder.encode(projectData)
        } catch {
            print("Error encoding project state for undo/redo: \(error.localizedDescription)")
            return nil
        }
    }

    /// Deserializes Data back into ProjectData.
    func decodeProjectState(from data: Data) -> ProjectData? {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ProjectData.self, from: data)
        } catch {
            print("Error decoding project state for undo/redo: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private Helper Methods
    
    /// Create an export coordinator for handling the export process
    private func createExportCoordinator() -> ExportCoordinator {
        guard let asset = createAVAsset() else {
            fatalError("Failed to create asset for export")
        }
        
        print("Creating ExportCoordinator with animation data and \(audioLayers.count) audio layers")
        
        return ExportCoordinator(
            asset: asset, 
            animationController: animationController!,
            canvasElements: canvasElements,
            canvasSize: canvasSize,
            audioLayers: audioLayers
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
        
        // Debug info - print the number of canvas elements and audio layers
        print("Creating project data with \(canvasElements.count) canvas elements and \(audioLayers.count) audio layers")
        
        // Use DocumentManager's canvas size properties as single source of truth
        let canvasWidth = CGFloat(self.canvasWidth)
        let canvasHeight = CGFloat(self.canvasHeight)
        print("📐 Using canvas dimensions from DocumentManager: \(canvasWidth)x\(canvasHeight)")
        
        // Get all animation tracks
        guard let animationController = animationController else {
            print("Warning: No animation controller available when saving")
            return ProjectData(elements: canvasElements, tracks: [], duration: 5.0, canvasWidth: canvasWidth, canvasHeight: canvasHeight, mediaAssets: currentProject?.mediaAssets ?? [], audioLayers: audioLayers)
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
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGFloat> {
                valueType = "CGFloat"
                
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
                    // Proper serialization of color using RGB components
                    let color = keyframe.value
                    let valueString = colorToString(color)
                    
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: valueString,
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
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<[CGPoint]> {
                valueType = "[CGPoint]"
                
                for keyframe in track.allKeyframes {
                    let points = keyframe.value
                    let pointStrings = points.map { "{\($0.x),\($0.y)}" }
                    let valueString = "[\(pointStrings.joined(separator: ","))]"
                    
                    keyframes.append(KeyframeData(
                        time: keyframe.time,
                        value: valueString,
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
        
        // Create canvas preferences from the current preferences view model
        var canvasPreferences: CanvasPreferences? = nil
        if let preferencesViewModel = preferencesViewModel {
            canvasPreferences = CanvasPreferences(
                showGrid: preferencesViewModel.showGrid,
                gridSize: preferencesViewModel.gridSize,
                gridColorR: preferencesViewModel.gridColorR,
                gridColorG: preferencesViewModel.gridColorG,
                gridColorB: preferencesViewModel.gridColorB,
                gridColorA: preferencesViewModel.gridColorA,
                canvasBgColorR: preferencesViewModel.canvasBgColorR,
                canvasBgColorG: preferencesViewModel.canvasBgColorG,
                canvasBgColorB: preferencesViewModel.canvasBgColorB,
                canvasBgColorA: preferencesViewModel.canvasBgColorA
            )
        }
        
        // Create and return the project data
        let projectData = ProjectData(
            elements: canvasElements,
            tracks: tracks,
            duration: animationController.duration,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            mediaAssets: currentProject?.mediaAssets ?? [],
            audioLayers: audioLayers,
            canvasPreferences: canvasPreferences
        )
        
        // Verification check
        print("Project data created with \(projectData.elements.count) elements, \(projectData.tracks.count) tracks, and \(projectData.audioLayers.count) audio layers")
        
        return projectData
    }
    
    /// Convert easing function to string representation
    internal func easingToString(_ easing: EasingFunction) -> String {
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
    internal func easingFromString(_ easingString: String) -> EasingFunction {
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
    
    /// Convert Color to string representation for saving
    internal func colorToString(_ color: Color) -> String {
        #if canImport(AppKit)
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "rgba(1.0,1.0,1.0,1.0)" // Default to white
        }
        
        let r = rgbColor.redComponent
        let g = rgbColor.greenComponent
        let b = rgbColor.blueComponent
        let a = rgbColor.alphaComponent
        
        return "rgba(\(r),\(g),\(b),\(a))"
        #else
        // Fallback for non-macOS platforms
        return "rgba(1.0,1.0,1.0,1.0)"
        #endif
    }
    
    /// Convert string representation to Color
    internal func colorFromString(_ colorString: String) -> Color {
        // Parse format: "rgba(r,g,b,a)"
        guard colorString.hasPrefix("rgba(") && colorString.hasSuffix(")") else {
            return Color.white // Default fallback
        }
        
        let valuesString = String(colorString.dropFirst(5).dropLast())
        let components = valuesString.split(separator: ",").map { 
            Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0 
        }
        
        guard components.count == 4 else {
            return Color.white // Default fallback
        }
        
        #if canImport(AppKit)
        let nsColor = NSColor(red: CGFloat(components[0]), 
                             green: CGFloat(components[1]), 
                             blue: CGFloat(components[2]), 
                             alpha: CGFloat(components[3]))
        return Color(nsColor)
        #else
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
        #endif
    }
    
    /// Convert string representation to [CGPoint] array
    internal func pointArrayFromString(_ pointArrayString: String) -> [CGPoint] {
        // Parse format: "[{x1,y1},{x2,y2},{x3,y3}]"
        guard pointArrayString.hasPrefix("[") && pointArrayString.hasSuffix("]") else {
            return [] // Default to empty array
        }
        
        let content = String(pointArrayString.dropFirst().dropLast())
        if content.isEmpty {
            return []
        }
        
        var points: [CGPoint] = []
        var current = ""
        var braceLevel = 0
        
        for char in content {
            if char == "{" {
                braceLevel += 1
                current.append(char)
            } else if char == "}" {
                braceLevel -= 1
                current.append(char)
                
                if braceLevel == 0 {
                    // Parse the complete point
                    if let point = parsePoint(from: current) {
                        points.append(point)
                    }
                    current = ""
                }
            } else if char == "," && braceLevel == 0 {
                // Skip comma separators between points
                continue
            } else {
                current.append(char)
            }
        }
        
        return points
    }
    
    /// Parse a single CGPoint from string format "{x,y}"
    private func parsePoint(from pointString: String) -> CGPoint? {
        guard pointString.hasPrefix("{") && pointString.hasSuffix("}") else {
            return nil
        }
        
        let content = String(pointString.dropFirst().dropLast())
        let components = content.split(separator: ",").map { 
            Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0 
        }
        
        guard components.count == 2 else {
            return nil
        }
        
        return CGPoint(x: components[0], y: components[1])
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
    var mediaAssets: [MediaAsset] = [] // Add media assets to project data
    var audioLayers: [AudioLayer] = [] // Add audio layers to project data
    var canvasPreferences: CanvasPreferences? = nil // Add canvas preferences
}

/// Canvas preferences data structure
struct CanvasPreferences: Codable {
    var showGrid: Bool
    var gridSize: Double
    var gridColorR: Double
    var gridColorG: Double
    var gridColorB: Double
    var gridColorA: Double
    var canvasBgColorR: Double
    var canvasBgColorG: Double
    var canvasBgColorB: Double
    var canvasBgColorA: Double
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