import SwiftUI
import Foundation

// MARK: - Element Deletion Extension
extension DesignCanvas {
    
    // MARK: - Element Deletion
    
    /// Centralized function to delete an element and clean up all associated animation tracks
    /// This function should be called from all element deletion entry points
    /// - Parameters:
    ///   - elementId: The ID of the element to delete
    ///   - actionName: The name of the action for undo/redo tracking
    internal func deleteElementAndCleanupTracks(elementId: UUID, actionName: String) {
        // Record state before deletion for undo/redo
        recordStateBeforeChange(actionName: actionName)
        
        // Remove element from canvas
        canvasElements.removeAll { $0.id == elementId }
        
        // Clean up all animation tracks associated with this element
        cleanupAnimationTracksForElement(elementId: elementId)
        
        // Clear selection if this element was selected
        if selectedElementId == elementId {
            selectedElementId = nil
        }
        
        // Mark document as changed
        markDocumentAsChanged(actionName: actionName)
        
        print("🗑️ Element deleted and \(actionName) completed. Animation tracks cleaned up for element: \(elementId)")
    }
    
    /// Removes all animation tracks associated with a specific element
    /// - Parameter elementId: The ID of the element whose tracks should be removed
    private func cleanupAnimationTracksForElement(elementId: UUID) {
        // Use the AnimationController's built-in cleanup method
        animationController.removeTracksForElement(elementId: elementId)
    }
}