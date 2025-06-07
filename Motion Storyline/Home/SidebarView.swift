import SwiftUI
import AppKit
import Foundation

// Import PreferencesController

struct SidebarView: View {
    @Binding var selectedItem: String?
    @Binding var searchText: String
    @Binding var isCreatingNewProject: Bool
    @EnvironmentObject var appState: AppStateManager
    @State private var isShowingPreferencesSheet = false
    
    let sidebarItems = ["Home", "Projects", "Templates", "Settings"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                Text("Navigation")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Sidebar content
            List {
                Section(header: Text("Menu")) {
                    ForEach(sidebarItems, id: \.self) { item in
                        SidebarItemView(
                            item: item,
                            systemImage: getSystemImage(for: item),
                            isSelected: selectedItem == item
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            
                            // Handle special cases
                            if item == "Settings" {
                                isShowingPreferencesSheet = true
                            } else if item == "Templates" {
                                // Post notification to switch to templates tab
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchToTemplatesTab"),
                                    object: nil
                                )
                            } else if item == "Home" {
                                // Post notification to switch to recent tab
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchToRecentTab"),
                                    object: nil
                                )
                            } else if item == "Projects" {
                                // Post notification to switch to all projects tab
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SwitchToAllProjectsTab"),
                                    object: nil
                                )
                            }
                        }
                        .background(selectedItem == item ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                
                Section(header: Text("Tools")) {
                    HStack {
                        TextField("Search...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                            .animation(.easeInOut, value: searchText.isEmpty)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.vertical, 5)
                    
                    Toggle("Dark Mode", isOn: Binding<Bool>(
                        get: { appState.isDarkMode },
                        set: { _ in appState.toggleAppearance() }
                    ))
                        .toggleStyle(.switch)
                    
                    Button(action: {
                        isCreatingNewProject = true
                    }) {
                        Label("New Project", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $isShowingPreferencesSheet) {
            PreferencesView()
        }
    }
    
    private func getSystemImage(for item: String) -> String {
        switch item {
        case "Home":
            return "house"
        case "Projects":
            return "folder"
        case "Templates":
            return "doc.badge.plus"
        case "Settings":
            return "gear"
        default:
            return "circle"
        }
    }
}

struct SidebarItemView: View {
    let item: String
    let systemImage: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .frame(width: 20)
            Text(item)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    SidebarView(
        selectedItem: .constant("Home"),
        searchText: .constant(""),
        isCreatingNewProject: .constant(false)
    )
    .environmentObject(AppStateManager())
} 
#endif 