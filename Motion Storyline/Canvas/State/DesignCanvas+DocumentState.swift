import SwiftUI
import Foundation

// MARK: - Document State Management Extension
extension DesignCanvas {
    
    // MARK: - State Recording
    
    internal func recordUndoState(actionName: String) {
        // CRITICAL: Restore projectURL if it was cleared by previous operations
        // This prevents save failures that cause changes not to persist between sessions
        if documentManager.projectURL == nil {
            if let originalURL = originalProjectURL {
                // Use the original URL from when the project was loaded
                documentManager.projectURL = originalURL
            } else if let selectedProject = appState.selectedProject {
                // Fallback: reconstruct URL from selectedProject (maintains original structure)
                documentManager.projectURL = constructProjectURL(for: selectedProject)
            }
        }
        
        // Preserve the projectURL around DocumentManager configuration
        let preservedProjectURL = documentManager.projectURL
        
        // Ensure DocumentManager has the latest state before capturing
        configureDocumentManager()
        
        // Restore the projectURL if it was cleared during configuration
        if documentManager.projectURL == nil && preservedProjectURL != nil {
            documentManager.projectURL = preservedProjectURL
        }
        
        // Use DocumentManager's method to get consistent state format
        guard let stateData = documentManager.getCurrentProjectStateData() else {
            print("Failed to capture current state for undo: \(actionName)")
            return
        }
        
        undoRedoManager.addUndoState(stateBeforeOperation: stateData)
        print("Recorded undo state for: \(actionName)")
    }
    
    // MARK: - Document State Management
    
    /// Records the current state before a change and marks the document as changed
    /// This should be called before any user action that modifies the canvas
    internal func recordStateBeforeChange(actionName: String) {
        // Skip if this is a programmatic change (e.g., during project loading)
        guard !isProgrammaticChange else { return }
        
        // Record the current state for undo/redo BEFORE the change
        recordUndoState(actionName: actionName)
        
        print("State recorded before change: \(actionName)")
    }
    
    /// Marks the document as changed after a modification
    /// This should be called after any user action that modifies the canvas
    internal func markDocumentAsChanged(actionName: String) {
        // Skip if this is a programmatic change (e.g., during project loading)
        guard !isProgrammaticChange else { 
            print("⏩ Skipping markDocumentAsChanged for programmatic change: \(actionName)")
            return 
        }
        
        // CRITICAL: Restore projectURL if it was cleared by previous operations
        // This prevents save failures that cause changes not to persist between sessions
        if documentManager.projectURL == nil {
            if let originalURL = originalProjectURL {
                // Use the original URL from when the project was loaded
                documentManager.projectURL = originalURL
            } else if let selectedProject = appState.selectedProject {
                // Fallback: reconstruct URL from selectedProject (maintains original structure)
                documentManager.projectURL = constructProjectURL(for: selectedProject)
            }
        }
        
        // Preserve the projectURL around DocumentManager configuration
        let preservedProjectURL = documentManager.projectURL
        
        // Update the document manager with the current state FIRST
        // This ensures the DocumentManager always has the latest data for auto-save
        configureDocumentManager()
        
        // Restore the projectURL if it was cleared during configuration
        if documentManager.projectURL == nil && preservedProjectURL != nil {
            documentManager.projectURL = preservedProjectURL
        }
        
        // Then mark the document as having unsaved changes
        documentManager.hasUnsavedChanges = true
        
        print("📝 Document marked as changed: \(actionName), hasUnsavedChanges = \(documentManager.hasUnsavedChanges)")
        print("📝 DocumentManager now has \(documentManager.currentElementCount) elements and \(documentManager.currentTrackCount) tracks")
        
        // Schedule debounced auto-save to ensure changes are saved after a brief delay
        scheduleAutoSave()
    }
    
    // MARK: - Undo/Redo Operations
    
    /// Performs undo operation by restoring the previous state
    internal func performUndo() {
        print("🔄 Starting undo operation...")
        
        // Ensure DocumentManager has the latest state before undo
        configureDocumentManager()
        
        // Get current state for potential redo
        guard let currentState = documentManager.getCurrentProjectStateData() else {
            print("❌ Cannot get current state for undo operation")
            return
        }
        
        // Perform undo and get the state to restore
        guard let stateToRestore = undoRedoManager.undo(currentStateForRedo: currentState) else {
            print("❌ No undo state available")
            return
        }
        
        // Decode and apply the restored state
        guard let projectData = documentManager.decodeProjectState(from: stateToRestore) else {
            print("❌ Failed to decode undo state")
            return
        }
        
        print("🔄 Restoring state with \(projectData.elements.count) elements and \(projectData.tracks.count) tracks")
        
        // Apply the restored state
        isProgrammaticChange = true
        applyProjectData(projectData: projectData)
        isProgrammaticChange = false
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("✅ Undo operation completed")
    }
    
    /// Performs redo operation by restoring the next state
    internal func performRedo() {
        print("🔄 Starting redo operation...")
        
        // Ensure DocumentManager has the latest state before redo
        configureDocumentManager()
        
        // Get current state for potential undo
        guard let currentState = documentManager.getCurrentProjectStateData() else {
            print("❌ Cannot get current state for redo operation")
            return
        }
        
        // Perform redo and get the state to restore
        guard let stateToRestore = undoRedoManager.redo(currentStateForUndo: currentState) else {
            print("❌ No redo state available")
            return
        }
        
        // Decode and apply the restored state
        guard let projectData = documentManager.decodeProjectState(from: stateToRestore) else {
            print("❌ Failed to decode redo state")
            return
        }
        
        print("🔄 Restoring state with \(projectData.elements.count) elements and \(projectData.tracks.count) tracks")
        
        // Apply the restored state
        isProgrammaticChange = true
        applyProjectData(projectData: projectData)
        isProgrammaticChange = false
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("✅ Redo operation completed")
    }
}