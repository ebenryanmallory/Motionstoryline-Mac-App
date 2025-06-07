import SwiftUI
import AppKit // For NSOpenPanel
import UniformTypeIdentifiers // For UTType

extension DesignCanvas {
    // File operation methods will be moved here

    // MARK: - Project Open Operations

    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "storyline")].compactMap { $0 }

        if panel.runModal() == .OK {
            if let url = panel.url {
                print("Attempting to open project file: \(url.path)")
                do {
                    // The tuple from loadProject is (elements: [CanvasElement], tracksData: [TrackData], duration: Double, canvasWidth: CGFloat, canvasHeight: CGFloat, projectName: String)
                    // We need to map this to the ProjectData struct that applyProjectData expects.
                    // DocumentManager.ProjectData is: { elements, tracks, duration, canvasWidth, canvasHeight, ... }
                    if let loadedTuple = try documentManager.loadProject(from: url) {
                        // Construct ProjectData from the tuple
                        let projectDataInstance = ProjectData(
                            elements: loadedTuple.elements,
                            tracks: loadedTuple.tracksData,
                            duration: loadedTuple.duration,
                            canvasWidth: loadedTuple.canvasWidth,
                            canvasHeight: loadedTuple.canvasHeight
                            // Removed version, metadata, colorProfiles, gridSettings as they are not in ProjectData init per build error
                        )
                        // If ProjectData struct is later updated to include version, metadata, colorProfiles, gridSettings as properties,
                        // they can be set here on projectDataInstance, e.g.:
                        // projectDataInstance.version = loadedTuple.version
                        // projectDataInstance.gridSettings = loadedTuple.gridSettings // Assuming loadedTuple provides this

                        self.applyProjectData(projectData: projectDataInstance)
                        
                        // Update project name in AppState
                        if self.appState.selectedProject != nil {
                            self.appState.selectedProject?.name = loadedTuple.projectName
                        } else {
                            print("Warning: No project currently selected in AppState. Project name from file not set.")
                        }

                        // Clear undo/redo history for the newly opened project
                        self.undoRedoManager.clearHistory()
                        print("Project loaded successfully. Undo/Redo history cleared.")
                        
                    }
                } catch {
                    print("Error loading project from DesignCanvas: \(error.localizedDescription)")
                    // Optionally, present an alert to the user
                }
            }
        }
    }

    func openProject(url: URL) {
        print("Attempting to open project from URL: \(url.path)")
        guard let projectData = try? documentManager.loadProject(from: url) else {
            print("Failed to load project from URL: \(url.path)")
            // Optionally: Show an error alert to the user
            let alert = NSAlert()
            alert.messageText = "Error Opening Project"
            alert.informativeText = "Could not open the project file at \(url.path). It might be corrupted or in an incompatible format."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        print("Project loaded successfully. Applying data...")
        isProgrammaticChange = true // Prevent marking as changed during state restoration

        // Apply loaded data
        self.canvasElements = projectData.elements
        self.canvasWidth = projectData.canvasWidth
        self.canvasHeight = projectData.canvasHeight
        
        // Rebuild AnimationController state
        self.animationController.reset()
        self.animationController.setup(duration: projectData.duration)
        // TODO: Reconstruct animation tracks and keyframes from projectData.tracksData
        // This requires mapping trackData.propertyName and trackData.valueType to actual types
        // and correctly setting up the updateCallback for each track.

        // Configure DocumentManager with the newly loaded state and URL
        // Note: documentManager.currentProjectURL is already set by loadProject(from:)
        configureDocumentManager()

        // Update AppState
        if let currentURL = documentManager.currentProjectURL {
            appState.currentProjectName = currentURL.deletingPathExtension().lastPathComponent
            print("Project name set to: \(appState.currentProjectName)")
        }
        appState.currentProjectURLToLoad = nil // Clear the request to load this URL

        // Reset UI states
        self.selectedElementId = nil
        self.zoom = 1.0
        self.viewportOffset = .zero
        self.appState.currentTimelineScale = 1.0 // Reset timeline zoom
        self.appState.currentTimelineOffset = 0.0 // Reset timeline offset

        self.undoRedoManager.clearHistory() // Clear undo/redo history for the newly loaded project
        self.documentManager.hasUnsavedChanges = false // A freshly loaded project has no unsaved changes

        self.isProgrammaticChange = false // Reset programmatic change flag
        print("Project data applied and UI reset for loaded project.")
    }

    // MARK: - Project Save Operations

    func handleSaveProject() {
        print("Handling Save Project action...")
        self.configureDocumentManager() // Ensure DocumentManager has the latest canvas state

        if self.documentManager.saveProject() {
            if let currentURL = self.documentManager.currentProjectURL {
                self.appState.currentProjectName = currentURL.deletingPathExtension().lastPathComponent
                print("Project saved successfully. New name: \(self.appState.currentProjectName)")
            }
            self.showSaveSuccessNotification()
        } else {
            print("Save project failed.")
            // Optionally: Show an error alert to the user
        }
    }

    func handleSaveProjectAs() {
        print("Handling Save Project As action...")
        self.configureDocumentManager() // Ensure DocumentManager has the latest canvas state

        if self.documentManager.saveProjectAs() {
            if let currentURL = self.documentManager.currentProjectURL {
                self.appState.currentProjectName = currentURL.deletingPathExtension().lastPathComponent
                print("Project saved as successfully. New name: \(self.appState.currentProjectName)")
            }
            self.showSaveSuccessNotification()
        } else {
            print("Save project as failed.")
            // Optionally: Show an error alert to the user
        }
    }
    
    // MARK: - Async Save Helper

    @MainActor
    internal func saveProjectAsync() async {
        handleSaveProject()
    }
}
