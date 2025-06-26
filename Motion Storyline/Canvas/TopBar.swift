import SwiftUI

// Import the PreferencesController
import Foundation
import AVFoundation
import Combine

struct CanvasTopBar: View {
    @State private var isShowingPreferences = false
    @State private var isShowingAuthenticationView = false
    @State private var isShowingUserProfileView = false
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
    let onShowAuthentication: () -> Void
    
    // Add clipboard operation callbacks
    let onCut: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    
    // Add undo/redo callbacks
    let onUndo: () -> Void
    let onRedo: () -> Void
    
    // Add grid and ruler visibility bindings
    @Binding var showGrid: Bool
    @Binding var showRulers: Bool
    @Binding var isInspectorVisible: Bool
    
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
    // Add a state for the initial export format
    @State private var exportModalInitialFormat: ExportFormat = .video
    
    // Undo/Redo manager
    @EnvironmentObject var undoManager: UndoRedoManager
    // Authentication manager
    @EnvironmentObject var authManager: AuthenticationManager
    // Add canvas dimensions for the export modal
    let canvasWidth: Int
    let canvasHeight: Int
    
    // Computed property for user display name
    private var userDisplayName: String {
        // Handle case where authentication is unavailable
        guard authManager.isAuthenticationAvailable else {
            return "User"
        }
        
        let firstName = authManager.user?.firstName ?? ""
        let lastName = authManager.user?.lastName ?? ""
        
        if !firstName.isEmpty && !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else if !firstName.isEmpty {
            return firstName
        } else if !lastName.isEmpty {
            return lastName
        } else {
            return "User"
        }
    }
    
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
            
            // Design Studio logo
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            // File menu
            Menu {
                Button("Open Project...", action: onOpenProject)
                Divider()
                Button("Save", action: onSave)
                    .keyboardShortcut("s", modifiers: .command)
                Button("Export Project...", action: onSaveAs)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
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
                    onUndo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!undoManager.canUndo)
                
                Button("Redo") {
                    onRedo()
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
                Divider()
                Toggle("Show Inspector", isOn: $isInspectorVisible)
                    .keyboardShortcut("i", modifiers: .command)
                Toggle("Show Animation Timeline", isOn: $showAnimationPreview)
                    .keyboardShortcut("t", modifiers: .command)
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
                        // Synchronize DocumentManager with live UI state before exporting
                        self.documentManager.configure(
                            canvasElements: self.liveCanvasElements(),
                            animationController: self.liveAnimationController(),
                            canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                        )
                        exportModalInitialFormat = .video
                        showingExportModal = true
                    }
                    
                    Divider()
                    
                    Menu("Quick Export as Video") {
                        Button("Standard MP4") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
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
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422 LT") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                        
                        Button("ProRes 422 HQ") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                        
                        Button("ProRes 4444") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                        
                        Button("ProRes 4444 XQ") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .video
                            showingExportModal = true
                        }
                    }
                    
                    Button("Quick Export as GIF") {
                        // Synchronize DocumentManager with live UI state before exporting
                        self.documentManager.configure(
                            canvasElements: self.liveCanvasElements(),
                            animationController: self.liveAnimationController(),
                            canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                        )
                        exportModalInitialFormat = .gif
                        showingExportModal = true
                    }
                    
                    Menu("Export as Image Sequence") {
                        Button("PNG Sequence") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .imageSequence(.png)
                            showingExportModal = true
                        }
                        
                        Button("JPEG Sequence") {
                            // Synchronize DocumentManager with live UI state before exporting
                            self.documentManager.configure(
                                canvasElements: self.liveCanvasElements(),
                                animationController: self.liveAnimationController(),
                                canvasSize: CGSize(width: CGFloat(self.canvasWidth), height: CGFloat(self.canvasHeight)), currentProject: nil
                            )
                            exportModalInitialFormat = .imageSequence(.jpeg)
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
                    if !authManager.isAuthenticationAvailable || authManager.isOfflineMode {
                        // Offline mode menu
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Offline Mode")
                                .font(.headline)
                            Text("Authentication unavailable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        Button("Sign In") {
                            if authManager.isAuthenticationAvailable {
                                isShowingAuthenticationView = true
                            } else {
                                Task {
                                    await authManager.retryAuthentication()
                                }
                            }
                        }
                        .disabled(authManager.isLoading)
                        
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
                    } else if authManager.isAuthenticated {
                        // Authenticated user menu
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userDisplayName)
                                .font(.headline)
                            Text(authManager.user?.primaryEmailAddress?.emailAddress ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        Button("Account Settings") {
                            isShowingUserProfileView = true
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
                            Task {
                                await authManager.signOut()
                            }
                        }
                    } else {
                        // Not authenticated but auth is available
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not Signed In")
                                .font(.headline)
                            Text("Sign in to sync your projects")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        Divider()
                        
                        Button("Sign In") {
                            isShowingAuthenticationView = true
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
                    }
                } label: {
                    Group {
                        if authManager.isAuthenticationAvailable && authManager.isAuthenticated,
                           let imageUrl = authManager.user?.imageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.black)
                            }
                        } else {
                            Image(systemName: "person.circle")
                                .foregroundColor(.black)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
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
        .sheet(isPresented: $isShowingAuthenticationView) {
            AuthenticationView()
                .environmentObject(authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingUserProfileView) {
            UserProfileView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingExportModal) {
            ExportModal(
                asset: AVAsset(url: URL(fileURLWithPath: "")), // Empty asset as placeholder
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                initialFormat: exportModalInitialFormat,
                getAnimationController: liveAnimationController,
                getCanvasElements: liveCanvasElements,
                onDismiss: { 
                    showingExportModal = false
                    exportModalInitialFormat = .video // Reset to default for next time
                }
            )
        }
    }
} 