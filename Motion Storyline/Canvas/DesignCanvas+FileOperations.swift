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
                    // The tuple from loadProject is (elements: [CanvasElement], tracksData: [TrackData], duration: Double, canvasWidth: CGFloat, canvasHeight: CGFloat, mediaAssets: [MediaAsset], projectName: String)
                    // We need to map this to the ProjectData struct that applyProjectData expects.
                    // DocumentManager.ProjectData is: { elements, tracks, duration, canvasWidth, canvasHeight, mediaAssets, ... }
                    if let loadedTuple = try documentManager.loadProject(from: url) {
                        // Construct ProjectData from the tuple
                        let projectDataInstance = ProjectData(
                            elements: loadedTuple.elements,
                            tracks: loadedTuple.tracksData,
                            duration: loadedTuple.duration,
                            canvasWidth: loadedTuple.canvasWidth,
                            canvasHeight: loadedTuple.canvasHeight,
                            mediaAssets: loadedTuple.mediaAssets,
                            audioLayers: loadedTuple.audioLayers
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
        do {
            guard let loadedTuple = try documentManager.loadProject(from: url) else {
                print("Failed to load project from URL: \(url.path)")
                // Optionally: Show an error alert to the user
                let alert = NSAlert()
                alert.messageText = "Error Opening Project"
                alert.informativeText = "Could not open the project file at \(url.path). It might be corrupted or in an incompatible format."
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }

            // Construct ProjectData from the tuple for use with applyProjectData
            let projectDataInstance = ProjectData(
                elements: loadedTuple.elements,
                tracks: loadedTuple.tracksData,
                duration: loadedTuple.duration,
                canvasWidth: loadedTuple.canvasWidth,
                canvasHeight: loadedTuple.canvasHeight,
                mediaAssets: loadedTuple.mediaAssets,
                audioLayers: loadedTuple.audioLayers
            )

            print("Project loaded successfully. Applying data...")
            self.applyProjectData(projectData: projectDataInstance)
            
            // Update project name in AppState
            if self.appState.selectedProject != nil {
                self.appState.selectedProject?.name = loadedTuple.projectName
            } else {
                print("Warning: No project currently selected in AppState. Project name from file not set.")
            }

            // Clear undo/redo history for the newly loaded project
            self.undoRedoManager.clearHistory()
            print("Project loaded and applied successfully. Undo/Redo history cleared.")
            
        } catch {
            print("Error loading project from URL: \(error.localizedDescription)")
            // Optionally: Show an error alert to the user
            let alert = NSAlert()
            alert.messageText = "Error Opening Project"
            alert.informativeText = "Could not open the project file at \(url.path). Error: \(error.localizedDescription)"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Project Save Operations

    func handleSaveWorkingFile() {
        print("Handling Save Working File action...")
        self.configureDocumentManager() // Ensure DocumentManager has the latest canvas state

        if self.documentManager.saveWorkingFile() {
            if let projectURL = self.documentManager.projectURL {
                self.appState.currentProjectName = projectURL.deletingPathExtension().lastPathComponent
                print("Working file saved successfully. Name: \(self.appState.currentProjectName)")
            }
            self.showSaveSuccessNotification()
        } else {
            print("Save working file failed.")
            // Optionally: Show an error alert to the user
        }
    }

    func handleExportProjectAs() {
        print("Handling Export Project As action...")
        self.configureDocumentManager() // Ensure DocumentManager has the latest canvas state

        if self.documentManager.exportProjectAs() {
            if let exportURL = self.documentManager.projectURL {
                print("Project exported successfully to: \(exportURL.path)")
            }
            self.showExportSuccessNotification()
        } else {
            print("Export project as failed.")
            // Optionally: Show an error alert to the user
        }
    }
    
    func handleExportToCurrentLocation() {
        print("Handling Export to Current Location action...")
        self.configureDocumentManager() // Ensure DocumentManager has the latest canvas state
        
        if self.documentManager.exportToFile() {
            if let exportURL = self.documentManager.projectURL {
                print("Project exported successfully to: \(exportURL.path)")
            }
            self.showExportSuccessNotification()
        } else {
            print("Export to current location failed - no export location set.")
            // Optionally: Show an error alert or fall back to Export As
        }
    }
    
    // Legacy method for backward compatibility
    func handleSaveProject() {
        handleSaveWorkingFile()
    }
    
    // Legacy method for backward compatibility  
    func handleSaveProjectAs() {
        handleExportProjectAs()
    }
    
    // MARK: - Async Save Helper

    @MainActor
    internal func saveProjectAsync() async {
        handleSaveProject()
    }
    
    // MARK: - Notification Helpers
    
    private func showExportSuccessNotification() {
        // Provide haptic feedback for successful export
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        print("Export operation completed successfully")
    }
}
