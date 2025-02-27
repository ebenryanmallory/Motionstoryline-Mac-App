import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: String?
    @Binding var searchText: String
    @Binding var isDarkMode: Bool
    @Binding var isCreatingNewProject: Bool
    
    let sidebarItems = ["Home", "Projects", "Tasks", "Settings"]
    
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
            List(selection: $selectedItem) {
                Section(header: Text("Menu")) {
                    ForEach(sidebarItems, id: \.self) { item in
                        Label(item, systemImage: getSystemImage(for: item))
                    }
                }
                
                Section(header: Text("Tools")) {
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 5)
                    
                    Toggle("Dark Mode", isOn: $isDarkMode)
                        .toggleStyle(.switch)
                    
                    Button(action: {
                        isCreatingNewProject = true
                    }) {
                        Label("New Project", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private func getSystemImage(for item: String) -> String {
        switch item {
        case "Home":
            return "house"
        case "Projects":
            return "folder"
        case "Tasks":
            return "checklist"
        case "Settings":
            return "gear"
        default:
            return "circle"
        }
    }
}

#Preview {
    SidebarView(
        selectedItem: .constant("Home"),
        searchText: .constant(""),
        isDarkMode: .constant(false),
        isCreatingNewProject: .constant(false)
    )
} 