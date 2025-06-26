import Foundation
import SwiftUI

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

// Note: This UndoRedoManager works with ProjectData serialized as Data.
// State capture and restoration is handled through DocumentManager.getCurrentProjectStateData()
// and DocumentManager.decodeProjectState() to ensure consistency.
