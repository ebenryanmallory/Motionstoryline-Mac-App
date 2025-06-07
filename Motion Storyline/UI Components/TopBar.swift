import SwiftUI

// Import the PreferencesController
import Foundation
import AVFoundation
import Combine

struct CanvasTopBar: View {
    @State private var isShowingPreferences = false
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
    
    // Add clipboard operation callbacks
    let onCut: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    
    // Add grid and ruler visibility bindings
    @Binding var showGrid: Bool
    @Binding var showRulers: Bool
    
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
    
    // Undo/Redo manager
    @EnvironmentObject var undoManager: UndoRedoManager
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
                Button("Undo") {
                    // Get current state for potential redo
                    if let currentState = documentManager.getCurrentProjectStateData() {
                        _ = undoManager.undo(currentStateForRedo: currentState)
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!undoManager.canUndo)
                
                Button("Redo") {
                    // Get current state for potential undo
                    if let currentState = documentManager.getCurrentProjectStateData() {
                        _ = undoManager.redo(currentStateForUndo: currentState)
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!undoManager.canRedo)
                
                Divider()
                Button("Cut", action: onCut)
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy", action: onCopy)
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste", action: onPaste)
                    .keyboardShortcut("v", modifiers: .command)
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
                Toggle("Show Grid", isOn: $showGrid)
                    .keyboardShortcut("g", modifiers: .command)
                Toggle("Show Rulers", isOn: $showRulers)
                    .keyboardShortcut("r", modifiers: .command)
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
                // Animation Preview Toggle
                Toggle(isOn: $showAnimationPreview) {
                    HStack(spacing: 4) {
                        Image(systemName: showAnimationPreview ? "play.fill" : "play")
                        Text("Preview")
                    }
                }
                .toggleStyle(ButtonToggleStyle())
                .help("Toggle Animation Preview")
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
                        // Synchronize DocumentManager with live UI state before exporting
                        self.documentManager.configure(
                            canvasElements: self.liveCanvasElements(),
                            animationController: self.liveAnimationController(),
                            canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                        )
                        showingExportModal = true
                    }
                    
                    Divider()
                    
                    Menu("Quick Export as Video") {
                        Button("Standard MP4") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Divider()
                        
                        Text("ProRes Options:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("ProRes 422 Proxy") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422 LT") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422 HQ") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("ProRes 4444") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("ProRes 4444 XQ") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                    }
                    
                    Button("Quick Export as GIF") {
                        // Synchronize DocumentManager with live UI state before exporting
                        self.documentManager.configure(
                            canvasElements: self.liveCanvasElements(),
                            animationController: self.liveAnimationController(),
                            canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                        )
                        showingExportModal = true
                    }
                    
                    Menu("Export as Image Sequence") {
                        Button("PNG Sequence") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
                        }
                        
                        Button("JPEG Sequence") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight))
                            )
                            showingExportModal = true
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
                        isShowingPreferences = true
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
        .sheet(isPresented: $isShowingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingExportModal) {
            ExportModal(
                asset: AVAsset(url: URL(fileURLWithPath: "")), // Empty asset as placeholder
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                getAnimationController: liveAnimationController,
                getCanvasElements: liveCanvasElements,
                onDismiss: { showingExportModal = false }
            )
        }
    }
} 