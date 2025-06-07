import Foundation
import SwiftUI // For CGSize, or define a CodableCGSize if not available directly

// Represents the state of the project to be saved for undo/redo
struct ProjectState: Codable {
    let canvasElements: [CanvasElement]
    let animationControllerState: Data // Assuming AnimationController can serialize its state to Data
    let canvasSize: CGSize
    // Add other properties that define the project's state if necessary
    
    // CGSize Codable conformance if not already provided by SwiftUI in this context
    // If using an older SwiftUI or if CGSize isn't directly Codable in your target,
    // you might need a wrapper or manual encoding/decoding.
    // For simplicity, assuming CGSize is Codable or you have a Codable wrapper.
}

class UndoRedoManager: ObservableObject {
    @Published private(set) var undoStack: [Data] = []
    @Published private(set) var redoStack: [Data] = []
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    
    private let maxHistoryCount = 5

    func addUndoState(stateBeforeOperation: Data) {
        if undoStack.count >= maxHistoryCount {
            undoStack.removeFirst()
        }
        undoStack.append(stateBeforeOperation)
        redoStack.removeAll() // Any new action clears the redo stack
        
        self.canUndo = !undoStack.isEmpty
        self.canRedo = !redoStack.isEmpty
        // Notify observers that canUndo/canRedo might have changed
        objectWillChange.send()
    }

    func undo(currentStateForRedo: Data) -> Data? {
        guard let stateToRestore = undoStack.popLast() else {
            return nil
        }
        redoStack.append(currentStateForRedo)
        
        self.canUndo = !undoStack.isEmpty
        self.canRedo = !redoStack.isEmpty
        // Notify observers
        objectWillChange.send()
        return stateToRestore
    }

    func redo(currentStateForUndo: Data) -> Data? {
        guard let stateToRestore = redoStack.popLast() else {
            return nil
        }
        undoStack.append(currentStateForUndo)
        
        self.canUndo = !undoStack.isEmpty
        self.canRedo = !redoStack.isEmpty
        // Notify observers
        objectWillChange.send()
        return stateToRestore
    }
    
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        self.canUndo = false
        self.canRedo = false
        objectWillChange.send()
    }
}

// Note: Ensure CanvasElement is Codable.
// Ensure AnimationController can provide its state as Data and restore from Data.
// e.g., AnimationController might have:
// func serializeState() -> Data?
// func restoreState(from data: Data)
