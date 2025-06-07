import SwiftUI
import Combine

class AppStateManager: ObservableObject {
    // Add a shared instance for global access
    static let shared = AppStateManager()
    
    @Published var selectedProject: Project?
    @AppStorage("isDarkMode") private(set) var isDarkMode: Bool = false
    @AppStorage("appearance") private var appearance: Int = AppAppearance.system.rawValue
    
    // Documentation state
    @Published var activeDocumentationType: DocumentationService.DocumentationType?
    @Published var isDocumentationVisible: Bool = false

    // Scene Phase for auto-save and lifecycle management
    @Published var scenePhase: ScenePhase = .active

    // Project State for UI updates (e.g., window title)
    @Published var currentProjectURL: URL? = nil
    @Published var hasUnsavedChanges: Bool = false
    @Published var currentTimelineScale: Double = 1.0
    @Published var currentTimelineOffset: Double = 0.0
    @Published var currentProjectName: String = "Untitled Project"
    @Published var currentProjectURLToLoad: URL? = nil
    @Published var isShowingOpenDialog: Bool = false

    @Published var undoRedoManager = UndoRedoManager()
    // Undo/Redo State & Actions
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    var undoAction: (() -> Void)?
    var redoAction: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
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

    // MARK: - Undo/Redo Integration
    func registerUndoRedoActions(
        undo: @escaping () -> Void,
        redo: @escaping () -> Void,
        canUndoPublisher: AnyPublisher<Bool, Never>,
        canRedoPublisher: AnyPublisher<Bool, Never>,
        hasUnsavedChangesPublisher: AnyPublisher<Bool, Never>,
        currentProjectURLPublisher: AnyPublisher<URL?, Never>
    ) {
        self.undoAction = undo
        self.redoAction = redo

        // Clear previous subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        canUndoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canUndoValue in
                self?.canUndo = canUndoValue
            }
            .store(in: &cancellables)

        canRedoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canRedoValue in
                self?.canRedo = canRedoValue
            }
            .store(in: &cancellables)

        hasUnsavedChangesPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasUnsavedChanges)

        currentProjectURLPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentProjectURL)
    }

    func clearUndoRedoActions() {
        self.undoAction = nil
        self.redoAction = nil
        self.canUndo = false
        self.canRedo = false
        self.hasUnsavedChanges = false
        self.currentProjectURL = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
} 