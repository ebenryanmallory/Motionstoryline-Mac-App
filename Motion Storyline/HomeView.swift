import SwiftUI

struct HomeView: View {
    @Binding var recentProjects: [Project]
    @Binding var userProjects: [Project]
    @Binding var statusMessage: String
    let onProjectSelected: (Project) -> Void
    @Binding var isCreatingNewProject: Bool
    let onCreateNewProject: (String, String) -> Void
    @EnvironmentObject private var appState: AppStateManager
    
    @State private var selectedItem: String? = "Home"
    @State private var searchText: String = ""
    @State private var isDarkMode: Bool = false
    @State private var selectedTab: Int = 0
    @State private var isShowingUserMenu = false
    
    // Design Studio-like colors
    private let designBg = Color(NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0))
    private let designHeaderBg = Color.white
    private let designBorder = Color(NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedItem: $selectedItem,
                searchText: $searchText,
                isDarkMode: $isDarkMode,
                isCreatingNewProject: $isCreatingNewProject
            )
            .frame(minWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                // Top header (Design Studio-style)
                HStack(spacing: 16) {
                    // Design Studio logo
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        Text("DesignStudio")
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search files...", text: $searchText)
                            .frame(width: 200)
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    
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
                    .popover(isPresented: $isShowingUserMenu) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("User Account")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            Button("Profile", action: {})
                            Button("Settings", action: {})
                            Divider()
                            Button("Sign Out", action: {})
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
                                .foregroundColor(selectedTab == index ? .black : .gray)
                        }
                        .buttonStyle(.plain)
                        .background(
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(selectedTab == index ? Color.blue : Color.clear)
                                    .frame(height: 2)
                            }
                        )
                    }
                    Spacer()
                    
                    // Status text
                    Text(statusMessage)
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal)
                    
                    // New project button
                    Button(action: { isCreatingNewProject = true }) {
                        Label("New Project", systemImage: "plus")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.trailing, 16)
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
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)], spacing: 20) {
                                ForEach(recentProjects) { project in
                                    ProjectCard(project: project)
                                        .onTapGesture {
                                            appState.navigateToProject(project)
                                            onProjectSelected(project)
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
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
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)], spacing: 20) {
                                ForEach(userProjects) { project in
                                    ProjectCard(project: project)
                                        .onTapGesture {
                                            appState.navigateToProject(project)
                                            onProjectSelected(project)
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
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
                                TemplateCard(name: "Mobile App", type: "Design")
                                    .onTapGesture {
                                        isCreatingNewProject = true
                                    }
                                
                                TemplateCard(name: "Website", type: "Prototype")
                                    .onTapGesture {
                                        isCreatingNewProject = true
                                    }
                                
                                TemplateCard(name: "Component Library", type: "Component Library")
                                    .onTapGesture {
                                        isCreatingNewProject = true
                                    }
                                
                                TemplateCard(name: "Style Guide", type: "Style Guide")
                                    .onTapGesture {
                                        isCreatingNewProject = true
                                    }
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
            NewProjectSheet(isPresented: $isCreatingNewProject) { name, type in
                onCreateNewProject(name, type)
            }
        }
    }
}

struct ProjectCard: View {
    let project: Project
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                if project.thumbnail.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    Image.placeholder(for: project.thumbnail)
                        .frame(height: 140)
                        .cornerRadius(8)
                        .clipped()
                }
                
                // Hover overlay
                if isHovered {
                    HStack {
                        Button(action: {}) {
                            Image(systemName: "star")
                                .foregroundColor(.black)
                                .padding(6)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.black)
                                .padding(6)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
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
            }
            .padding(12)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
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
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(8)
                
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
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
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct NewProjectSheet: View {
    @Binding var isPresented: Bool
    let onCreateProject: (String, String) -> Void
    
    @State private var projectName = ""
    @State private var selectedProjectType = 0
    
    let projectTypes = ["Design", "Prototype", "Component Library", "Style Guide"]
    
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
                    }
                }
            }
            
            // Project name
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.headline)
                
                TextField("Untitled Project", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
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
            }
        }
        .padding(24)
        .frame(width: 600, height: 400)
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
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    HomeView(recentProjects: .constant([]), userProjects: .constant([]), statusMessage: .constant("Ready"), onProjectSelected: { _ in }, isCreatingNewProject: .constant(false), onCreateNewProject: { _, _ in })
} 
#endif
