import SwiftUI
import Combine
import AppKit
import UserNotifications
import Foundation

// MARK: - Project Save/Export Extensions for DesignCanvas
extension DesignCanvas {
    // MARK: - Project Save Methods
    
    /// Save the project with Save As dialog
    internal func saveAsProjectInternal() async {
        // Configure the save panel
        let savePanel = NSSavePanel()
        savePanel.title = "Save Project"
        savePanel.nameFieldStringValue = "Untitled Project.mstory"
        savePanel.allowedContentTypes = [.init(filenameExtension: "mstory")!]
        savePanel.canCreateDirectories = true
        
        // Show the save panel
        if savePanel.runModal() == .OK, let url = savePanel.url {
            // Update document manager with current state
            documentManager.configure(
                canvasElements: self.canvasElements,
                animationController: self.animationController,
                canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight)
            )
            
            // Save to the selected URL
            documentManager.currentProjectURL = url
            let success = documentManager.saveProject()
            
            // Update project name in app state
            if success {
                appState.currentProjectName = url.lastPathComponent
                showSaveSuccessNotification()
            }
        }
    }
    
    /// Helper to show success notification
    internal func showSaveSuccessNotification() {
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