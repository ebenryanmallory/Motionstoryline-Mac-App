import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// Define ExportFormat at the top level so it's accessible to all structs
enum ExportFormat {
    case video
    case gif
    case imageSequence
    case projectFile
}

// Add this class outside the DesignCanvas struct
class AnimationController: ObservableObject {
    @Published var currentTime: Double = 0
    var totalDuration: Double = 60.0
    private var timer: Timer?
    
    func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Update time
            var newTime = self.currentTime + 1/30
            
            // Loop back to start when reaching the end
            if newTime >= self.totalDuration {
                newTime = 0
            }
            
            self.currentTime = newTime
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    deinit {
        stopTimer()
    }
}

struct DesignCanvas: View {
    let project: Project
    let onClose: () -> Void
    let onCreateNewProject: ((Project) -> Void)?
    let onUpdateProject: ((Project) -> Void)?
    
    @State private var zoom: CGFloat
    @State private var panOffset: CGPoint
    @State private var selectedTool: DesignTool = .select
    @State private var selectedLayer: String?
    @State private var isInspectorVisible = true
    @State private var isLayersPanelVisible = true
    @State private var showGrid = true
    @State private var currentPage = "Page 1"
    @State private var pages = ["Page 1", "Page 2", "Page 3"]
    @State private var isNewFileSheetPresented = false
    @State private var isCameraRecordingPresented = false
    @State private var showNewRecordingAlert = false
    @State private var newRecordingURL: URL?
    @State private var newRecordingFilename: String = ""
    
    // Video editing specific state
    @State private var isTimelinePanelVisible = true
    @State private var selectedClip: String?
    @State private var timelineZoom: CGFloat = 1.0
    @State private var selectedProperty: String?
    @State private var showAnimationPreview: Bool = true
    @State private var showKeyframeEditor: Bool = false
    @State private var showEasingControls: Bool = false
    @State private var selectedKeyframe: (String, Double, Double)?
    @State private var selectedEasing: EasingType = .linear
    
    // Sample keyframes for animation (property, time, value)
    @State private var keyframes: [(String, Double, Double)] = [
        ("Position X", 0, 200),
        ("Position X", 15, 400),
        ("Position X", 30, 200),
        ("Position Y", 0, 100),
        ("Position Y", 20, 200),
        ("Position Y", 40, 100),
        ("Scale", 0, 100),
        ("Scale", 10, 150),
        ("Scale", 25, 80),
        ("Scale", 45, 100),
        ("Rotation", 0, 0),
        ("Rotation", 30, 360),
        ("Opacity", 0, 100),
        ("Opacity", 5, 50),
        ("Opacity", 35, 100)
    ]
    
    // Design Studio color scheme
    let designBg = Color(NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0))
    let designToolbarBg = Color(NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    let designBorder = Color(NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
    
    // Replace the currentTime state variable with the controller
    @StateObject private var animationController = AnimationController()
    // Keep isPlaying as a state variable
    @State private var isPlaying = false
    
    // Initialize with project's viewport settings
    init(project: Project, onClose: @escaping () -> Void, onCreateNewProject: ((Project) -> Void)? = nil, onUpdateProject: ((Project) -> Void)? = nil) {
        self.project = project
        self.onClose = onClose
        self.onCreateNewProject = onCreateNewProject
        self.onUpdateProject = onUpdateProject
        
        // Initialize state variables with project's viewport settings
        _zoom = State(initialValue: project.zoomLevel)
        _panOffset = State(initialValue: CGPoint(x: project.panOffsetX, y: project.panOffsetY))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar (Design Studio-style)
            TopBar(
                projectName: project.name,
                onClose: {
                    // Save viewport settings before closing
                    saveViewportSettings()
                    onClose()
                },
                onNewFile: { isNewFileSheetPresented = true },
                onCameraRecord: { isCameraRecordingPresented = true },
                isPlaying: $isPlaying,
                showAnimationPreview: $showAnimationPreview,
                onExport: { format in
                    exportProject(as: format)
                },
                onAccountSettings: showAccountSettings,
                onPreferences: showPreferences,
                onHelpAndSupport: openHelpAndSupport,
                onCheckForUpdates: checkForUpdates,
                onSignOut: signOut
            )
                .background(designToolbarBg)
                .border(designBorder, width: 1)
            
            // Main content area
            HStack(spacing: 0) {
                // Left sidebar (Layers & Assets)
                if isLayersPanelVisible {
                    LayersPanelView(selectedLayer: $selectedLayer)
                        .frame(width: 240)
                        .background(Color.white)
                        .border(designBorder, width: 1)
                }
                
                // Main canvas area
                VStack(spacing: 0) {
                    // Toolbar
                    DesignToolbar(
                        selectedTool: $selectedTool,
                        zoom: $zoom,
                        showGrid: $showGrid,
                        currentPage: $currentPage,
                        pages: pages,
                        onZoomChanged: { 
                            // Save viewport settings when zoom changes
                            saveViewportSettings()
                        }
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(designToolbarBg)
                    .border(designBorder, width: 1)
                    
                    // Canvas
                    ZStack {
                        // Background
                        designBg
                        
                        // Background grid
                        if showGrid {
                            GridBackgroundView()
                        }
                        
                        // Canvas content
                        CanvasContentView(
                            currentTime: $animationController.currentTime,
                            isPlaying: $isPlaying,
                            selectedProperty: $selectedProperty,
                            showAnimationPreview: $showAnimationPreview,
                            keyframes: keyframes
                        )
                            .scaleEffect(zoom)
                            .offset(x: panOffset.x, y: panOffset.y)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if selectedTool == .hand {
                                            panOffset = CGPoint(
                                                x: panOffset.x + value.translation.width,
                                                y: panOffset.y + value.translation.height
                                            )
                                            // Save viewport settings after panning
                                            saveViewportSettings()
                                        }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Video playback controls
                    VideoPlaybackControls(
                        currentTime: $animationController.currentTime,
                        isPlaying: $isPlaying,
                        totalDuration: animationController.totalDuration
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(designToolbarBg)
                    .border(designBorder, width: 1)
                    
                    // Timeline panel
                    if isTimelinePanelVisible {
                        VideoTimelinePanel(
                            currentTime: $animationController.currentTime,
                            isPlaying: $isPlaying,
                            totalDuration: animationController.totalDuration,
                            timelineZoom: $timelineZoom,
                            selectedClip: $selectedClip,
                            showKeyframeEditor: showKeyframeEditor,
                            selectedProperty: $selectedProperty,
                            showAnimationProperties: $showEasingControls,
                            keyframes: keyframes,
                            onKeyframeSelected: { keyframe in
                                selectedKeyframe = keyframe
                                showKeyframeEditor = true
                            }
                        )
                        .frame(height: 200)
                        .background(Color.white)
                        .border(designBorder, width: 1)
                    }
                }
                
                // Right sidebar (Inspector)
                if isInspectorVisible {
                    InspectorView()
                        .frame(width: 280)
                        .background(Color.white)
                        .border(designBorder, width: 1)
                }
                
                // Right sidebar (optional)
                if showEasingControls {
                    EasingControlsView(
                        selectedEasing: $selectedEasing,
                        selectedProperty: $selectedProperty,
                        currentTime: $animationController.currentTime,
                        keyframes: keyframes,
                        onKeyframeSelected: { keyframe in
                            selectedKeyframe = keyframe
                            showKeyframeEditor = true
                        }
                    )
                    .frame(width: 300)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: { isLayersPanelVisible.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
            }
            
            ToolbarItem {
                Button(action: { isTimelinePanelVisible.toggle() }) {
                    Image(systemName: "rectangle.bottomthird.inset.filled")
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { showEasingControls.toggle() }) {
                    Label("Animation Controls", systemImage: "waveform.path")
                        .foregroundColor(showEasingControls ? .blue : .primary)
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: { showAnimationPreview.toggle() }) {
                    Label("Animation Preview", systemImage: "play.rectangle")
                }
            }
        }
        .sheet(isPresented: $isNewFileSheetPresented) {
            NewFileSheet(isPresented: $isNewFileSheetPresented) { fileName, fileType in
                // Save current viewport settings before creating new project
                saveViewportSettings()
                
                // Create a new project with the file name and type
                let newProject = Project(
                    name: fileName,
                    thumbnail: getThumbnailForFileType(fileType),
                    lastModified: Date()
                )
                
                // Call the onCreateNewProject callback if it exists
                if let onCreateNewProject = onCreateNewProject {
                    onCreateNewProject(newProject)
                }
            }
        }
        .sheet(isPresented: $isCameraRecordingPresented) {
            CameraRecordingView(isPresented: $isCameraRecordingPresented)
        }
        .alert(isPresented: $showNewRecordingAlert) {
            Alert(
                title: Text("New Recording Available"),
                message: Text("Would you like to import '\(newRecordingFilename)' into your project?"),
                primaryButton: .default(Text("Import")) {
                    importRecordingIntoProject()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            setupNotificationObserver()
        }
        .onDisappear {
            removeNotificationObserver()
        }
    }
    
    // Setup notification observer for new camera recordings
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NewCameraRecordingAvailable"),
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["url"] as? URL,
               let filename = notification.userInfo?["filename"] as? String {
                self.newRecordingURL = url
                self.newRecordingFilename = filename
                self.showNewRecordingAlert = true
            }
        }
    }
    
    // Remove notification observer
    private func removeNotificationObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("NewCameraRecordingAvailable"),
            object: nil
        )
    }
    
    // Import the recording into the current project
    private func importRecordingIntoProject() {
        guard let url = newRecordingURL else { return }
        
        // Create a new media asset for the recording
        let mediaAsset = MediaAsset(
            name: newRecordingFilename,
            type: .cameraRecording,
            url: url,
            duration: 0, // We would need to get the actual duration from the video file
            thumbnail: "recording_thumbnail" // Use a placeholder thumbnail
        )
        
        // Add the asset to the project
        var updatedProject = project
        updatedProject.addMediaAsset(mediaAsset)
        
        // Update the project
        if let onUpdateProject = onUpdateProject {
            onUpdateProject(updatedProject)
        }
        
        print("Imported recording \(mediaAsset.name) into project \(project.name)")
    }
    
    // Save the current viewport settings to the project
    private func saveViewportSettings() {
        // Create an updated project with current viewport settings
        var updatedProject = project
        updatedProject.zoomLevel = zoom
        updatedProject.panOffsetX = panOffset.x
        updatedProject.panOffsetY = panOffset.y
        
        // Call the onUpdateProject callback if it exists
        if let onUpdateProject = onUpdateProject {
            onUpdateProject(updatedProject)
        }
    }
    
    // Helper function to get a thumbnail based on file type
    private func getThumbnailForFileType(_ fileType: String) -> String {
        switch fileType {
        case "Video":
            return "video_thumbnail"
        case "Animation":
            return "animation_thumbnail"
        case "Screen Recording":
            return "recording_thumbnail"
        case "Presentation":
            return "presentation_thumbnail"
        default:
            return "placeholder"
        }
    }
    
    // MARK: - Animation Control Methods
    private func togglePlayback() {
        isPlaying.toggle()
        
        // If starting playback, ensure animation preview is visible
        if isPlaying && !showAnimationPreview {
            showAnimationPreview = true
        }
        
        // Start or stop the animation timer
        if isPlaying {
            animationController.startTimer()
        } else {
            animationController.stopTimer()
        }
    }
    
    // MARK: - Export Methods
    func exportProject(as format: ExportFormat) {
        // Create a save panel
        let savePanel = NSSavePanel()
        
        // Configure based on format
        switch format {
        case .video:
            savePanel.title = "Export Video"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.nameFieldStringValue = "\(project.name).mp4"
            savePanel.allowedContentTypes = [UTType.mpeg4Movie]
            
        case .gif:
            savePanel.title = "Export GIF"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.nameFieldStringValue = "\(project.name).gif"
            savePanel.allowedContentTypes = [UTType.gif]
            
        case .imageSequence:
            savePanel.title = "Export Image Sequence"
            savePanel.nameFieldLabel = "Export To Folder:"
            savePanel.nameFieldStringValue = "\(project.name)_sequence"
            savePanel.allowedContentTypes = [UTType.folder]
            
        case .projectFile:
            savePanel.title = "Export Project File"
            savePanel.nameFieldLabel = "Export As:"
            savePanel.nameFieldStringValue = "\(project.name).msl"
            savePanel.allowedContentTypes = [UTType.data]
        }
        
        // Show the save panel
        if let window = NSApplication.shared.keyWindow {
            savePanel.beginSheetModal(for: window) { response in
                if response == .OK, let url = savePanel.url {
                    // Perform the actual export based on format
                    switch format {
                    case .video:
                        self.exportAsVideo(to: url)
                    case .gif:
                        self.exportAsGIF(to: url)
                    case .imageSequence:
                        self.exportAsImageSequence(to: url)
                    case .projectFile:
                        self.exportAsProjectFile(to: url)
                    }
                }
            }
        } else {
            // Fallback if no window is available
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    // Perform the actual export based on format
                    switch format {
                    case .video:
                        self.exportAsVideo(to: url)
                    case .gif:
                        self.exportAsGIF(to: url)
                    case .imageSequence:
                        self.exportAsImageSequence(to: url)
                    case .projectFile:
                        self.exportAsProjectFile(to: url)
                    }
                }
            }
        }
    }
    
    // Export as video file
    private func exportAsVideo(to url: URL) {
        // In a real implementation, this would render the animation to a video file
        print("Exporting video to: \(url.path)")
        
        // Show a success message
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Your animation has been exported as a video file."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // Export as GIF
    private func exportAsGIF(to url: URL) {
        // In a real implementation, this would render the animation to a GIF
        print("Exporting GIF to: \(url.path)")
        
        // Show a success message
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Your animation has been exported as a GIF."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // Export as image sequence
    private func exportAsImageSequence(to url: URL) {
        // In a real implementation, this would render the animation to a sequence of images
        print("Exporting image sequence to: \(url.path)")
        
        // Show a success message
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Your animation has been exported as an image sequence."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // Export as project file
    private func exportAsProjectFile(to url: URL) {
        // In a real implementation, this would serialize the project to a file
        print("Exporting project file to: \(url.path)")
        
        // Show a success message
        let alert = NSAlert()
        alert.messageText = "Export Successful"
        alert.informativeText = "Your project has been exported as a project file."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - User Menu Actions
    
    private func showAccountSettings() {
        // In a real implementation, this would show an account settings sheet
        let alert = NSAlert()
        alert.messageText = "Account Settings"
        alert.informativeText = "This would display your account settings in a real implementation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPreferences() {
        // In a real implementation, this would show a preferences sheet
        let alert = NSAlert()
        alert.messageText = "Preferences"
        alert.informativeText = "This would display application preferences in a real implementation."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func openHelpAndSupport() {
        // Open help website in browser
        if let url = URL(string: "https://help.motionstoryline.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkForUpdates() {
        // In a real implementation, this would check for app updates
        let alert = NSAlert()
        alert.messageText = "Checking for Updates"
        alert.informativeText = "Motion Storyline is up to date (version 1.0)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func signOut() {
        // In a real implementation, this would sign the user out and return to login screen
        let alert = NSAlert()
        alert.messageText = "Sign Out"
        alert.informativeText = "Are you sure you want to sign out? Any unsaved changes will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Sign out and close the project
            onClose()
        }
    }
}

struct TopBar: View {
    let projectName: String
    let onClose: () -> Void
    let onNewFile: () -> Void
    let onCameraRecord: () -> Void
    
    // Add bindings and callbacks for the functionality
    @Binding var isPlaying: Bool
    @Binding var showAnimationPreview: Bool
    let onExport: (ExportFormat) -> Void
    let onAccountSettings: () -> Void
    let onPreferences: () -> Void
    let onHelpAndSupport: () -> Void
    let onCheckForUpdates: () -> Void
    let onSignOut: () -> Void
    
    @State private var isShowingMenu = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onClose) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            
            // Design Studio logo (placeholder)
            Circle()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
            
            // File menu
            Menu {
                Button("New File", action: onNewFile)
                Button("Open...", action: {})
                Divider()
                Button("Save", action: {})
                Button("Save As...", action: {})
                Divider()
                Button("Export...", action: {})
            } label: {
                Text("File")
                    .foregroundColor(.black)
            }
            
            // Edit menu
            Menu {
                Button("Undo", action: {})
                Button("Redo", action: {})
                Divider()
                Button("Cut", action: {})
                Button("Copy", action: {})
                Button("Paste", action: {})
            } label: {
                Text("Edit")
                    .foregroundColor(.black)
            }
            
            // View menu
            Menu {
                Button("Zoom In", action: {})
                Button("Zoom Out", action: {})
                Button("Zoom to 100%", action: {})
                Divider()
                Button("Show Grid", action: {})
                Button("Show Rulers", action: {})
            } label: {
                Text("View")
                    .foregroundColor(.black)
            }
            
            Divider()
                .frame(height: 20)
            
            // Project name
            Text(projectName)
                .fontWeight(.medium)
            
            Spacer()
            
            // Right side items
            HStack(spacing: 16) {
                Button(action: {
                    // Toggle playback state
                    isPlaying.toggle()
                    
                    // If starting playback, ensure animation preview is visible
                    if isPlaying && !showAnimationPreview {
                        showAnimationPreview = true
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.black)
                }
                .help(isPlaying ? "Pause Animation" : "Play Animation")
                
                Button(action: onCameraRecord) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.black)
                }
                
                Menu {
                    Button("Export as Video") {
                        onExport(.video)
                    }
                    
                    Button("Export as GIF") {
                        onExport(.gif)
                    }
                    
                    Button("Export as Image Sequence") {
                        onExport(.imageSequence)
                    }
                    
                    Divider()
                    
                    Button("Export Project File") {
                        onExport(.projectFile)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.black)
                }
                .help("Export Project")
                
                Menu {
                    Button("Account Settings") {
                        onAccountSettings()
                    }
                    
                    Button("Preferences") {
                        onPreferences()
                    }
                    
                    Divider()
                    
                    Button("Help & Support") {
                        onHelpAndSupport()
                    }
                    
                    Button("Check for Updates") {
                        onCheckForUpdates()
                    }
                    
                    Divider()
                    
                    Button("Sign Out") {
                        onSignOut()
                    }
                } label: {
                    Image(systemName: "person.circle")
                        .foregroundColor(.black)
                }
                .help("User Menu")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

struct NewFileSheet: View {
    @Binding var isPresented: Bool
    let onCreateFile: (String, String) -> Void
    
    @State private var fileName = ""
    @State private var selectedFileType = 0
    
    let fileTypes = ["Video", "Animation", "Screen Recording", "Presentation"]
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("New File")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // File type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("File Type")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    ForEach(fileTypes.indices, id: \.self) { index in
                        FileTypeCard(
                            name: fileTypes[index],
                            isSelected: selectedFileType == index
                        )
                        .onTapGesture {
                            selectedFileType = index
                        }
                    }
                }
            }
            
            // File name
            VStack(alignment: .leading, spacing: 8) {
                Text("File Name")
                    .font(.headline)
                
                TextField("Untitled", text: $fileName)
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
                    if fileName.isEmpty {
                        onCreateFile("Untitled", fileTypes[selectedFileType])
                    } else {
                        onCreateFile(fileName, fileTypes[selectedFileType])
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

struct FileTypeCard: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        VStack {
            // File type preview
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

struct DesignToolbar: View {
    @Binding var selectedTool: DesignTool
    @Binding var zoom: CGFloat
    @Binding var showGrid: Bool
    @Binding var currentPage: String
    let pages: [String]
    let onZoomChanged: () -> Void
    
    var body: some View {
        HStack {
            // Tools
            HStack(spacing: 2) {
                ForEach([
                    (DesignTool.select, "arrow.up.left.and.arrow.down.right", "Select"),
                    (DesignTool.rectangle, "rectangle", "Rectangle"),
                    (DesignTool.ellipse, "circle", "Ellipse"),
                    (DesignTool.text, "text.cursor", "Text"),
                    (DesignTool.pen, "pencil", "Pen"),
                    (DesignTool.hand, "hand.raised", "Hand")
                ], id: \.0) { tool, icon, tooltip in
                    Button {
                        selectedTool = tool
                    } label: {
                        Image(systemName: icon)
                            .padding(8)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                    .help(tooltip)
                }
            }
            .padding(2)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            Spacer()
            
            // Pages dropdown
            Menu {
                ForEach(pages, id: \.self) { page in
                    Button(page) {
                        currentPage = page
                    }
                }
                Divider()
                Button("Add page", action: {})
            } label: {
                HStack {
                    Text(currentPage)
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            }
            
            Spacer()
            
            // Zoom controls
            HStack {
                Button {
                    zoom = max(0.25, zoom - 0.25)
                    onZoomChanged()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                
                Text("\(Int(zoom * 100))%")
                    .frame(width: 60)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                
                Button {
                    zoom = min(4, zoom + 0.25)
                    onZoomChanged()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                
                Menu {
                    Button("Fit", action: {})
                    Button("50%") { 
                        zoom = 0.5
                        onZoomChanged()
                    }
                    Button("100%") { 
                        zoom = 1.0
                        onZoomChanged()
                    }
                    Button("200%") { 
                        zoom = 2.0
                        onZoomChanged()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
    }
}

enum DesignTool {
    case select, rectangle, ellipse, text, pen, hand
}

struct LayersPanelView: View {
    @Binding var selectedLayer: String?
    @State private var isSearching = false
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
                Button(action: { isSearching.toggle() }) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Search field (if searching)
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search layers...", text: $searchText)
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .opacity(searchText.isEmpty ? 0 : 1)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Layers list
            List(selection: $selectedLayer) {
                DisclosureGroup("Page 1") {
                    HStack {
                        Image(systemName: "rectangle")
                            .foregroundColor(.blue)
                        Text("Rectangle 1")
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.green)
                        Text("Ellipse 1")
                    }
                    .padding(.vertical, 2)
                    
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.black)
                        Text("Text Layer")
                    }
                    .padding(.vertical, 2)
                }
                
                Section("Assets") {
                    DisclosureGroup("Colors") {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                            Text("Red")
                        }
                        
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 16, height: 16)
                            Text("Blue")
                        }
                    }
                    
                    DisclosureGroup("Components") {
                        Text("Button")
                        Text("Card")
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }
}

struct InspectorView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Inspector header
            HStack {
                Text("Design")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Tab selector
            HStack(spacing: 0) {
                ForEach(["Design", "Prototype", "Inspect"], id: \.self) { tab in
                    let index = ["Design", "Prototype", "Inspect"].firstIndex(of: tab) ?? 0
                    Button(action: { selectedTab = index }) {
                        Text(tab)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
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
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // Inspector content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Layer properties
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layer")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Position and size
                        HStack {
                            VStack(alignment: .leading) {
                                Text("X")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("", value: .constant(100), formatter: NumberFormatter())
                                    .frame(width: 60)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Y")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("", value: .constant(100), formatter: NumberFormatter())
                                    .frame(width: 60)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("W")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("", value: .constant(200), formatter: NumberFormatter())
                                    .frame(width: 60)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("H")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("", value: .constant(100), formatter: NumberFormatter())
                                    .frame(width: 60)
                            }
                        }
                        
                        // Constraints
                        HStack {
                            Text("Constraints")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "link")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Constraint controls (simplified)
                        HStack {
                            VStack {
                                Image(systemName: "arrow.up")
                                Text("Top")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Image(systemName: "arrow.right")
                                Text("Right")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Image(systemName: "arrow.down")
                                Text("Bottom")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack {
                                Image(systemName: "arrow.left")
                                Text("Left")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Fill
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fill")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack {
                            ColorPicker("", selection: .constant(.blue))
                            Text("Solid")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("100%")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Stroke
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stroke")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack {
                            ColorPicker("", selection: .constant(Color.black))
                            Text("Solid")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("1px")
                                .foregroundColor(.secondary)
                        }
                        
                        // Stroke options
                        HStack {
                            Text("Weight")
                                .foregroundColor(.secondary)
                            Spacer()
                            TextField("", value: .constant(1), formatter: NumberFormatter())
                                .frame(width: 60)
                        }
                        
                        Picker("", selection: .constant(0)) {
                            Text("Inside").tag(0)
                            Text("Center").tag(1)
                            Text("Outside").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // Effects
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Effects")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Effect")
                                Spacer()
                            }
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

struct GridBackgroundView: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 10
            let majorGridInterval = 5 // Every 5 lines is a major line
            
            for x in stride(from: 0, through: size.width, by: gridSize) {
                let isMajorLine = Int(x / gridSize) % majorGridInterval == 0
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajorLine ? .gray.opacity(0.2) : .gray.opacity(0.1)),
                    lineWidth: isMajorLine ? 1.0 : 0.5
                )
            }
            
            for y in stride(from: 0, through: size.height, by: gridSize) {
                let isMajorLine = Int(y / gridSize) % majorGridInterval == 0
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(isMajorLine ? .gray.opacity(0.2) : .gray.opacity(0.1)),
                    lineWidth: isMajorLine ? 1.0 : 0.5
                )
            }
        }
    }
}

struct CanvasContentView: View {
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    @Binding var selectedProperty: String?
    @Binding var showAnimationPreview: Bool
    let keyframes: [(String, Double, Double)]
    
    var body: some View {
        ZStack {
            // Video preview area
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black)
                .frame(minWidth: 640, minHeight: 360) // Minimum size instead of fixed size
                .shadow(radius: 20)
            
            // Sample content (video frame placeholder)
            if showAnimationPreview {
                AnimationPreviewView(
                    currentTime: currentTime,
                    keyframes: keyframes,
                    selectedProperty: selectedProperty
                )
            } else {
            VStack(spacing: 20) {
                    Text("Video Preview")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Image(systemName: "play.rectangle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space
    }
}

struct AnimationPreviewView: View {
    let currentTime: Double
    let keyframes: [(String, Double, Double)]
    let selectedProperty: String?
    
    // Get the current values for properties at the current time
    private var positionX: CGFloat {
        getPropertyValue(for: "Position X")
    }
    
    private var positionY: CGFloat {
        getPropertyValue(for: "Position Y")
    }
    
    private var scale: CGFloat {
        max(0.1, getPropertyValue(for: "Scale") / 100)
    }
    
    private var rotation: Double {
        getPropertyValue(for: "Rotation")
    }
    
    private var opacity: Double {
        getPropertyValue(for: "Opacity") / Double(100)
    }
    
    var body: some View {
        ZStack {
            // Background grid for reference
            AnimationGridView()
            
            // Animated element
            VStack {
                Text("Animated Element")
                    .font(.headline)
                    .foregroundColor(.white)
                
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                    .frame(width: 100, height: 100)
            }
            .padding()
            .background(Color.blue.opacity(0.3))
            .cornerRadius(12)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: positionX - 200, y: positionY - 100) // Center offset
            
            // Current property values overlay
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Values:")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Position: (\(Int(positionX)), \(Int(positionY)))")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Scale: \(Int(scale * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Rotation: \(Int(rotation))°")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Opacity: \(Int(opacity * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding()
        }
    }
    
    private func getPropertyValue(for property: String) -> CGFloat {
        // Find keyframes for this property
        let propertyKeyframes = keyframes.filter { $0.0 == property }
        let sortedKeyframes = propertyKeyframes.sorted { $0.1 < $1.1 }
        
        // If no keyframes, return default value
        if sortedKeyframes.isEmpty {
            return property == "Scale" || property == "Opacity" ? 100 : 0
        }
        
        // If before first keyframe, return first keyframe value
        if currentTime <= sortedKeyframes.first!.1 {
            return CGFloat(sortedKeyframes.first!.2)
        }
        
        // If after last keyframe, return last keyframe value
        if currentTime >= sortedKeyframes.last!.1 {
            return CGFloat(sortedKeyframes.last!.2)
        }
        
        // Find keyframes before and after current time
        var beforeKeyframe: (String, Double, Double)?
        var afterKeyframe: (String, Double, Double)?
        
        for keyframe in sortedKeyframes {
            if keyframe.1 <= currentTime {
                beforeKeyframe = keyframe
            } else {
                afterKeyframe = keyframe
                break
            }
        }
        
        guard let before = beforeKeyframe, let after = afterKeyframe else {
            return CGFloat(sortedKeyframes.first!.2)
        }
        
        // Linear interpolation between keyframes
        let t = (currentTime - before.1) / (after.1 - before.1)
        return CGFloat(before.2 + t * (after.2 - before.2))
    }
}

struct AnimationGridView: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 50
            let majorGridInterval = 4 // Every 4 lines is a major line
            
            for x in stride(from: 0, through: size.width, by: gridSize) {
                let isMajorLine = Int(x / gridSize) % majorGridInterval == 0
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(isMajorLine ? .gray.opacity(0.3) : .gray.opacity(0.1)),
                    lineWidth: isMajorLine ? 1.0 : 0.5
                )
            }
            
            for y in stride(from: 0, through: size.height, by: gridSize) {
                let isMajorLine = Int(y / gridSize) % majorGridInterval == 0
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(isMajorLine ? .gray.opacity(0.3) : .gray.opacity(0.1)),
                    lineWidth: isMajorLine ? 1.0 : 0.5
                )
            }
            
            // Draw center lines
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                },
                with: .color(.white.opacity(0.4)),
                lineWidth: 1.0
            )
            
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                },
                with: .color(.white.opacity(0.4)),
                lineWidth: 1.0
            )
        }
    }
}

struct VideoPlaybackControls: View {
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    let totalDuration: Double
    
    var body: some View {
        HStack(spacing: 16) {
            // Time display
            Text(formatTime(currentTime))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Playback controls
            HStack(spacing: 12) {
                Button(action: { currentTime = max(0, currentTime - 5) }) {
                    Image(systemName: "backward.fill")
                }
                .buttonStyle(.plain)
                
                Button(action: { currentTime = max(0, currentTime - 1/30) }) {
                    Image(systemName: "backward.frame.fill")
                }
                .buttonStyle(.plain)
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button(action: { currentTime = min(totalDuration, currentTime + 1/30) }) {
                    Image(systemName: "forward.frame.fill")
                }
                .buttonStyle(.plain)
                
                Button(action: { currentTime = min(totalDuration, currentTime + 5) }) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.plain)
            }
            
            // Scrubber/timeline
            Slider(value: $currentTime, in: 0...totalDuration)
                .frame(maxWidth: .infinity)
            
            // Total duration
            Text(formatTime(totalDuration))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let wholeSeconds = Double(Int(seconds))
        let fraction = seconds - wholeSeconds
        let frames = Int(fraction * 30)
        return String(format: "%02d:%02d:%02d", minutes, secs, frames)
    }
}

struct VideoTimelinePanel: View {
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    let totalDuration: Double
    @Binding var timelineZoom: CGFloat
    @Binding var selectedClip: String?
    var showKeyframeEditor: Bool
    @Binding var selectedProperty: String?
    @Binding var showAnimationProperties: Bool
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    // Sample video tracks and clips
    let tracks = ["Video 1", "Video 2", "Audio 1", "Audio 2", "Effects"]
    
    // Sample clips (trackIndex, startTime, duration, name, color)
    let clips: [(Int, Double, Double, String, Color)] = [
        (0, 0, 10, "Intro", .blue),
        (0, 12, 8, "Scene 1", .green),
        (0, 22, 15, "Scene 2", .orange),
        (1, 5, 12, "Overlay", .purple),
        (2, 0, 30, "Background Music", .red),
        (3, 8, 5, "Voice Over", .pink),
        (4, 15, 3, "Transition", .yellow)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline header
            timelineHeader
            
            // Timeline ruler
            timelineRuler
            
            HStack(spacing: 0) {
                // Left panel - Properties and keyframes
                if showAnimationProperties {
                    animationPropertiesPanel
                        .frame(width: 240)
                        .background(Color(NSColor.controlBackgroundColor))
                        .border(Color.gray.opacity(0.3), width: 0.5)
                }
                
                // Timeline tracks
                timelineTracks
            }
        }
    }
    
    // MARK: - Component Views
    
    private var timelineHeader: some View {
        HStack {
            Text("Timeline")
                .font(.headline)
            
            Spacer()
            
            // Animation controls
            HStack(spacing: 12) {
                Button(action: { showAnimationProperties.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(showAnimationProperties ? .blue : .primary)
                }
                .buttonStyle(.plain)
                .help("Toggle Animation Properties")
                
                Button(action: { addKeyframeAtCurrentTime() }) {
                    Image(systemName: "diamond")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Add Keyframe")
                
                Button(action: { toggleKeyframeEditor() }) {
                    Image(systemName: "cursorarrow.motionlines")
                        .foregroundColor(showKeyframeEditor ? .blue : .primary)
                }
                .buttonStyle(.plain)
                .help("Keyframe Editor")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            
            Spacer()
            
            // Zoom controls
            zoomControls
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var zoomControls: some View {
        HStack {
            Button(action: { timelineZoom = max(0.5, timelineZoom - 0.25) }) {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            
            Text("\(Int(timelineZoom * 100))%")
                .frame(width: 50)
            
            Button(action: { timelineZoom = min(4, timelineZoom + 0.25) }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var timelineRuler: some View {
        TimelineRulerView(
            currentTime: $currentTime,
            totalDuration: totalDuration,
            zoom: timelineZoom,
            keyframes: keyframes,
            showKeyframes: showKeyframeEditor
        )
        .frame(height: 24)
        .background(Color(NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)))
    }
    
    private var timelineTracks: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(tracks.indices, id: \.self) { trackIndex in
                    createTrackView(for: trackIndex)
                }
            }
        }
    }
    
    private var animationPropertiesPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Properties")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .background(Color(NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)))
            
            Divider()
            
            // Properties list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Transform properties
                    PropertyGroupView(
                        title: "Transform",
                        properties: ["Position X", "Position Y", "Scale", "Rotation", "Opacity"],
                        selectedProperty: $selectedProperty,
                        currentTime: currentTime,
                        keyframes: keyframes,
                        onKeyframeSelected: onKeyframeSelected
                    )
                    
                    Divider()
                    
                    // Effects properties
                    PropertyGroupView(
                        title: "Effects",
                        properties: ["Blur", "Brightness", "Contrast", "Saturation"],
                        selectedProperty: $selectedProperty,
                        currentTime: currentTime,
                        keyframes: keyframes,
                        onKeyframeSelected: onKeyframeSelected
                    )
                    
                    Divider()
                    
                    // Text properties (if applicable)
                    PropertyGroupView(
                        title: "Text",
                        properties: ["Font Size", "Tracking", "Leading", "Color"],
                        selectedProperty: $selectedProperty,
                        currentTime: currentTime,
                        keyframes: keyframes,
                        onKeyframeSelected: onKeyframeSelected
                    )
                }
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTrackView(for trackIndex: Int) -> some View {
        let trackClips = clips.filter { $0.0 == trackIndex }
        
        return TimelineTrackView(
            trackName: tracks[trackIndex],
            trackIndex: trackIndex,
            clips: trackClips,
            currentTime: $currentTime,
            totalDuration: totalDuration,
            zoom: timelineZoom,
            selectedClip: $selectedClip,
            showKeyframeEditor: showKeyframeEditor,
            keyframes: keyframes
        )
    }
    
    private func addKeyframeAtCurrentTime() {
        // In a real app, this would add a keyframe for the selected property at the current time
        print("Adding keyframe at time: \(currentTime)")
    }
    
    private func toggleKeyframeEditor() {
        // This would toggle the keyframe editor visibility
        // In a real app, this might also select the first keyframe near the current time
        if let property = selectedProperty {
            let nearbyKeyframes = keyframes.filter { 
                $0.0 == property && abs($0.1 - currentTime) < 0.5
            }.sorted { abs($0.1 - currentTime) < abs($1.1 - currentTime) }
            
            if let firstKeyframe = nearbyKeyframes.first {
                onKeyframeSelected(firstKeyframe)
            }
        }
    }
}

struct PropertyGroupView: View {
    let title: String
    let properties: [String]
    @Binding var selectedProperty: String?
    let currentTime: Double
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                    
                    Text(title)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Properties
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(properties, id: \.self) { property in
                        PropertyRowView(
                            name: property,
                            isSelected: selectedProperty == property,
                            currentTime: currentTime,
                            keyframes: keyframes.filter { $0.0 == property },
                            onSelect: {
                                selectedProperty = property
                            },
                            onKeyframeSelected: onKeyframeSelected
                        )
                    }
                }
            }
        }
    }
}

struct PropertyRowView: View {
    let name: String
    let isSelected: Bool
    let currentTime: Double
    let keyframes: [(String, Double, Double)]
    let onSelect: () -> Void
    let onKeyframeSelected: ((String, Double, Double)) -> Void
    
    // Get the current value for this property at the current time
    private var currentValue: Double {
        // Find keyframes before and after current time
        let sortedKeyframes = keyframes.sorted { $0.1 < $1.1 }
        
        // If no keyframes, return default value
        if sortedKeyframes.isEmpty {
            return 0
        }
        
        // If before first keyframe, return first keyframe value
        if currentTime <= sortedKeyframes.first!.1 {
            return sortedKeyframes.first!.2
        }
        
        // If after last keyframe, return last keyframe value
        if currentTime >= sortedKeyframes.last!.1 {
            return sortedKeyframes.last!.2
        }
        
        // Find keyframes before and after current time
        var beforeKeyframe: (String, Double, Double)?
        var afterKeyframe: (String, Double, Double)?
        
        for keyframe in sortedKeyframes {
            if keyframe.1 <= currentTime {
                beforeKeyframe = keyframe
            } else {
                afterKeyframe = keyframe
                break
            }
        }
        
        guard let before = beforeKeyframe, let after = afterKeyframe else {
            return sortedKeyframes.first!.2
        }
        
        // Linear interpolation between keyframes
        let t = (currentTime - before.1) / (after.1 - before.1)
        return before.2 + t * (after.2 - before.2)
    }
    
    var body: some View {
        HStack {
            // Property name
            Button(action: onSelect) {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            // Current value
            Text("\(Int(currentValue))")
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 40, alignment: .trailing)
            
            // Keyframe indicator/button
            Button(action: {
                if hasKeyframeAtCurrentTime, let keyframe = keyframeAtCurrentTime {
                    onKeyframeSelected(keyframe)
                }
            }) {
                if hasKeyframeAtCurrentTime {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "diamond")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasKeyframeAtCurrentTime)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    private var hasKeyframeAtCurrentTime: Bool {
        keyframes.contains { abs($0.1 - currentTime) < 0.1 }
    }
    
    private var keyframeAtCurrentTime: (String, Double, Double)? {
        keyframes.first { abs($0.1 - currentTime) < 0.1 }
    }
}

struct TimelineRulerView: View {
    @Binding var currentTime: Double
    let totalDuration: Double
    let zoom: CGFloat
    let keyframes: [(String, Double, Double)]
    var showKeyframes: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            rulerContent(width: geometry.size.width)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCurrentTime(at: value.location.x, width: geometry.size.width)
                        }
                )
        }
    }
    
    private func rulerContent(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Background
            rulerBackground
            
            // Time markers
            timeMarkers(width: width)
            
            // Time labels
            timeLabels(width: width)
            
            // Keyframes (if enabled)
            if showKeyframes {
                keyframeMarkers(width: width)
            }
            
            // Current time indicator
            currentTimeIndicator(width: width)
        }
    }
    
    private var rulerBackground: some View {
        Rectangle()
            .fill(Color(NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)))
    }
    
    private func timeMarkers(width: CGFloat) -> some View {
        let pps = pixelsPerSecond(width)
        let secondsRange = Array(0...Int(totalDuration))
        return ZStack {
            ForEach(secondsRange, id: \.self) { second in
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1)
                    .offset(x: CGFloat(second) * pps)
            }
        }
    }
    
    private func timeLabels(width: CGFloat) -> some View {
        let pps = pixelsPerSecond(width)
        let labelSeconds = Array(stride(from: 0, through: Int(totalDuration), by: 5))
        return ZStack {
            ForEach(labelSeconds, id: \.self) { second in
                Text("\(second)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .offset(x: labelOffset(for: second, pps: pps))
            }
        }
    }
    
    private func keyframeMarkers(width: CGFloat) -> some View {
        let pps = pixelsPerSecond(width)
        let uniqueKeyframeTimes = Set(keyframes.map { $0.1 }).sorted()
        
        return ZStack {
            ForEach(uniqueKeyframeTimes, id: \.self) { time in
                Image(systemName: "diamond.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                    .offset(x: CGFloat(time) * pps - 4, y: 4)
            }
        }
    }
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        let pps = pixelsPerSecond(width)
        return Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .offset(x: CGFloat(currentTime) * pps)
    }
    
    private func updateCurrentTime(at xPosition: CGFloat, width: CGFloat) {
        let newTime = Double(xPosition) / Double(width) * (totalDuration)
        currentTime = max(0, min(totalDuration, newTime))
    }
    
    private func pixelsPerSecond(_ width: CGFloat) -> CGFloat {
        return width * zoom / CGFloat(totalDuration)
    }
    
    private func labelOffset(for second: Int, pps: CGFloat) -> CGFloat {
        return CGFloat(second) * pps - 5
    }
}

struct TimelineTrackView: View {
    let trackName: String
    let trackIndex: Int
    let clips: [(Int, Double, Double, String, Color)]
    @Binding var currentTime: Double
    let totalDuration: Double
    let zoom: CGFloat
    @Binding var selectedClip: String?
    let showKeyframeEditor: Bool
    let keyframes: [(String, Double, Double)]
    
    var body: some View {
        HStack(spacing: 0) {
            // Track label
            Text(trackName)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
            
            // Track content
            GeometryReader { geometry in
                TrackContentView(
                    clips: clips,
                    currentTime: $currentTime,
                    selectedClip: $selectedClip,
                    totalDuration: totalDuration,
                    zoom: zoom,
                    geometryWidth: geometry.size.width,
                    showKeyframeEditor: showKeyframeEditor,
                    keyframes: keyframes
                )
            }
        }
        .frame(height: 30)
        .border(Color.gray.opacity(0.3), width: 0.5)
    }
    
    private func pixelsPerSecond(_ width: CGFloat) -> CGFloat {
        return width * zoom / CGFloat(totalDuration)
    }
}

struct TrackContentView: View {
    let clips: [(Int, Double, Double, String, Color)]
    @Binding var currentTime: Double
    @Binding var selectedClip: String?
    let totalDuration: Double
    let zoom: CGFloat
    let geometryWidth: CGFloat
    let showKeyframeEditor: Bool
    let keyframes: [(String, Double, Double)]
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            Rectangle()
                .fill(Color(NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)))
            
            // Clips
            ForEach(clips.indices, id: \.self) { index in
                clipView(for: index)
            }
            
            // Keyframe markers (if enabled)
            if showKeyframeEditor {
                keyframeMarkers
            }
            
            // Current time indicator
            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
                .offset(x: CGFloat(currentTime) * pixelsPerSecond())
        }
    }
    
    private var keyframeMarkers: some View {
        let uniqueKeyframeTimes = Set(keyframes.map { $0.1 }).sorted()
        
        return ZStack {
            ForEach(uniqueKeyframeTimes, id: \.self) { time in
                Rectangle()
                    .fill(Color.yellow.opacity(0.5))
                    .frame(width: 1)
                    .offset(x: CGFloat(time) * pixelsPerSecond())
            }
        }
    }
    
    private func clipView(for index: Int) -> some View {
        let clip = clips[index]
        let startPos = CGFloat(clip.1) * pixelsPerSecond()
        let clipWidth = CGFloat(clip.2) * pixelsPerSecond()
        
        return TimelineClipView(
            name: clip.3,
            color: clip.4,
            isSelected: selectedClip == clip.3,
            startPosition: startPos,
            width: clipWidth
        )
        .onTapGesture {
            selectedClip = clip.3
        }
    }
    
    private func pixelsPerSecond() -> CGFloat {
        return geometryWidth * zoom / CGFloat(totalDuration)
    }
}

struct TimelineClipView: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let startPosition: CGFloat
    let width: CGFloat
    
    var body: some View {
        Text(name)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .frame(width: max(30, width), height: 24)
            .background(color.opacity(0.7))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .offset(x: startPosition)
    }
}

enum EasingType: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In Out"
    case bounce = "Bounce"
    case elastic = "Elastic"
    
    var id: String { self.rawValue }
    
    func apply(to progress: Double) -> Double {
        switch self {
        case .linear:
            return progress
        case .easeIn:
            return progress * progress
        case .easeOut:
            return 1 - (1 - progress) * (1 - progress)
        case .easeInOut:
            return progress < 0.5 ?
                2 * progress * progress :
                1 - pow(-2 * progress + 2, 2) / 2
        case .bounce:
            if progress < 0.36363636 {
                return 7.5625 * progress * progress
            } else if progress < 0.72727272 {
                let t = progress - 0.54545454
                return 7.5625 * t * t + 0.75
            } else if progress < 0.90909090 {
                let t = progress - 0.81818181
                return 7.5625 * t * t + 0.9375
            } else {
                let t = progress - 0.95454545
                return 7.5625 * t * t + 0.984375
            }
        case .elastic:
            let c4 = (2 * Double.pi) / 3
            return progress == 0 ? 0 :
                   progress == 1 ? 1 :
                   -pow(2, 10 * progress - 10) * sin((progress * 10 - 10.75) * c4)
        }
    }
}

struct KeyframeEditorView: View {
    let keyframe: (String, Double, Double)
    @Binding var easing: EasingType
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Keyframe Editor")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Keyframe info
            Group {
                Text("Property: \(keyframe.0)")
                    .font(.subheadline)
                
                Text("Time: \(String(format: "%.2f", keyframe.1))s")
                    .font(.subheadline)
                
                Text("Value: \(String(format: "%.2f", keyframe.2))")
                    .font(.subheadline)
            }
            
            Divider()
            
            // Easing selection
            Text("Easing:")
                .font(.subheadline)
            
            Picker("", selection: $easing) {
                ForEach(EasingType.allCases) { easingType in
                    Text(easingType.rawValue).tag(easingType)
                }
            }
            .pickerStyle(.menu)
            
            // Easing preview
            EasingPreviewView(easing: easing)
                .frame(height: 40)
                .padding(.top, 8)
        }
        .padding()
    }
}

struct EasingPreviewView: View {
    let easing: EasingType
    
    var body: some View {
        Canvas { context, size in
            // Draw grid
            for x in stride(from: 0, through: size.width, by: size.width / 4) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
            
            for y in stride(from: 0, through: size.height, by: size.height / 4) {
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
            
            // Draw easing curve
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height))
            
            for x in stride(from: 0, through: size.width, by: 1) {
                let progress = x / size.width
                let easedValue = easing.apply(to: Double(progress))
                let y = size.height - CGFloat(easedValue) * size.height
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            context.stroke(
                path,
                with: .color(.blue),
                lineWidth: 2
            )
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(4)
    }
}

struct EasingControlsView: View {
    @Binding var selectedEasing: EasingType
    @Binding var selectedProperty: String?
    @Binding var currentTime: Double
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Animation Controls")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Spacer()
            }
            .background(Color(NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)))
            
            Divider()
            
            // Curve editor
            AnimationCurveEditor(
                selectedProperty: $selectedProperty,
                currentTime: $currentTime,
                keyframes: keyframes,
                onKeyframeSelected: onKeyframeSelected
            )
            .frame(height: 200)
            
            Divider()
            
            // Easing type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Selected Property:")
                    .font(.subheadline)
                
                Text(selectedProperty ?? "None")
                    .font(.body)
                    .foregroundColor(selectedProperty == nil ? .secondary : .primary)
                
                Divider()
                
                Text("Easing Type:")
                    .font(.subheadline)
                
                Picker("", selection: $selectedEasing) {
                    ForEach(EasingType.allCases) { easingType in
                        Text(easingType.rawValue).tag(easingType)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Divider()
                
                Text("Preview:")
                    .font(.subheadline)
                
                EasingPreviewView(easing: selectedEasing)
                    .frame(height: 100)
                    .padding(.bottom, 8)
            }
            .padding()
            
            Spacer()
        }
    }
}

struct AnimationCurveEditor: View {
    @Binding var selectedProperty: String?
    @Binding var currentTime: Double
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Animation Curves")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                Spacer()
            }
            .background(Color(NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)))
            
            Divider()
            
            // Curve editor
            if let property = selectedProperty {
                CurveEditorView(
                    property: property,
                    currentTime: $currentTime,
                    keyframes: keyframes.filter { $0.0 == property },
                    onKeyframeSelected: onKeyframeSelected
                )
                .padding()
            } else {
                VStack {
                    Spacer()
                    Text("Select a property to view animation curves")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct CurveEditorView: View {
    let property: String
    @Binding var currentTime: Double
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    // Find the min and max values for the property
    private var minValue: Double {
        keyframes.map { $0.2 }.min() ?? 0
    }
    
    private var maxValue: Double {
        keyframes.map { $0.2 }.max() ?? 100
    }
    
    // Find the min and max times
    private var minTime: Double {
        keyframes.map { $0.1 }.min() ?? 0
    }
    
    private var maxTime: Double {
        keyframes.map { $0.1 }.max() ?? 30
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(property)
                .font(.headline)
            
            GeometryReader { geometry in
                ZStack {
                    // Background grid
                    curveEditorGrid(size: geometry.size)
                    
                    // Animation curve
                    animationCurve(size: geometry.size)
                    
                    // Keyframe points
                    keyframePoints(size: geometry.size)
                    
                    // Current time indicator
                    currentTimeIndicator(size: geometry.size)
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCurrentTime(at: value.location.x, width: geometry.size.width)
                        }
                )
            }
        }
    }
    
    private func curveEditorGrid(size: CGSize) -> some View {
        Canvas { context, size in
            // Draw horizontal grid lines
            let valueRange = maxValue - minValue
            let valueStep = valueRange > 0 ? valueRange / 4 : 25
            
            for value in stride(from: minValue, through: maxValue + valueStep, by: valueStep) {
                let y = size.height - (value - minValue) / (maxValue - minValue) * size.height
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
            
            // Draw vertical grid lines
            let timeRange = maxTime - minTime
            let timeStep = timeRange > 0 ? timeRange / 8 : 5
            
            for time in stride(from: minTime, through: maxTime + timeStep, by: timeStep) {
                let x = (time - minTime) / (maxTime - minTime) * size.width
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    private func animationCurve(size: CGSize) -> some View {
        let sortedKeyframes = keyframes.sorted { $0.1 < $1.1 }
        
        return Canvas { context, size in
            guard sortedKeyframes.count >= 2 else { return }
            
            var path = Path()
            
            // Start at the first keyframe
            let firstKeyframe = sortedKeyframes.first!
            let startX = (firstKeyframe.1 - minTime) / (maxTime - minTime) * size.width
            let startY = size.height - (firstKeyframe.2 - minValue) / (maxValue - minValue) * size.height
            path.move(to: CGPoint(x: startX, y: startY))
            
            // Draw lines between keyframes
            for i in 1..<sortedKeyframes.count {
                let keyframe = sortedKeyframes[i]
                let x = (keyframe.1 - minTime) / (maxTime - minTime) * size.width
                let y = size.height - (keyframe.2 - minValue) / (maxValue - minValue) * size.height
                
                // For a more realistic curve, we could use bezier curves here
                // For now, just use straight lines
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            context.stroke(
                path,
                with: .color(.blue),
                lineWidth: 2
            )
        }
    }
    
    private func keyframePoints(size: CGSize) -> some View {
        ForEach(keyframes, id: \.1) { keyframe in
            let x = (keyframe.1 - minTime) / (maxTime - minTime) * size.width
            let y = size.height - (keyframe.2 - minValue) / (maxValue - minValue) * size.height
            
            Circle()
                .fill(Color.yellow)
                .frame(width: 8, height: 8)
                .position(x: x, y: y)
                .onTapGesture {
                    onKeyframeSelected(keyframe)
                }
        }
    }
    
    private func currentTimeIndicator(size: CGSize) -> some View {
        let x = (currentTime - minTime) / (maxTime - minTime) * size.width
        
        return Rectangle()
            .fill(Color.red)
            .frame(width: 1)
            .frame(height: size.height)
            .position(x: x, y: size.height / 2)
    }
    
    private func updateCurrentTime(at xPosition: CGFloat, width: CGFloat) {
        let newTime = minTime + Double(xPosition) / Double(width) * (maxTime - minTime)
        currentTime = max(minTime, min(maxTime, newTime))
    }
}

#Preview {
    DesignCanvas(
        project: Project(name: "Video Project", thumbnail: "", lastModified: Date()),
        onClose: {},
        onCreateNewProject: nil
    )
} 
