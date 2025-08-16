import SwiftUI
import Foundation
import AppKit
@preconcurrency import AVFoundation

// MARK: - Project Operations Extension
extension DesignCanvas {
    
    // MARK: - Auto-Save Operations
    
    /// Auto-saves the project without showing dialogs
    internal func autoSaveProject() {
        print("🔄 Starting auto-save process...")
        print("🔄 Current canvas state: \(canvasElements.count) elements")
        
        // Configure the document manager with current state to ensure consistency
        configureDocumentManager()
        
        // Validate that DocumentManager has the correct state before saving
        let expectedElementCount = canvasElements.count
        let actualElementCount = documentManager.currentElementCount
        
        if expectedElementCount != actualElementCount {
            print("⚠️ WARNING: State mismatch detected!")
            print("⚠️ Expected \(expectedElementCount) elements, DocumentManager has \(actualElementCount)")
            print("⚠️ Reconfiguring DocumentManager...")
            
            // Force reconfigure if there's a mismatch
            configureDocumentManager()
        }
        
        print("🔄 DocumentManager configured with \(documentManager.currentElementCount) elements, \(documentManager.currentTrackCount) tracks")
        
        // Always use project file for auto-save
        let success = documentManager.saveWorkingFile()
        if success {
            print("✅ Project auto-saved successfully")
        } else {
            print("❌ Failed to auto-save project - no project URL set")
            // If no project URL is set, create one
            createDefaultProjectFile()
        }
    }
    
    /// Creates a default project file location for new projects
    internal func createDefaultProjectFile() {
        guard let project = appState.selectedProject else {
            print("Could not create default project file: no selected project")
            return
        }
        
        // Use the UUID-based URL construction for uniqueness
        let saveURL = constructProjectURL(for: project)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = project.name // Use the actual project name, not the filename
        
        // Now actually save the project file
        let success = documentManager.saveWorkingFile()
        
        if success {
            print("Project file auto-saved to: \(saveURL.path)")
        } else {
            print("Failed to auto-save project file to: \(saveURL.path)")
        }
    }
    
    // MARK: - Project File Management
    
    /// Shows an error alert when save fails
    private func showSaveErrorAlert() {
        let alert = NSAlert()
        alert.messageText = "Save Failed"
        alert.informativeText = "Could not save the project. Please try again or choose a different location."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Creates the projects directory if it doesn't exist
    private func ensureProjectsDirectoryExists() -> URL? {
        let fileManager = FileManager.default
        
        // Get the Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents directory")
            return nil
        }
        
        // Create Motion Storyline Projects folder if it doesn't exist
        let projectsFolder = documentsURL.appendingPathComponent("Motion Storyline Projects")
        if !fileManager.fileExists(atPath: projectsFolder.path) {
            do {
                try fileManager.createDirectory(at: projectsFolder, withIntermediateDirectories: true)
                print("Created projects directory at: \(projectsFolder.path)")
            } catch {
                print("Failed to create projects folder: \(error.localizedDescription)")
                return nil
            }
        }
        
        return projectsFolder
    }
    
    /// Prepares a new project for auto-save by setting up a default project file URL
    private func prepareNewProjectForAutoSave() {
        guard let project = appState.selectedProject else {
            print("Could not prepare project for auto-save: no selected project")
            return
        }
        
        // Use the UUID-based URL construction for uniqueness
        let saveURL = constructProjectURL(for: project)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = project.name // Use the actual project name, not the filename
        
        print("Prepared new project for auto-save at: \(saveURL.path)")
    }
    
    /// Loads a project from the file system based on the selected project
    internal func loadProjectFromSelection(_ project: Project) {
        print("🔄 Loading project from selection: \(project.name)")
        
        // Create the expected file path based on project UUID for uniqueness
        let projectURL = constructProjectURL(for: project)
        
        // Check if the project file exists
        if FileManager.default.fileExists(atPath: projectURL.path) {
            print("📁 Found existing project file at: \(projectURL.path)")
            
            // Load the existing project file
            do {
                guard let loadedTuple = try documentManager.loadProject(from: projectURL) else {
                    print("❌ Failed to load project data from: \(projectURL.path)")
                    setupNewProject(for: project)
                    return
                }
                
                // Construct ProjectData from the loaded tuple
                let projectDataInstance = ProjectData(
                    elements: loadedTuple.elements,
                    tracks: loadedTuple.tracksData,
                    duration: loadedTuple.duration,
                    canvasWidth: loadedTuple.canvasWidth,
                    canvasHeight: loadedTuple.canvasHeight,
                    mediaAssets: loadedTuple.mediaAssets,
                    audioLayers: loadedTuple.audioLayers
                )
                
                print("✅ Successfully loaded project with \(loadedTuple.elements.count) elements")
                
                // CRITICAL: Store the original project URL for restoration during save operations
                // This prevents filename mismatches that cause changes not to persist between sessions
                originalProjectURL = projectURL
                
                // CRITICAL: Set DocumentManager projectURL before applying data
                // This ensures auto-save operations use the correct project file
                documentManager.projectURL = projectURL
                
                // Apply the loaded project data
                applyProjectData(projectData: projectDataInstance)
                
                // IMPORTANT: Do NOT modify appState.selectedProject?.name here!
                // The selectedProject must maintain its original structure for URL reconstruction.
                // Display names are handled separately in the TopBar using cleanProjectName().
                
                print("🎯 Project '\(project.name)' loaded successfully from file")
                
            } catch {
                print("❌ Error loading project file: \(error.localizedDescription)")
                // Fall back to creating a new project
                setupNewProject(for: project)
            }
        } else {
            print("📄 No existing file found for '\(project.name)', setting up new project")
            // No existing file, set up as a new project
            setupNewProject(for: project)
        }
    }
    
    // MARK: - URL Construction
    
    /// Constructs the expected file URL for a project using its unique ID
    internal func constructProjectURL(for project: Project) -> URL {
        // Ensure the projects directory exists and get its URL
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            fatalError("Could not access or create Motion Storyline Projects directory")
        }
        
        // Use project UUID to ensure uniqueness, with human-readable name as prefix
        let sanitizedName = project.name.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Create filename using both name and UUID for uniqueness
        let filename = "\(baseFilename)_\(project.id.uuidString).storyline"
        return projectsFolder.appendingPathComponent(filename)
    }
    
    /// Legacy method for backward compatibility - constructs URL based on project name only
    internal func constructProjectURL(for projectName: String) -> URL {
        // Ensure the projects directory exists and get its URL
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            fatalError("Could not access or create Motion Storyline Projects directory")
        }
        
        // Sanitize the project name for filename (same logic as save methods)
        let sanitizedName = projectName.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Always use the exact project name - no auto-incrementing or version scanning
        let filename = "\(baseFilename).storyline"
        return projectsFolder.appendingPathComponent(filename)
    }
    
    // MARK: - Project Setup
    
    /// Sets up a new project with default elements and prepares it for saving
    private func setupNewProject(for project: Project) {
        print("🆕 Setting up new project: \(project.name)")
        
        // Reset to default canvas elements for new projects
        isProgrammaticChange = true
        
        // Set default elements for new projects
        canvasElements = createDefaultCanvasElements()
        
        // Reset canvas properties using document manager
        canvasWidth = CGFloat(documentManager.canvasWidth)
        canvasHeight = CGFloat(documentManager.canvasHeight)
        zoom = 1.0
        viewportOffset = .zero
        selectedElementId = nil
        selectedElement = nil
        
        // Reset animation controller
        animationController.reset()
        animationController.setup(duration: 3.0)
        
        // Set up initial animations for default elements
        setupInitialAnimations()
        
        // Set up document manager with the correct project URL for this new project
        let projectURL = constructProjectURL(for: project)
        documentManager.projectURL = projectURL
        documentManager.hasUnsavedChanges = false
        
        // Configure DocumentManager with the new state
        configureDocumentManager()
        
        // Prepare for auto-saving with the correct internal working file URL
        prepareNewProjectForAutoSave()
        
        isProgrammaticChange = false
        
        print("✅ New project '\(project.name)' set up with default elements")
    }
    
    // MARK: - View Lifecycle
    
    internal func handleViewAppear() {
        // Perform one-time initialization
        if !hasInitializedProject {
            hasInitializedProject = true
            
            canvasWidth = CGFloat(documentManager.canvasWidth)
            canvasHeight = CGFloat(documentManager.canvasHeight)
            
            showGrid = preferencesViewModel.showGrid
            gridSize = CGFloat(preferencesViewModel.gridSize)
            snapToGridEnabled = preferencesViewModel.showGrid && preferencesViewModel.snapToGrid
            
            keyMonitorController.setupMonitor(
                onSpaceDown: {
                    isSpaceBarPressed = true
                    NSCursor.openHand.set()
                },
                onSpaceUp: {
                    isSpaceBarPressed = false
                    if selectedTool == .select {
                        NSCursor.arrow.set()
                    } else if selectedTool == .rectangle || selectedTool == .ellipse {
                        NSCursor.crosshair.set()
                    }
                }
            )
            
            keyMonitorController.setupCanvasKeyboardShortcuts(
                zoomIn: zoomIn,
                zoomOut: zoomOut,
                resetZoom: resetZoom,
                saveProject: { 
                    print("💾 Manual save triggered via keyboard shortcut")
                    self.handleSaveWorkingFile()
                },
                deleteSelectedElement: {
                    if let elementId = selectedElementId {
                        deleteElementAndCleanupTracks(elementId: elementId, actionName: "Delete Element")
                    }
                }
            )

            // Wire global Delete command to post a notification that the canvas listens for
            appState.deleteAction = {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DeleteSelectedCanvasElement"),
                    object: nil
                )
            }

            // Wire clipboard and file actions
            // TODO: Implement clipboard functions
            // appState.cutAction = { [self] in cutSelectedElement() }
            // appState.copyAction = { [self] in copySelectedElement() }
            // appState.pasteAction = { [self] in pasteElement() }
            // appState.selectAllAction = { [self] in selectAllElements() }
            appState.saveAction = { [self] in handleSaveWorkingFile() }
            appState.saveAsAction = { [self] in handleExportProjectAs() }
            // appState.openProjectAction = { [self] in openProject() } // TODO: Fix URL parameter
            // Listen for new screen recordings and import into project
            NotificationCenter.default.addObserver(forName: Notification.Name("NewScreenRecordingAvailable"), object: nil, queue: .main) { notification in
                guard var project = self.appState.selectedProject else { return }
                if let userInfo = notification.userInfo, let url = userInfo["url"] as? URL {
                    let name = url.lastPathComponent
                    let dimensions = MediaAsset.extractDimensions(from: url, type: .video)
                    let asset = MediaAsset(
                        name: name,
                        type: .video,
                        url: url,
                        duration: AVAsset(url: url).duration.seconds,
                        thumbnail: "video_thumbnail",
                        width: dimensions?.width,
                        height: dimensions?.height
                    )
                    project.addMediaAsset(asset)
                    self.appState.selectedProject = project
                    // Mark as changed and optionally show media browser
                    self.markDocumentAsChanged(actionName: "Import Screen Recording")
                    
                    // Show success notification
                    withAnimation {
                        self.notificationMessage = "Screen recording saved and added to Media Browser"
                        self.isNotificationError = false
                        self.showSuccessNotification = true
                    }
                }
            }

            // Listen for global delete notifications and perform deletion when applicable
            NotificationCenter.default.addObserver(forName: NSNotification.Name("DeleteSelectedCanvasElement"), object: nil, queue: .main) { _ in
                if let elementId = self.selectedElementId {
                    self.deleteElementAndCleanupTracks(elementId: elementId, actionName: "Delete Element")
                }
            }
            
            appState.registerUndoRedoActions(
                undo: performUndo,
                redo: performRedo,
                canUndoPublisher: undoRedoManager.$canUndo.eraseToAnyPublisher(),
                canRedoPublisher: undoRedoManager.$canRedo.eraseToAnyPublisher(),
                hasUnsavedChangesPublisher: documentManager.$hasUnsavedChanges.eraseToAnyPublisher(),
                currentProjectURLPublisher: documentManager.$projectURL.eraseToAnyPublisher()
            )
        }
        
        // Load project data every time we appear (this was the fix for the bug)
        loadCurrentProject()
    }
    
    internal func loadCurrentProject() {
        if let selectedProject = appState.selectedProject {
            print("🎯 Loading project from selection: \(selectedProject.name)")
            loadProjectFromSelection(selectedProject)
        } else {
            print("🆕 No selected project, setting up new project with default elements")
            canvasElements = createDefaultCanvasElements()
            
            animationController.setup(duration: 3.0)
            setupInitialAnimations()
            
            audioLayerManager.setAnimationController(animationController)
            
            audioLayerManager.onAudioLayerChanged = { actionName in
                Task { @MainActor in
                    self.markDocumentAsChanged(actionName: actionName)
                }
            }
            
            configureDocumentManager()
            // Note: prepareNewProjectForAutoSave() removed here because there's no selectedProject
            // The project URL will be set when a project is actually selected or created
        }
    }
    
    internal func handleViewDisappear() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        keyMonitorController.teardownMonitor()
        appState.clearUndoRedoActions()
        
        if documentManager.hasUnsavedChanges && !isClosing {
            print("🔄 Auto-saving project on view disappear...")
            autoSaveProject()
        }
    }
}