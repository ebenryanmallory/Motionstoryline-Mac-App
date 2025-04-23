import SwiftUI
import AppKit

// Import the PreferencesController
import Foundation

struct HomeView: View {
    @Binding var recentProjects: [Project]
    @Binding var userProjects: [Project]
    @Binding var statusMessage: String
    let onProjectSelected: (Project) -> Void
    @Binding var isCreatingNewProject: Bool
    let onCreateNewProject: (String, String) -> Void
    @EnvironmentObject private var appState: AppStateManager
    
    // Add deleteProject function
    var onDeleteProject: ((Project) -> Void)?
    // Add renameProject function
    var onRenameProject: ((Project, String) -> Void)?
    // Add toggleProjectStar function
    var onToggleProjectStar: ((Project) -> Void)?
    
    @State private var selectedItem: String? = "Home"
    @State private var searchText: String = ""
    @State private var selectedTab: Int = 0
    @State private var isShowingUserMenu = false
    @State private var selectedTemplateType: String = ""
    
    // Dynamic colors for light/dark mode adaptability
    private var designBg: Color {
        Color(NSColor.windowBackgroundColor)
    }
    private var designHeaderBg: Color {
        Color(NSColor.controlBackgroundColor)
    }
    private var designBorder: Color {
        Color.primary.opacity(0.1)
    }
    private var cardBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    // Filtered projects based on search text
    private var filteredRecentProjects: [Project] {
        let filtered: [Project]
        if searchText.isEmpty {
            filtered = recentProjects
        } else {
            filtered = recentProjects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by star status (starred first) and then by last modified date
        return filtered.sorted { (a, b) -> Bool in
            if a.isStarred != b.isStarred {
                return a.isStarred && !b.isStarred
            }
            return a.lastModified > b.lastModified
        }
    }
    
    private var filteredUserProjects: [Project] {
        let filtered: [Project]
        if searchText.isEmpty {
            filtered = userProjects
        } else {
            filtered = userProjects.filter { project in
                project.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by star status (starred first) and then by name
        return filtered.sorted { (a, b) -> Bool in
            if a.isStarred != b.isStarred {
                return a.isStarred && !b.isStarred
            }
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
    }
    
    // Function to delete project
    private func deleteProject(_ project: Project) {
        // Remove from user projects
        userProjects.removeAll { $0.id == project.id }
        
        // Remove from recent projects if present
        recentProjects.removeAll { $0.id == project.id }
        
        // If this was the selected project, navigate back to home
        if appState.selectedProject?.id == project.id {
            appState.navigateToHome()
        }
        
        // Update status message
        updateStatusMessage()
        
        // Notify parent component for persistence
        if let onDelete = onDeleteProject {
            onDelete(project)
        }
    }
    
    // Function to toggle project star status
    private func toggleProjectStar(_ project: Project) {
        // Create a new project with the toggled star status
        var updatedProject = project
        updatedProject.isStarred.toggle()
        
        // Update in user projects
        if let index = userProjects.firstIndex(where: { $0.id == project.id }) {
            userProjects[index] = updatedProject
        }
        
        // Update in recent projects if present
        if let index = recentProjects.firstIndex(where: { $0.id == project.id }) {
            recentProjects[index] = updatedProject
        }
        
        // If this is the selected project, update it
        if appState.selectedProject?.id == project.id {
            appState.selectedProject = updatedProject
        }
        
        // Notify parent component for persistence
        if let onToggleStar = onToggleProjectStar {
            onToggleStar(updatedProject)
        }
    }
    
    // Update status message based on project count
    private func updateStatusMessage() {
        if userProjects.isEmpty {
            statusMessage = "No projects available"
        } else {
            statusMessage = "\(userProjects.count) project\(userProjects.count == 1 ? "" : "s") available"
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedItem: $selectedItem,
                searchText: $searchText,
                isCreatingNewProject: $isCreatingNewProject
            )
            .frame(minWidth: 220)
            .environmentObject(appState)
        } detail: {
            VStack(spacing: 0) {
                // Top header (Design Studio-style)
                HStack(spacing: 16) {
                    // Design Studio logo
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        Text("DesignStudio")
                            .fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("DesignStudio")
                    .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        TextField("Search files...", text: $searchText)
                            .frame(width: 200)
                            .accessibilityLabel("Search files")
                            .onChange(of: searchText) { oldValue, newValue in
                                // Update status message based on search results
                                if !newValue.isEmpty {
                                    let allCount = filteredUserProjects.count
                                    statusMessage = "Found \(allCount) project\(allCount == 1 ? "" : "s") matching '\(newValue)'"
                                } else {
                                    updateStatusMessage()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { 
                                searchText = ""
                                updateStatusMessage()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    
                    // Documentation buttons
                    HStack(spacing: 2) {
                        DocumentationButton(
                            documentationType: .keyboardShortcuts,
                            compact: true
                        )
                        
                        DocumentationButton(
                            documentationType: .voiceOverCompatibility,
                            compact: true
                        )
                    }
                    
                    // User menu
                    Button(action: { isShowingUserMenu.toggle() }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("User Menu")
                    .accessibilityHint("Access profile and settings")
                    .popover(isPresented: $isShowingUserMenu) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User Account")
                                .font(.headline)
                                .padding(.bottom, 4)
                                .accessibilityAddTraits(.isHeader)
                            
                            Button("Profile", action: {})
                                .accessibilityHint("View your profile")
                            Button("Settings", action: {
                                isShowingUserMenu = false
                                self.showPreferences()
                            })
                            .accessibilityHint("Open application settings")
                            Divider()
                            Button("Sign Out", action: {})
                                .accessibilityHint("Sign out of your account")
                        }
                        .padding()
                        .frame(width: 200)
                    }
                }
                .padding()
                .background(designHeaderBg)
                .border(designBorder, width: 0.5)
                
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(["Recent", "All Projects", "Templates"], id: \.self) { tab in
                        let index = ["Recent", "All Projects", "Templates"].firstIndex(of: tab) ?? 0
                        Button(action: { selectedTab = index }) {
                            Text(tab)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .foregroundColor(selectedTab == index ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .background(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(tab)
                        .accessibilityAddTraits(selectedTab == index ? [.isSelected, .isButton] : .isButton)
                        .accessibilityHint("Show \(tab.lowercased()) projects")
                    }
                    Spacer()
                    
                    // Status text
                    Text(statusMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal)
                        .accessibilityLabel("Status: \(statusMessage)")
                    
                    // New project button
                    Button(action: { isCreatingNewProject = true }) {
                        Label("New Project", systemImage: "plus")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.trailing, 16)
                    .accessibilityLabel("Create New Project")
                    .accessibilityHint("Opens dialog to create a new project")
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .background(designHeaderBg)
                .border(designBorder, width: 0.5)
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Recent projects
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Recent projects")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.top, 24)
                                .padding(.horizontal, 24)
                            
                            if filteredRecentProjects.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    
                                    Text("No results found")
                                        .font(.headline)
                                    
                                    Text("Try a different search term")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("No search results found for \(searchText)")
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)], spacing: 20) {
                                    ForEach(filteredRecentProjects) { project in
                                        ProjectCard(
                                            project: project, 
                                            onDeleteProject: deleteProject, 
                                            onRenameProject: onRenameProject,
                                            onToggleStar: toggleProjectStar
                                        )
                                            .onTapGesture {
                                                appState.navigateToProject(project)
                                                onProjectSelected(project)
                                            }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .background(designBg)
                    .tag(0)
                    
                    // All projects
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("All projects")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.top, 24)
                                .padding(.horizontal, 24)
                            
                            if filteredUserProjects.isEmpty && !searchText.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    
                                    Text("No results found")
                                        .font(.headline)
                                    
                                    Text("Try a different search term")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("No search results found for \(searchText)")
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)], spacing: 20) {
                                    ForEach(filteredUserProjects) { project in
                                        ProjectCard(
                                            project: project, 
                                            onDeleteProject: deleteProject, 
                                            onRenameProject: onRenameProject,
                                            onToggleStar: toggleProjectStar
                                        )
                                            .onTapGesture {
                                                appState.navigateToProject(project)
                                                onProjectSelected(project)
                                            }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .background(designBg)
                    .tag(1)
                    
                    // Templates
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text("Templates")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.top, 24)
                                .padding(.horizontal, 24)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)], spacing: 20) {
                                TemplateCard(name: "Mobile App", type: "Design", id: "mobile-app-template")
                                    .onTapGesture {
                                        selectedTemplateType = "Design"
                                        isCreatingNewProject = true
                                    }
                                    .accessibilityIdentifier("mobile-app-template")
                                
                                TemplateCard(name: "Website", type: "Prototype", id: "website-template")
                                    .onTapGesture {
                                        selectedTemplateType = "Prototype"
                                        isCreatingNewProject = true
                                    }
                                    .accessibilityIdentifier("website-template")
                                
                                TemplateCard(name: "Component Library", type: "Component Library", id: "component-library-template")
                                    .onTapGesture {
                                        selectedTemplateType = "Component Library"
                                        isCreatingNewProject = true
                                    }
                                    .accessibilityIdentifier("component-library-template")
                                
                                TemplateCard(name: "Style Guide", type: "Style Guide", id: "style-guide-template")
                                    .onTapGesture {
                                        selectedTemplateType = "Style Guide"
                                        isCreatingNewProject = true
                                    }
                                    .accessibilityIdentifier("style-guide-template")
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 24)
                    }
                    .background(designBg)
                    .tag(2)
                }
                // .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .sheet(isPresented: $isCreatingNewProject) {
            NewProjectSheet(
                isPresented: $isCreatingNewProject,
                initialProjectType: selectedTemplateType
            ) { name, type in
                // Save the template type for the editor to use for identifiers
                _ = selectedTemplateType
                onCreateNewProject(name, type)
                
                // Reset the selected template type
                selectedTemplateType = ""
            }
        }
        .onAppear {
            // Listen for notification to switch to Templates tab
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToTemplatesTab"),
                object: nil,
                queue: .main
            ) { _ in
                selectedTab = 2  // Index for Templates tab
            }
            
            // Listen for notification to switch to Recent tab
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToRecentTab"),
                object: nil,
                queue: .main
            ) { _ in
                selectedTab = 0  // Index for Recent tab
            }
            
            // Listen for notification to switch to All Projects tab
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SwitchToAllProjectsTab"),
                object: nil,
                queue: .main
            ) { _ in
                selectedTab = 1  // Index for All Projects tab
            }
        }
        // Add keyboard shortcuts
        .keyboardShortcut("f", modifiers: [.command])
        .onExitCommand {
            // Clear search when ESC is pressed
            if !searchText.isEmpty {
                searchText = ""
                updateStatusMessage()
            }
        }
    }
    
    // Helper function to start search
    func focusOnSearch() {
        // Post notification to focus search field
        NotificationCenter.default.post(
            name: NSNotification.Name("FocusSearchField"),
            object: nil
        )
    }
    
    // Helper function to show preferences 
    func showPreferences() {
        // Use View extension to show preferences
        self.openPreferences()
    }
}

struct ProjectCard: View {
    let project: Project
    let onDeleteProject: (Project) -> Void
    @State private var isHovered = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRenameDialog = false
    @State private var newProjectName = ""
    
    // For optional rename callback
    var onRenameProject: ((Project, String) -> Void)?
    // For optional star toggle callback
    var onToggleStar: ((Project) -> Void)?
    
    // Dynamic colors for light/dark mode adaptability
    private var cardBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                if project.thumbnail.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                        .accessibilityHidden(true)
                } else {
                    Image.placeholder(for: project.thumbnail)
                        .frame(height: 140)
                        .cornerRadius(8)
                        .clipped()
                        .accessibilityLabel("Project thumbnail")
                }
                
                // Show star indicator even when not hovering for starred projects
                if project.isStarred && !isHovered {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .clipShape(Circle())
                        .padding(8)
                }
                
                // Hover overlay
                if isHovered {
                    HStack {
                        Button(action: {
                            // Toggle the star status
                            if let onToggleStar = onToggleStar {
                                onToggleStar(project)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                            }
                        }) {
                            Image(systemName: project.isStarred ? "star.fill" : "star")
                                .foregroundColor(project.isStarred ? .yellow : .primary)
                                .padding(6)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(project.isStarred ? "Unstar project" : "Star project")
                        .accessibilityHint(project.isStarred ? "Remove from starred projects" : "Add to starred projects")
                        
                        Menu {
                            Button(action: {
                                // Show rename dialog
                                newProjectName = project.name
                                showingRenameDialog = true
                            }) {
                                Label("Rename Project", systemImage: "pencil")
                            }
                            .accessibilityIdentifier("rename-project")
                            .help("Rename this project")
                            
                            Button(action: {
                                // Show delete confirmation
                                showingDeleteConfirmation = true
                            }) {
                                Label("Delete Project", systemImage: "trash")
                            }
                            .foregroundColor(.red)
                            .accessibilityIdentifier("delete-project")
                            .help("Delete this project")
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .clipShape(Circle())
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .accessibilityLabel("Project options")
                        .accessibilityHint("Show options including delete")
                        .keyboardShortcut("d", modifiers: [.command, .shift], 
                             localization: KeyboardShortcut.Localization.automatic)
                    }
                    .padding(8)
                }
            }
            
            // Project info
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(formattedDate(project.lastModified))
                        .font(.caption)
                    Spacer()
                    Image(systemName: "person.fill")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last modified \(formattedDate(project.lastModified))")
            }
            .padding(12)
            .background(cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(project.name) project")
        .accessibilityHint("Double-tap to open project. Use option menu to access delete functionality.")
        .contextMenu {
            Button(action: {
                if let onToggleStar = onToggleStar {
                    onToggleStar(project)
                }
            }) {
                Label(project.isStarred ? "Unstar Project" : "Star Project", 
                      systemImage: project.isStarred ? "star.slash" : "star")
            }
            .keyboardShortcut("s", modifiers: [.command])
            
            Button(action: {
                newProjectName = project.name
                showingRenameDialog = true
            }) {
                Label("Rename Project", systemImage: "pencil")
            }
            .keyboardShortcut("r", modifiers: [.command])
            
            Button(action: {
                showingDeleteConfirmation = true
            }) {
                Label("Delete Project", systemImage: "trash")
            }
            .keyboardShortcut(.delete)
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Delete Project"),
                message: Text("Are you sure you want to delete \"\(project.name)\"? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDeleteProject(project)
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                },
                secondaryButton: .cancel()
            )
        }
        // Add rename dialog
        .sheet(isPresented: $showingRenameDialog) {
            VStack(spacing: 20) {
                Text("Rename Project")
                    .font(.headline)
                
                TextField("Project Name", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                    .onAppear {
                        // Focus the text field
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NSApp.keyWindow?.makeFirstResponder(nil)
                        }
                    }
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        showingRenameDialog = false
                    }
                    .keyboardShortcut(.escape)
                    
                    Button("Rename") {
                        if !newProjectName.isEmpty && newProjectName != project.name {
                            if let onRename = onRenameProject {
                                onRename(project, newProjectName)
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                            }
                        }
                        showingRenameDialog = false
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(newProjectName.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 400, height: 150)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct TemplateCard: View {
    let name: String
    let type: String
    let id: String
    @State private var isHovered = false
    
    // Dynamic colors for light/dark mode adaptability
    private var cardBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    init(name: String, type: String, id: String = "") {
        self.name = name
        self.type = type
        self.id = id.isEmpty ? "\(name.lowercased())-\(type.lowercased())-template" : id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                    .accessibilityHidden(true)
                
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    Text("Start with \(type)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Template info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                
                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name) \(type) template")
        .accessibilityHint("Double-tap to create a new project using this template")
        .id(id)
        .accessibilityIdentifier(id)
    }
}

struct NewProjectSheet: View {
    @Binding var isPresented: Bool
    let onCreateProject: (String, String) -> Void
    let initialProjectType: String
    
    @State private var projectName = ""
    @State private var selectedProjectType = 0
    
    let projectTypes = ["Design", "Prototype", "Component Library", "Style Guide"]
    
    init(isPresented: Binding<Bool>, initialProjectType: String = "", onCreateProject: @escaping (String, String) -> Void) {
        self._isPresented = isPresented
        self.onCreateProject = onCreateProject
        self.initialProjectType = initialProjectType
        
        // Set the initial selected project type based on the template
        let typeIndex = projectTypes.firstIndex(of: initialProjectType) ?? 0
        self._selectedProjectType = State(initialValue: typeIndex)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("New Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            
            // Project type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Project Type")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    ForEach(projectTypes.indices, id: \.self) { index in
                        ProjectTypeCard(
                            name: projectTypes[index],
                            isSelected: selectedProjectType == index
                        )
                        .onTapGesture {
                            selectedProjectType = index
                        }
                        .id("project-type-\(projectTypes[index].lowercased().replacingOccurrences(of: " ", with: "-"))")
                        .accessibilityIdentifier(selectedProjectType == index ? 
                            "selected-project-type-\(projectTypes[index].lowercased().replacingOccurrences(of: " ", with: "-"))" : 
                            "project-type-\(projectTypes[index].lowercased().replacingOccurrences(of: " ", with: "-"))")
                    }
                }
            }
            
            // Project name
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.headline)
                
                TextField("Untitled Project", text: $projectName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("project-name-field")
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                .accessibilityIdentifier("Cancel")
                
                Button("Create") {
                    if projectName.isEmpty {
                        onCreateProject("Untitled Project", projectTypes[selectedProjectType])
                    } else {
                        onCreateProject(projectName, projectTypes[selectedProjectType])
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .accessibilityIdentifier("Create")
            }
        }
        .padding(24)
        .frame(width: 600, height: 400)
        .accessibilityIdentifier("new-project-sheet")
    }
}

struct ProjectTypeCard: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        VStack {
            // Project type preview
            Rectangle()
                .fill(Color.white)
                .frame(width: 120, height: 80)
                .overlay(
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
                .border(isSelected ? Color.blue : Color.gray.opacity(0.3), width: isSelected ? 2 : 1)
            
            Text(name)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .primary)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) project type")
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(isSelected ? "selected-project-type-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))" : "project-type-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

// MARK: - Cursor Modifiers
struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onHover { isHovered in
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    HomeView(recentProjects: .constant([]), userProjects: .constant([]), statusMessage: .constant("Ready"), onProjectSelected: { _ in }, isCreatingNewProject: .constant(false), onCreateNewProject: { _, _ in })
} 
#endif
