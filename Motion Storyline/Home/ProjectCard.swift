import SwiftUI
import AppKit
import Foundation

struct ProjectCard: View {
    let project: Project
    let onDeleteProject: (Project) -> Void
    @State private var isHovered = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRenameDialog = false
    @State private var newProjectName = ""
    @State private var showingOptionsMenu = false
    
    // For optional rename callback
    var onRenameProject: ((Project, String) -> Void)?
    // For optional star toggle callback
    var onToggleStar: ((Project) -> Void)?
    
    // Dynamic colors for light/dark mode adaptability
    private var cardBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    var body: some View {
        ZStack {
            // Main card container
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail - full width
                if project.thumbnail.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fill)
                        .accessibilityHidden(true)
                } else {
                    PlaceholderView.create(for: project.thumbnail)
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .accessibilityLabel("Project thumbnail")
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
            
            // Overlay for star indicator and hover controls
            VStack(alignment: .trailing) {
                // Show star indicator even when not hovering for starred projects
                if project.isStarred && !isHovered && !showingOptionsMenu {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .padding(6)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .clipShape(Circle())
                        .padding(8)
                }
                
                // Hover overlay - show when hovered or when options menu is open
                if isHovered || showingOptionsMenu {
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
                        
                        // Custom popover button
                        Button(action: { showingOptionsMenu.toggle() }) {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingOptionsMenu, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Button(action: {
                                    showingOptionsMenu = false
                                    newProjectName = project.name
                                    showingRenameDialog = true
                                }) {
                                    Label("Rename Project", systemImage: "pencil")
                                        .foregroundColor(.primary)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("rename-project")
                                .help("Rename this project")
                                
                                Divider()
                                
                                Button(action: {
                                    showingOptionsMenu = false
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Project", systemImage: "trash")
                                        .foregroundColor(.red)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("delete-project")
                                .help("Delete this project")
                            }
                            .padding(8)
                            .frame(width: 200)
                        }
                        .accessibilityLabel("Project options")
                        .accessibilityHint("Show options including delete")
                        .onHover { isHovered in
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .padding(8)
                }
                
                Spacer()
            }
        }
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