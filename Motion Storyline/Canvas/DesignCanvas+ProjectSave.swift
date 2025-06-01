import SwiftUI
import Combine
import AppKit
import UserNotifications
import Foundation

// MARK: - Project Save/Export Extensions for DesignCanvas
extension DesignCanvas {
    // MARK: - Project Save Methods
    
    /// Non-async wrapper for save project
    func saveProject() {
        Task {
            await saveProjectAsync()
        }
    }
    
    /// Save the current project state 
    @MainActor
    func saveProjectAsync() async {
        print("Saving project with \(self.canvasElements.count) canvas elements")
        
        // Create a document manager
        let documentManager = DocumentManager()
        
        // Configure it with the current canvas state
        documentManager.configure(
            canvasElements: self.canvasElements,
            animationController: self.animationController,
            canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight)
        )
        
        // Save the project
        if documentManager.saveCurrentState() {
            showSaveSuccessNotification()
        } else {
            print("Failed to save project")
        }
    }
    
    /// Non-async wrapper for save as project
    func saveAsProject() {
        Task {
            await saveAsProjectAsync()
        }
    }
    
    /// Save the current project with a new filename
    @MainActor
    func saveAsProjectAsync() async {
        print("Save As project with \(self.canvasElements.count) canvas elements")
        
        // Create a document manager
        let documentManager = DocumentManager()
        
        // Configure it with the current canvas state
        documentManager.configure(
            canvasElements: self.canvasElements, 
            animationController: self.animationController,
            canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight)
        )
        
        // Save the project - this will prompt the user for location
        if documentManager.saveCurrentState() {
            showSaveSuccessNotification()
        } else {
            print("Failed to save project")
        }
    }
    
    /// Helper to show success notification
    private func showSaveSuccessNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Project Saved"
        content.body = "Your project has been saved successfully"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing save notification: \(error.localizedDescription)")
            }
        }
    }
} 