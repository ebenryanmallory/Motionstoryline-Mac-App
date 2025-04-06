import SwiftUI

class AppStateManager: ObservableObject {
    @Published var selectedProject: Project?
    
    func navigateToHome() {
        selectedProject = nil
    }
    
    func navigateToProject(_ project: Project) {
        selectedProject = project
    }
} 