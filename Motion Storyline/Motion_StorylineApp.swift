//
//  Motion_StorylineApp.swift
//  Motion Storyline
//
//  Created by rpf on 2/25/25.
//

import SwiftUI

@main
struct Motion_StorylineApp: App {
    @StateObject private var appState = AppStateManager()
    @State private var isCreatingNewProject = false
    @AppStorage("recentProjects") private var recentProjectsData: Data = Data()
    @AppStorage("userProjects") private var userProjectsData: Data = Data()
    @State private var recentProjects: [Project] = []
    @State private var userProjects: [Project] = []
    @State private var statusMessage = "No recent projects"
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if appState.selectedProject != nil {
                    DesignCanvas()
                        .navigationBarBackButtonHidden(true)
                        .environmentObject(appState)
                        .onAppear {
                            // We can set up any necessary state here if needed
                        }
                } else {
                    HomeView(
                        recentProjects: $recentProjects,
                        userProjects: $userProjects,
                        statusMessage: $statusMessage,
                        onProjectSelected: { project in
                            appState.selectedProject = project
                            addToRecentProjects(project)
                        },
                        isCreatingNewProject: $isCreatingNewProject,
                        onCreateNewProject: { name, type in
                            createNewProject(name: name, type: type)
                        }
                    )
                    .environmentObject(appState)
                    .onAppear {
                        loadRecentProjects()
                        loadAllProjects()
                        updateStatus()
                    }
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
                    
                    // Set a reasonable minimum size for the window
                    window.minSize = NSSize(width: 800, height: 600)
                }
            }
        }
        .windowToolbarStyle(.unified)
        .commands {
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
            
            CommandGroup(replacing: .help) {
                Button("Help Center") {
                    if let url = URL(string: "https://help.designstudio.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Keyboard Shortcuts") {
                    // Show shortcuts
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
    
    // Create a new project and set it as the selected project
    private func createNewProject(name: String, type: String) {
        let thumbnail = getThumbnailForType(type)
        let newProject = Project(name: name, thumbnail: thumbnail, lastModified: Date())
        createNewProject(newProject)
    }
    
    // Create a project from an existing Project object
    private func createNewProject(_ project: Project) {
        appState.selectedProject = project
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
        if appState.selectedProject?.id == updatedProject.id {
            appState.selectedProject = updatedProject
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
        guard !recentProjectsData.isEmpty else {
            recentProjects = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            recentProjects = try decoder.decode([Project].self, from: recentProjectsData)
        } catch {
            print("Failed to load recent projects: \(error.localizedDescription)")
            recentProjects = []
        }
    }
    
    // Load all projects from AppStorage
    private func loadAllProjects() {
        guard !userProjectsData.isEmpty else {
            createSampleProjects()
            return
        }
        
        do {
            let decoder = JSONDecoder()
            userProjects = try decoder.decode([Project].self, from: userProjectsData)
        } catch {
            print("Failed to load all projects: \(error.localizedDescription)")
            createSampleProjects()
        }
    }
    
    // Create sample projects for first-time users
    private func createSampleProjects() {
        userProjects = [
            Project(name: "Mobile App Design", thumbnail: "design_thumbnail", lastModified: Date()),
            Project(name: "Website Prototype", thumbnail: "prototype_thumbnail", lastModified: Date()),
            Project(name: "Brand Style Guide", thumbnail: "style_thumbnail", lastModified: Date())
        ]
        saveAllProjects()
    }
    
    // Update status message based on projects
    private func updateStatus() {
        if userProjects.isEmpty {
            statusMessage = "No projects available"
        } else {
            statusMessage = "\(userProjects.count) projects available"
        }
    }
    
    // Helper function to get a thumbnail based on project type
    private func getThumbnailForType(_ type: String) -> String {
        switch type {
        case "Design":
            return "design_thumbnail"
        case "Prototype":
            return "prototype_thumbnail"
        case "Component Library":
            return "component_thumbnail"
        case "Style Guide":
            return "style_thumbnail"
        default:
            return "placeholder"
        }
    }
}
