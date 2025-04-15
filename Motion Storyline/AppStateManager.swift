import SwiftUI

class AppStateManager: ObservableObject {
    // Add a shared instance for global access
    static let shared = AppStateManager()
    
    @Published var selectedProject: Project?
    @AppStorage("isDarkMode") private(set) var isDarkMode: Bool = false
    @AppStorage("appearance") private var appearance: Int = AppAppearance.system.rawValue
    
    // Documentation state
    @Published var activeDocumentationType: DocumentationService.DocumentationType?
    @Published var isDocumentationVisible: Bool = false
    
    func navigateToHome() {
        selectedProject = nil
    }
    
    func navigateToProject(_ project: Project) {
        selectedProject = project
    }
    
    func updateProject(_ project: Project) {
        // Only update if it's the currently selected project
        if selectedProject?.id == project.id {
            selectedProject = project
        }
    }
    
    func toggleAppearance() {
        isDarkMode.toggle()
        updateAppAppearance()
    }
    
    func setAppearance(_ newAppearance: AppAppearance) {
        appearance = newAppearance.rawValue
        
        // Update isDarkMode for backward compatibility
        switch newAppearance {
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        case .system:
            // Set based on system appearance
            if let systemAppearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) {
                isDarkMode = systemAppearance == .darkAqua
            }
        }
        
        updateAppAppearance()
    }
    
    // Documentation functions
    func showDocumentation(_ type: DocumentationService.DocumentationType) {
        activeDocumentationType = type
        isDocumentationVisible = true
    }
    
    func hideDocumentation() {
        isDocumentationVisible = false
    }
    
    func updateAppAppearance() {
        let currentAppearance = AppAppearance(rawValue: appearance) ?? .system
        
        var appearanceName: NSAppearance.Name
        
        switch currentAppearance {
        case .light:
            appearanceName = .aqua
        case .dark:
            appearanceName = .darkAqua
        case .system:
            // For system, we still use the isDarkMode value for backward compatibility
            appearanceName = isDarkMode ? .darkAqua : .aqua
        }
        
        NSApp.appearance = NSAppearance(named: appearanceName)
    }
    
    init() {
        // Initialize app appearance based on saved preference
        updateAppAppearance()
    }
} 