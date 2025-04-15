import SwiftUI

// Import the PreferencesController
import Foundation

struct CanvasTopBar: View {
    let projectName: String
    let onClose: () -> Void
    let onNewFile: () -> Void
    let onCameraRecord: () -> Void
    let onMediaLibrary: () -> Void
    
    // Add bindings and callbacks for the functionality
    @Binding var showAnimationPreview: Bool
    let onExport: (ExportFormat) -> Void
    let onAccountSettings: () -> Void
    let onHelpAndSupport: () -> Void
    let onCheckForUpdates: () -> Void
    let onSignOut: () -> Void
    
    // Zoom callbacks
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onZoomReset: () -> Void
    
    @State private var isShowingMenu = false
    
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
                Button("New File", action: onNewFile)
                Button("Open...", action: {})
                Divider()
                Button("Save", action: {})
                Button("Save As...", action: {})
                Divider()
                Button("Export...", action: {})
            } label: {
                Text("File")
                    .foregroundColor(.black)
            }
            
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
            }
            
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
            }
            
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
            }
            
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
                
                Menu {
                    Menu("Export as Video") {
                        Button("Standard MP4") {
                            onExport(.video)
                        }
                        
                        Divider()
                        
                        Text("ProRes Options:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("ProRes 422 Proxy") {
                            // We'll handle the ProRes option in DesignCanvas
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
                    
                    Button("Export as GIF") {
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
                            onExport(.projectFile)
                        } label: {
                            Label("Motion Storyline Project (.msproj)", systemImage: "doc.badge.arrow.down")
                        }
                        .help("Export as a Motion Storyline native project file that can be reopened later")
                        
                        Divider()
                        
                        Text("Project file contains:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("All canvas elements", systemImage: "square.on.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Animation keyframes", systemImage: "timeline.selection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("Project settings", systemImage: "gearshape")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Button {
                        onExport(.batchExport)
                    } label: {
                        Label("Batch Export Multiple Formats", systemImage: "square.stack.3d.down.right")
                    }
                    .help("Export multiple formats simultaneously with background processing")
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.black)
                }
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
                .help("User Menu")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 0.5)
    }
} 