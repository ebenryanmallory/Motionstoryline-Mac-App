import SwiftUI

struct NewProjectSheet: View {
    @Binding var isPresented: Bool
    let onCreateProject: (String, String) -> Void
    let initialProjectType: String
    let existingProjectNames: [String]
    
    @State private var projectName = ""
    @State private var selectedProjectType = 0
    @State private var nameValidationMessage = ""
    @State private var isNameValid = true
    
    let projectTypes = ["Design", "Prototype", "Component Library", "Style Guide"]
    
    init(isPresented: Binding<Bool>, initialProjectType: String = "", existingProjectNames: [String] = [], onCreateProject: @escaping (String, String) -> Void) {
        self._isPresented = isPresented
        self.onCreateProject = onCreateProject
        self.initialProjectType = initialProjectType
        self.existingProjectNames = existingProjectNames
        
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
                    .onChange(of: projectName) { oldValue, newValue in
                        validateProjectName(newValue)
                    }
                
                if !nameValidationMessage.isEmpty {
                    Text(nameValidationMessage)
                        .font(.caption)
                        .foregroundColor(isNameValid ? .secondary : .red)
                        .accessibilityIdentifier("name-validation-message")
                }
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
                    let finalName = getFinalProjectName()
                    onCreateProject(finalName, projectTypes[selectedProjectType])
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(!isNameValid && !projectName.isEmpty)
                .accessibilityIdentifier("Create")
            }
        }
        .padding(24)
        .frame(width: 600, height: 400)
        .accessibilityIdentifier("new-project-sheet")
        .onAppear {
            // Pre-validate the default name if the field is empty
            if projectName.isEmpty {
                validateProjectName("Untitled Project")
            }
        }
    }
    
    private func validateProjectName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            nameValidationMessage = ""
            isNameValid = true
            return
        }
        
        if existingProjectNames.contains(trimmedName) {
            let suggestedName = generateUniqueProjectName(baseName: trimmedName)
            nameValidationMessage = "Name already exists. Suggested: \"\(suggestedName)\""
            isNameValid = false
        } else {
            nameValidationMessage = "✓ Name is available"
            isNameValid = true
        }
    }
    
    private func generateUniqueProjectName(baseName: String) -> String {
        var counter = 1
        var candidateName = "\(baseName) \(counter)"
        
        while existingProjectNames.contains(candidateName) {
            counter += 1
            candidateName = "\(baseName) \(counter)"
        }
        
        return candidateName
    }
    
    private func getFinalProjectName() -> String {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return generateUniqueProjectName(baseName: "Untitled Project")
        }
        
        if existingProjectNames.contains(trimmedName) {
            return generateUniqueProjectName(baseName: trimmedName)
        }
        
        return trimmedName
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

#if !DISABLE_PREVIEWS
#Preview {
    NewProjectSheet(
        isPresented: .constant(true),
        initialProjectType: "Design",
        existingProjectNames: ["Test Project", "Another Project"]
    ) { name, type in
        print("Creating project: \(name) of type: \(type)")
    }
}
#endif