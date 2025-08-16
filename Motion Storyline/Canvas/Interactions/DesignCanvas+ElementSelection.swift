import SwiftUI
import Foundation

// MARK: - Element Selection Extension
extension DesignCanvas {
    
    // MARK: - Element Selection
    
    /// Handles element selection when an element is tapped
    internal func handleElementSelection(_ element: CanvasElement) {
        print("🎯 Element selected: \(element.displayName)")
        print("🎯 Timeline enabled: \(showAnimationPreview), Timeline height: \(timelineHeight)")
        
        // Update selected element state
        selectedElementId = element.id
        selectedElement = element
        
        // If the selected element is a text element, start editing
        if element.type == .text {
            isEditingText = true
            editingText = element.text
        } else {
            isEditingText = false
        }
        
        // Update inspector and animation data
        animationPropertyManager.updateAnimationPropertiesForSelectedElement(selectedElement, canvasElements: $canvasElements)
        
        // Force UI update by triggering objectWillChange
        isProgrammaticChange = true
        isProgrammaticChange = false
    }
}