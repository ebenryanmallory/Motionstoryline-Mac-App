//
//  Motion_StorylineApp.swift
//  Motion Storyline
//
//  Created by rpf on 2/25/25.
//

import SwiftUI
import Foundation
import Clerk

@main
struct Motion_StorylineApp: App {
    @StateObject private var appStateManager = AppStateManager.shared // Use the shared instance
    @StateObject private var documentManager = DocumentManager() // Add DocumentManager
    @StateObject private var authManager = AuthenticationManager() // Add Authentication Manager
    @StateObject private var preferencesViewModel = PreferencesViewModel() // Add Preferences Manager
    @State private var clerk = Clerk.shared
    @Environment(\.scenePhase) private var scenePhase // Get scenePhase from environment
    @State private var isCreatingNewProject = false
    @AppStorage("recentProjects") private var recentProjectsData: Data = Data()
    @AppStorage("userProjects") private var userProjectsData: Data = Data()
    @State private var recentProjects: [Project] = []
    @State private var userProjects: [Project] = []
    @State private var statusMessage = "No recent projects"
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ZStack {
                    if authManager.isLoading {
                        // Show loading view while authentication is initializing
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading...")
                                .font(.headline)
                            
                            if !authManager.isAuthenticationAvailable {
                                VStack(spacing: 12) {
                                    Text("Authentication service is taking longer than expected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Continue Without Signing In") {
                                        authManager.continueWithoutAuthentication()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.top, 20)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor))
                    } else if self.appStateManager.selectedProject != nil {
                        DesignCanvas()
                            .withUITestIdentifier()
                            .navigationBarBackButtonHidden(true)
                            .environmentObject(self.appStateManager)
                            .environmentObject(self.documentManager) // Add DocumentManager to environment
                            .environmentObject(self.authManager) // Add AuthManager to environment
                            .environmentObject(self.preferencesViewModel) // Add PreferencesViewModel to environment
                            .onAppear {
                                // We can set up any necessary state here if needed
                            }
                            .onChange(of: self.appStateManager.selectedProject) { oldValue, newValue in
                                if let updatedProject = newValue {
                                    updateProject(updatedProject)
                                }
                            }
                    } else {
                        // Show home view (works in both authenticated and offline modes)
                        HomeView(
                            recentProjects: $recentProjects,
                            userProjects: $userProjects,
                            statusMessage: $statusMessage,
                            onProjectSelected: { project in
                                self.appStateManager.selectedProject = project
                                addToRecentProjects(project)
                            },
                            isCreatingNewProject: $isCreatingNewProject,
                            onCreateNewProject: { name, type in
                                createNewProject(name: name, type: type)
                            },
                            onDeleteProject: { project in
                                deleteProject(project)
                            },
                            onRenameProject: { project, newName in
                                renameProject(project, newName: newName)
                            },
                            onToggleProjectStar: { project in
                                toggleProjectStar(project)
                            }
                        )
                        .environmentObject(self.appStateManager)
                        .environmentObject(self.authManager)
                        .environmentObject(self.documentManager)
                        .environmentObject(self.preferencesViewModel)
                        .onAppear {
                            loadProjects()
                            updateStatusMessage()
                        }
                    }
                }
            }
            .environmentObject(authManager)
            .task {
                // Only configure Clerk if authentication is properly set up
                if ClerkConfig.isAuthenticationConfigured {
                    do {
                        // Configure Clerk with your publishable key
                        clerk.configure(publishableKey: ClerkConfig.currentPublishableKey)
                        try await clerk.load()
                    } catch {
                        print("Failed to load Clerk: \(error.localizedDescription)")
                        // The AuthenticationManager will handle this gracefully
                    }
                } else {
                    print("Clerk not configured - running in offline mode")
                }
            }
            .onAppear {
                // Configure window to prevent automatic snapping during resize
                if let window = NSApplication.shared.windows.first {
                    // Disable automatic collection behavior that might cause snapping
                    window.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
                    
                    // Enable resizing and ensure it doesn't snap to screen edges
                    window.styleMask.insert(.resizable)
                    
                    // Disable full screen transitions which can cause snapping
                    window.animationBehavior = .documentWindow
                    
                    // Set a reasonable minimum size for the window with extra height for timeline
                    window.minSize = NSSize(width: 1000, height: 750)
                }
                
                // Initialize appearance based on saved preference
                self.appStateManager.updateAppAppearance()
            }
            .overlay {
                // Documentation overlay
                if let docType = self.appStateManager.activeDocumentationType, self.appStateManager.isDocumentationVisible {
                    let content = DocumentationService.shared.getDocumentation(type: docType)
                    InfoOverlayView(
                        isVisible: Binding<Bool>(
                            get: { self.appStateManager.isDocumentationVisible }, 
                            set: { if !$0 { self.appStateManager.hideDocumentation() } }
                        ),
                        title: docType.title,
                        content: content
                    )
                } // Closes 'if let docType...'
            } // Closes '.overlay'
        } // Closes 'WindowGroup' content block
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                saveProjects()
            }
            print("Scene phase changed from \(oldPhase) to: \(newPhase)")
            self.appStateManager.scenePhase = newPhase
        }
            .windowToolbarStyle(.unified)
            .commands {
            CommandMenu("File") {
                Button("Open Project…") {
                    self.appStateManager.openProjectAction?()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()
                Button("Save") {
                    self.appStateManager.saveAction?()
                }
                .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") {
                    self.appStateManager.saveAsAction?()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Edit") {
                Button("Undo") {
                    self.appStateManager.undoAction?()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!self.appStateManager.canUndo)

                Button("Redo") {
                    self.appStateManager.redoAction?()
                }
                .keyboardShortcut("z", modifiers: [.shift, .command])
                .disabled(!self.appStateManager.canRedo)
                
                // Standard edit items (can be implemented later)
                Divider()
                Button("Cut") { self.appStateManager.cutAction?() }
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy") { self.appStateManager.copyAction?() }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste") { self.appStateManager.pasteAction?() }
                    .keyboardShortcut("v", modifiers: .command)
                Button("Delete") {
                    self.appStateManager.deleteAction?()
                }
                    .keyboardShortcut(.delete, modifiers: []) // Backspace/Delete key
                Button("Select All") { self.appStateManager.selectAllAction?() }
                    .keyboardShortcut("a", modifiers: .command)
            }

            CommandGroup(replacing: .newItem) {
                Menu("New File") {
                    Button("New Design") {
                        createNewProject(name: "Untitled", type: "Design")
                    }
                    Button("New Prototype") {
                        createNewProject(name: "Untitled", type: "Prototype")
                    }
                    Button("New Component Library") {
                        createNewProject(name: "Untitled", type: "Component Library")
                    }
                    Button("New Style Guide") {
                        createNewProject(name: "Untitled", type: "Style Guide")
                    }
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
            
            CommandMenu("Debug") {
                Button("Run Permission Diagnostic") {
                    PermissionDebugger.performFullDiagnostic()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Button("Test Basic Permissions") {
                    CaptureTestUtility.testBasicPermissions()
                }
                
                Button("Run End-to-End Capture Test") {
                    CaptureTestUtility.performEndToEndTest()
                }
                
                Divider()
                
                Button("Test Screen Recording") {
                    let recorder = ScreenCaptureKitRecorder()
                    recorder.requestPermissionsIfNeeded { granted in
                        print("🧪 [TEST] Permission result: \(granted)")
                    }
                }
            }
            
            CommandGroup(replacing: .help) {
                Button("Help Center") {
                    if let url = URL(string: "https://help.designstudio.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Divider()
                
                Button("Keyboard Shortcuts") {
                    self.appStateManager.showDocumentation(.keyboardShortcuts)
                }
                .keyboardShortcut("/", modifiers: [.command])
                
                Button("VoiceOver Compatibility") {
                    self.appStateManager.showDocumentation(.voiceOverCompatibility)
                }
                
                Button("VoiceOver Testing Checklist") {
                    self.appStateManager.showDocumentation(.voiceOverTestingChecklist)
                }
            }
        }
    }
    
    // Create a new project and set it as the selected project
    private func createNewProject(name: String, type: String) {
        let thumbnail = getThumbnailForType(type)
        let newProject = Project(name: name, thumbnail: thumbnail, lastModified: Date(), isStarred: false)
        createNewProject(newProject)
    }
    
    // Create a project from an existing Project object
    private func createNewProject(_ project: Project) {
        self.appStateManager.selectedProject = project
        addToRecentProjects(project)
        addToAllProjects(project)
        saveRecentProjects()
        saveAllProjects()
        updateStatus()
    }
    
    // Update an existing project
    private func updateProject(_ updatedProject: Project) {
        // Update in recent projects
        if let index = recentProjects.firstIndex(where: { $0.id == updatedProject.id }) {
            recentProjects[index] = updatedProject
            saveRecentProjects()
        }
        
        // Update in all projects
        if let index = userProjects.firstIndex(where: { $0.id == updatedProject.id }) {
            userProjects[index] = updatedProject
            saveAllProjects()
        }
        
        // Update selected project if it's the same one
        if self.appStateManager.selectedProject?.id == updatedProject.id {
            self.appStateManager.selectedProject = updatedProject
        }
    }
    
    // Add a project to recent projects (avoiding duplicates)
    private func addToRecentProjects(_ project: Project) {
        // Remove the project if it already exists to avoid duplicates
        recentProjects.removeAll { $0.id == project.id }
        
        // Add the project to the beginning of the array
        recentProjects.insert(project, at: 0)
        
        // Limit to 10 recent projects
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        
        saveRecentProjects()
    }
    
    // Add a project to all projects (avoiding duplicates)
    private func addToAllProjects(_ project: Project) {
        // Check if the project already exists
        if !userProjects.contains(where: { $0.id == project.id }) {
            userProjects.append(project)
            saveAllProjects()
        }
    }
    
    // Save recent projects to AppStorage
    private func saveRecentProjects() {
        do {
            let encoder = JSONEncoder()
            recentProjectsData = try encoder.encode(recentProjects)
        } catch {
            print("Failed to save recent projects: \(error.localizedDescription)")
        }
    }
    
    // Save all projects to AppStorage
    private func saveAllProjects() {
        do {
            let encoder = JSONEncoder()
            userProjectsData = try encoder.encode(userProjects)
        } catch {
            print("Failed to save all projects: \(error.localizedDescription)")
        }
    }
    
    // Load recent projects from AppStorage
    private func loadRecentProjects() {
        do {
            let decoder = JSONDecoder()
            recentProjects = try decoder.decode([Project].self, from: recentProjectsData)
            print("✅ Successfully loaded \(recentProjects.count) recent projects")
        } catch {
            print("❌ Failed to load recent projects: \(error.localizedDescription)")
            print("📝 Raw data size: \(recentProjectsData.count) bytes")
            recentProjects = []
        }
    }
    
    // Load all projects from AppStorage
    private func loadAllProjects() {
        do {
            let decoder = JSONDecoder()
            userProjects = try decoder.decode([Project].self, from: userProjectsData)
            print("✅ Successfully loaded \(userProjects.count) user projects")
        } catch {
            print("❌ Failed to load all projects: \(error.localizedDescription)")
            print("📝 Raw data size: \(userProjectsData.count) bytes")
            userProjects = []
        }
    }
    
    // Update status message based on project count
    private func updateStatus() {
        if recentProjects.isEmpty && userProjects.isEmpty {
            statusMessage = "No projects found. Create your first project to get started."
        } else if recentProjects.isEmpty {
            statusMessage = "No recent projects"
        } else {
            statusMessage = "\(recentProjects.count) recent project\(recentProjects.count == 1 ? "" : "s")"
        }
    }
    
    // Delete a project
    private func deleteProject(_ project: Project) {
        // Remove from recent projects
        recentProjects.removeAll { $0.id == project.id }
        
        // Remove from all projects
        userProjects.removeAll { $0.id == project.id }
        
        // Save changes
        saveRecentProjects()
        saveAllProjects()
        updateStatus()
        
        // If this was the selected project, clear the selection
        if self.appStateManager.selectedProject?.id == project.id {
            self.appStateManager.selectedProject = nil
        }
    }
    
    // Rename a project
    private func renameProject(_ project: Project, newName: String) {
        let updatedProject = Project(
            id: project.id,
            name: newName,
            thumbnail: project.thumbnail,
            lastModified: Date(),
            isStarred: project.isStarred
        )
        
        updateProject(updatedProject)
    }
    
    // Toggle project star status
    private func toggleProjectStar(_ project: Project) {
        let updatedProject = Project(
            id: project.id,
            name: project.name,
            thumbnail: project.thumbnail,
            lastModified: project.lastModified,
            isStarred: !project.isStarred
        )
        
        updateProject(updatedProject)
    }
    
    // Get thumbnail for project type
    private func getThumbnailForType(_ type: String) -> String {
        switch type {
        case "Design":
            return "rectangle.on.rectangle"
        case "Prototype":
            return "play.rectangle"
        case "Component Library":
            return "square.grid.3x3"
        case "Style Guide":
            return "paintbrush"
        default:
            return "doc"
        }
    }
    
    // Load projects and update status message
    private func loadProjects() {
        loadRecentProjects()
        loadAllProjects()
        
        // If no projects exist, create some sample projects for testing
        if recentProjects.isEmpty && userProjects.isEmpty {
            print("🔧 No projects found. Creating sample projects for testing...")
            createSampleProjects()
        }
        
        updateStatus()
        
        // Debug logging
        print("📊 Loaded \(recentProjects.count) recent projects")
        print("📊 Loaded \(userProjects.count) user projects")
        print("📊 Status message: \(statusMessage)")
    }
    
    // Create sample projects for testing
    private func createSampleProjects() {
        let sampleProjects = [
            Project(name: "Sample Design Project", thumbnail: "design_thumbnail", lastModified: Date().addingTimeInterval(-3600), isStarred: true),
            Project(name: "Mobile App Prototype", thumbnail: "prototype_thumbnail", lastModified: Date().addingTimeInterval(-7200), isStarred: false),
            Project(name: "Component Library", thumbnail: "component_thumbnail", lastModified: Date().addingTimeInterval(-86400), isStarred: false)
        ]
        
        for project in sampleProjects {
            userProjects.append(project)
            recentProjects.append(project)
        }
        
        // Limit recent projects to 10
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }
        
        // Save the sample projects
        saveProjects()
        print("✅ Created \(sampleProjects.count) sample projects")
    }
    
    // Update status message
    private func updateStatusMessage() {
        updateStatus()
    }
    
    // Save projects
    private func saveProjects() {
        saveRecentProjects()
        saveAllProjects()
    }
} 