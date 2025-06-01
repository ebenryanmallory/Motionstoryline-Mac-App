import SwiftUI

// Import the PreferencesController
import Foundation
import AVFoundation

struct CanvasTopBar: View {
    let projectName: String
    let onClose: () -> Void
    let onCameraRecord: () -> Void
    let onMediaLibrary: () -> Void
    
    // Add bindings and callbacks for the functionality
    @Binding var showAnimationPreview: Bool
    let onExport: (ExportFormat) -> Void
    let onAccountSettings: () -> Void
    let onHelpAndSupport: () -> Void
    let onCheckForUpdates: () -> Void
    let onSignOut: () -> Void
    
    // Add save callbacks
    let onSave: () -> Void
    let onSaveAs: () -> Void
    let onOpenProject: () -> Void
    
    // Zoom callbacks
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    
    // Document manager for saving/exporting
    let documentManager: DocumentManager
    // Live canvas state for export
    let liveCanvasElements: () -> [CanvasElement]
    let liveAnimationController: () -> AnimationController
    
    @State private var isShowingMenu = false
    // Add a state for showing the export modal
    @State private var showingExportModal = false
    // Add canvas dimensions for the export modal
    let canvasWidth: Int
    let canvasHeight: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onClose) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Back to Home")
            .accessibilityLabel("Back to Home")
            
            // Design Studio logo (placeholder)
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
            
            // File menu
            Menu {
                Button("Open Project...", action: onOpenProject)
                Divider()
                Button("Save Project", action: onSave)
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save Project As...", action: onSaveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Button("Export...", action: { 
                    // Synchronize DocumentManager with live UI state before exporting
                    self.documentManager.configure(
                        canvasElements: self.liveCanvasElements(),
                        animationController: self.liveAnimationController(),
                        canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                    )

                    showingExportModal = true
                })
            } label: {
                Text("File")
                    .foregroundColor(.black)
                    .frame(width: 60, alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            
            // Edit menu
            Menu {
                Button("Undo", action: {})
                Button("Redo", action: {})
                Divider()
                Button("Cut", action: {})
                Button("Copy", action: {})
                Button("Paste", action: {})
            } label: {
                Text("Edit")
                    .foregroundColor(.black)
                    .frame(width: 60, alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            
            // View menu
            Menu {
                Button("Zoom In", action: onZoomIn)
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out", action: onZoomOut)
                    .keyboardShortcut("-", modifiers: .command)
                Button("Zoom to 100%", action: onZoomReset)
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Show Grid", action: {})
                Button("Show Rulers", action: {})
            } label: {
                Text("View")
                    .foregroundColor(.black)
                    .frame(width: 60, alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            
            // Help menu
            Menu {
                Button("Keyboard Shortcuts") {
                    AppStateManager.shared.showDocumentation(.keyboardShortcuts)
                }
                .keyboardShortcut("/", modifiers: .command)
                
                Button("VoiceOver Compatibility") {
                    AppStateManager.shared.showDocumentation(.voiceOverCompatibility)
                }
                
                Button("VoiceOver Testing Checklist") {
                    AppStateManager.shared.showDocumentation(.voiceOverTestingChecklist)
                }
                
                Divider()
                
                Button("Help Center", action: onHelpAndSupport)
            } label: {
                Text("Help")
                    .foregroundColor(.black)
                    .frame(width: 60, alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()
            
            Divider()
                .frame(height: 20)
            
            // Project name
            Text(projectName)
                .fontWeight(.medium)
            
            Spacer()
            
            // Right side items
            HStack(spacing: 16) {
                // Documentation buttons
                HStack(spacing: 4) {
                    DocumentationButton(
                        documentationType: .keyboardShortcuts,
                        compact: true
                    )
                    
                    DocumentationButton(
                        documentationType: .voiceOverCompatibility,
                        compact: true
                    )
                }
                
                // Media Library Button
                Button(action: onMediaLibrary) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Media")
                    }
                    .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                .help("Open Media Library")
                
                Button(action: onCameraRecord) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.black)
                }
                
                // Updated Export menu
                Menu {
                    Button("Export...") {
                        // Tell parent to show the export modal with all options
                        onExport(.batchExport)
                    }
                    
                    Divider()
                    
                    Menu("Quick Export as Video") {
                        Button("Standard MP4") {
                            onExport(.video)
                        }
                        
                        Divider()
                        
                        Text("ProRes Options:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("ProRes 422 Proxy") {
                            onExport(.video)
                        }
                        
                        Button("ProRes 422 LT") {
                            onExport(.video)
                        }
                        
                        Button("ProRes 422") {
                            onExport(.video)
                        }
                        
                        Button("ProRes 422 HQ") {
                            onExport(.video)
                        }
                        
                        Button("ProRes 4444") {
                            onExport(.video)
                        }
                        
                        Button("ProRes 4444 XQ") {
                            onExport(.video)
                        }
                    }
                    
                    Button("Quick Export as GIF") {
                        onExport(.gif)
                    }
                    
                    Menu("Export as Image Sequence") {
                        Button("PNG Sequence") {
                            onExport(.imageSequence(.png))
                        }
                        
                        Button("JPEG Sequence") {
                            onExport(.imageSequence(.jpeg))
                        }
                    }
                    
                    Divider()
                    
                    Menu("Export Project File") {
                        Button {
                            // Use the same onSaveAs callback that the File menu uses
                            onSaveAs()
                        } label: {
                            Label("Motion Storyline Project (.storyline)", systemImage: "doc.badge.arrow.down")
                        }
                        .help("Export as a Motion Storyline native project file that can be reopened later")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.black)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()
                .help("Export Project")
                
                Menu {
                    Button("Account Settings") {
                        onAccountSettings()
                    }
                    
                    Button("Preferences") {
                        self.showPreferences()
                    }
                    
                    Divider()
                    
                    Button("Help & Support") {
                        onHelpAndSupport()
                    }
                    
                    Button("Check for Updates") {
                        onCheckForUpdates()
                    }
                    
                    Divider()
                    
                    Button("Sign Out") {
                        onSignOut()
                    }
                } label: {
                    Image(systemName: "person.circle")
                        .foregroundColor(.black)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .fixedSize()
                .help("User Menu")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 0.5)
    }
    
    // Method to show preferences window
    func showPreferences() {
        // Post notification that preferences should be shown
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowPreferences"),
            object: nil
        )
    }
} 