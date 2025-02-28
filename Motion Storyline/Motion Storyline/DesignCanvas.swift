import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// Import the refactored components
import Foundation
// No need to import SwiftUI again as it's already imported above

// Define ExportFormat at the top level so it's accessible to all structs
enum ExportFormat {
    case video
    case gif
    case imageSequence
    case projectFile
}

// Add this class outside the DesignCanvas struct
class AnimationController: ObservableObject {
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 5.0
    
    private var timer: Timer?
    private var lastUpdateTime: Date?
    
    func setup(duration: Double) {
        self.duration = duration
        self.currentTime = 0.0
    }
    
    func play() {
        // Stop any existing timer
        timer?.invalidate()
        
        // Record the current time for accurate timing
        lastUpdateTime = Date()
        
        // Create a new timer that fires 60 times per second
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Calculate elapsed time since last update
            let now = Date()
            if let lastUpdate = self.lastUpdateTime {
                let elapsed = now.timeIntervalSince(lastUpdate)
                self.lastUpdateTime = now
                
                // Update the current time
                self.currentTime += elapsed
                
                // Loop back to the beginning if we reach the end
                if self.currentTime >= self.duration {
                    self.currentTime = 0.0
                }
            }
        }
    }
    
    func pause() {
        timer?.invalidate()
        timer = nil
        lastUpdateTime = nil
    }
    
    func reset() {
        pause()
        currentTime = 0.0
    }
    
    deinit {
        timer?.invalidate()
    }
}

// Remove the CanvasElement struct since it's now in its own file

enum ElementType: String {
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case text = "Text"
    case image = "Image"
    case video = "Video"
}

struct DesignCanvas: View {
    @State private var zoom: CGFloat = 1.0
    @State private var canvasElements: [CanvasElement] = [
        CanvasElement(
            type: .rectangle,
            position: CGPoint(x: 300, y: 200),
            size: CGSize(width: 200, height: 150),
            color: .blue,
            displayName: "Blue Rectangle"
        ),
        CanvasElement(
            type: .ellipse,
            position: CGPoint(x: 500, y: 300),
            size: CGSize(width: 120, height: 120),
            color: .green,
            displayName: "Red Circle"
        ),
        CanvasElement(
            type: .text,
            position: CGPoint(x: 400, y: 100),
            size: CGSize(width: 300, height: 50),
            color: .black,
            text: "Title Text",
            displayName: "Title Text"
        )
    ]
    @State private var selectedElement: CanvasElement?
    @State private var selectedTool: DesignTool = .select
    @State private var isInspectorVisible = true
    @State private var isEditingText = false
    
    // Navigation state
    @Environment(\.presentationMode) private var presentationMode
    
    // Animation controller
    @StateObject private var animationController = AnimationController()
    @State private var isPlaying = false
    @State private var selectedProperty: String?
    @State private var showAnimationPreview = true
    
    // Camera recording state
    @State private var isRecording = false
    @State private var showCameraView = false
    
    // Sample keyframes for demonstration
    let keyframes: [(String, Double, Double)] = [
        ("opacity", 0.0, 0.0),
        ("opacity", 1.0, 0.5),
        ("opacity", 0.0, 1.0),
        ("scale", 1.0, 0.0),
        ("scale", 1.5, 0.5),
        ("scale", 1.0, 1.0)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Add TopBar at the top
            CanvasTopBar(
                projectName: "Untitled Project",
                onClose: {
                    // Use presentation mode to navigate back
                    presentationMode.wrappedValue.dismiss()
                },
                onNewFile: {
                    // Handle new file action
                },
                onCameraRecord: {
                    // Show camera recording view
                    showCameraView = true
                },
                isPlaying: $isPlaying,
                showAnimationPreview: $showAnimationPreview,
                onExport: { format in
                    // Handle export action
                },
                onAccountSettings: {
                    // Handle account settings action
                },
                onPreferences: {
                    // Handle preferences action
                },
                onHelpAndSupport: {
                    // Handle help and support action
                },
                onCheckForUpdates: {
                    // Handle check for updates action
                },
                onSignOut: {
                    // Handle sign out action
                }
            )
            
            NavigationSplitView {
                // Sidebar with timeline
                TimelineView(
                    currentTime: $animationController.currentTime,
                    duration: animationController.duration,
                    isPlaying: $isPlaying,
                    keyframes: keyframes,
                    selectedProperty: $selectedProperty,
                    onAddKeyframe: { property, time, value in
                        // Add keyframe logic
                        print("Add keyframe: \(property) at \(time) with value \(value)")
                    }
                )
                .frame(minHeight: 200)
            } content: {
                // Main content area with canvas
                VStack(spacing: 0) {
                    // Toolbar
                    DesignToolbar(selectedTool: $selectedTool)
                    
                    // Canvas with zoom controls
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView([.horizontal, .vertical]) {
                            ZStack {
                                // Canvas content
                                CanvasContentView(
                                    elements: $canvasElements,
                                    selectedElementId: Binding(
                                        get: { selectedElement?.id },
                                        set: { newId in
                                            if let newId = newId {
                                                selectedElement = canvasElements.first(where: { $0.id == newId })
                                                // Ensure inspector is visible when an element is selected
                                                if !isInspectorVisible {
                                                    isInspectorVisible = true
                                                }
                                            } else {
                                                selectedElement = nil
                                            }
                                        }
                                    ),
                                    isEditingText: $isEditingText,
                                    selectedTool: selectedTool
                                )
                                .scaleEffect(zoom)
                                .frame(width: 1200, height: 800)
                                .padding(100)
                            }
                        }
                        
                        // Zoom controls
                        VStack {
                            Button(action: {
                                zoom = min(zoom + 0.1, 3.0)
                            }) {
                                Image(systemName: "plus.magnifyingglass")
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                            
                            Text("\(Int(zoom * 100))%")
                                .font(.caption)
                                .padding(.vertical, 4)
                            
                            Button(action: {
                                zoom = max(zoom - 0.1, 0.5)
                            }) {
                                Image(systemName: "minus.magnifyingglass")
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                            
                            Button(action: {
                                zoom = 1.0
                            }) {
                                Image(systemName: "1.magnifyingglass")
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                        }
                        .padding()
                    }
                }
                .frame(minWidth: 900, idealWidth: 900)
            } detail: {
                // Inspector panel
                Group {
                    if isInspectorVisible {
                        InspectorView(
                            selectedElement: $selectedElement,
                            onClose: {
                                isInspectorVisible = false
                            }
                        )
                    } else {
                        Button(action: {
                            isInspectorVisible = true
                        }) {
                            Image(systemName: "sidebar.right")
                                .font(.title)
                                .padding()
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationSplitViewStyle(.automatic)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        animationController.play()
                    } else {
                        animationController.pause()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    animationController.reset()
                    isPlaying = false
                }) {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showAnimationPreview.toggle()
                }) {
                    Image(systemName: showAnimationPreview ? "eye.fill" : "eye.slash.fill")
                }
            }
        }
        .onAppear {
            animationController.setup(duration: 5.0)
        }
        .sheet(isPresented: $showCameraView) {
            CameraRecordingView(isPresented: $showCameraView)
        }
        .onKeyPress(KeyEquivalent("a")) {
            // Command modifier check
            guard NSEvent.modifierFlags.contains(.command) else { return .ignored }
            
            // Select all elements (in this case, just select the first element)
            if !isEditingText && selectedTool == .select && !canvasElements.isEmpty {
                selectedElement = canvasElements.first
                return .handled
            }
            return .ignored
        }
        // Tool selection shortcuts
        .onKeyPress(KeyEquivalent("v")) {
            if !isEditingText {
                selectedTool = .select
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("r")) {
            if !isEditingText {
                selectedTool = .rectangle
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("e")) {
            if !isEditingText {
                selectedTool = .ellipse
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("t")) {
            if !isEditingText {
                selectedTool = .text
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("p")) {
            if !isEditingText {
                selectedTool = .pen
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("h")) {
            if !isEditingText {
                selectedTool = .hand
                return .handled
            }
            return .ignored
        }
    }
    
    // Add a new element to the canvas
    func addElement(_ element: CanvasElement) {
        canvasElements.append(element)
        selectedElement = element
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

struct CanvasContentView: View {
    @Binding var elements: [CanvasElement]
    @Binding var selectedElementId: UUID?
    @Binding var isEditingText: Bool
    let selectedTool: DesignTool
    
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint?
    @State private var drawStartPosition: CGPoint?
    @State private var isDrawing = false
    @State private var temporaryElement: CanvasElement?
    @State private var drawingMode: DrawingMode = .inactive
    @State private var currentMousePosition: CGPoint?
    @State private var editingText = ""
    
    enum DrawingMode {
        case inactive
        case firstPointSet
        case drawing
    }
    
    var body: some View {
        ZStack {
            // Grid background
            GridBackground()
            
            // Canvas elements
            ForEach(elements) { element in
                CanvasElementView(
                    element: element,
                    isSelected: element.id == selectedElementId,
                    onResize: { newSize in
                        if let index = elements.firstIndex(where: { $0.id == element.id }) {
                            elements[index].size = newSize
                        }
                    }
                )
                .onTapGesture {
                    if selectedTool == .select {
                        selectedElementId = element.id
                        
                        // If the selected element is a text element, start editing
                        if element.type == .text {
                            isEditingText = true
                            editingText = element.text
                        } else {
                            isEditingText = false
                        }
                    }
                }
                .onHover { isHovering in
                    if selectedTool == .select {
                        // Change cursor to indicate the element is selectable/movable
                        if isHovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
                .gesture(
                    selectedTool == .select && element.id == selectedElementId ?
                    DragGesture()
                        .onChanged { value in
                            if dragStartPosition == nil {
                                // Store the initial position when drag starts
                                dragStartPosition = findElementById(element.id)?.position
                            }
                            
                            // Calculate new position
                            if let startPos = dragStartPosition {
                                let newPosition = CGPoint(
                                    x: startPos.x + value.translation.width,
                                    y: startPos.y + value.translation.height
                                )
                                
                                // Update the element's position
                                updateElementPosition(element.id, newPosition)
                            }
                        }
                        .onEnded { _ in
                            // Reset drag state
                            dragStartPosition = nil
                        } : nil
                )
            }
            
            // Drawing guide lines
            if drawingMode == .firstPointSet, let startPos = drawStartPosition, let mousePos = currentMousePosition {
                DrawingGuideView(startPoint: startPos, currentPoint: mousePos, tool: selectedTool)
            }
            
            // Temporary element during drawing
            if let tempElement = temporaryElement {
                CanvasElementView(
                    element: tempElement,
                    isSelected: false,
                    onResize: { newSize in
                        if var element = temporaryElement {
                            element.size = newSize
                            temporaryElement = element
                        }
                    },
                    isTemporary: true
                )
            }
            
            // Drawing area for new elements
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // If we're editing text, finish editing
                    if isEditingText {
                        if let elementId = selectedElementId, let index = elements.firstIndex(where: { $0.id == elementId }) {
                            elements[index].text = editingText
                            elements[index].displayName = editingText.isEmpty ? "Text" : editingText
                        }
                        isEditingText = false
                    } else {
                        handleTap(at: location)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrag(value: value)
                        }
                        .onEnded { value in
                            handleDragEnd(value: value)
                        }
                )
                .onHover { isHovering in
                    if !isHovering {
                        currentMousePosition = nil
                    } else if selectedTool == .select {
                        // Change cursor to arrow when in selection mode
                        NSCursor.arrow.set()
                    }
                }
            
            // Mouse tracking view for real-time preview
            MousePositionView { location in
                currentMousePosition = location
                updatePreviewIfNeeded(at: location)
            }
            .allowsHitTesting(false) // Make sure it doesn't interfere with other interactions
            
            // Status indicator for drawing mode
            if selectedTool == .rectangle || selectedTool == .ellipse {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Status text
                        Text(drawingStatusText)
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.bottom, 16)
                            .padding(.horizontal, 16)
                            .animation(.easeInOut(duration: 0.2), value: drawingMode)
                        
                        Spacer()
                    }
                }
            }
            
            // Selection status indicator
            if selectedTool == .select {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // Selection status text
                        Text(selectionStatusText)
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.bottom, 16)
                            .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                }
            }
            
            // Text editing overlay
            if isEditingText, let elementId = selectedElementId, let index = elements.firstIndex(where: { $0.id == elementId }), elements[index].type == .text {
                let element = elements[index]
                TextField("Enter text", text: $editingText, onCommit: {
                    // Update the element text when editing is done
                    if let index = elements.firstIndex(where: { $0.id == elementId }) {
                        elements[index].text = editingText
                        elements[index].displayName = editingText.isEmpty ? "Text" : editingText
                    }
                    isEditingText = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: element.size.width)
                .position(element.position)
                .background(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: element.size.width + 10, height: element.size.height + 10)
                )
                .onAppear {
                    // Set initial text value from the element
                    editingText = element.text
                }
                .keyboardShortcut(.return)
            }
        }
        // Add keyboard shortcuts for selection operations
        .onKeyPress(.delete) { [selectedElementId] in
            // Delete the selected element
            if let elementId = selectedElementId, !isEditingText {
                elements.removeAll(where: { $0.id == elementId })
                self.selectedElementId = nil
                return .handled
            }
            return .ignored
        }
        .onKeyPress(KeyEquivalent("d")) { [selectedElementId] in
            // Command modifier check
            guard NSEvent.modifierFlags.contains(.command) else { return .ignored }
            
            // Duplicate the selected element
            if let elementId = selectedElementId, 
               let elementIndex = elements.firstIndex(where: { $0.id == elementId }),
               !isEditingText {
                var newElement = elements[elementIndex]
                newElement.id = UUID() // Generate a new ID
                newElement.position = CGPoint(
                    x: newElement.position.x + 20,
                    y: newElement.position.y + 20
                )
                newElement.displayName = "Copy of \(newElement.displayName)"
                elements.append(newElement)
                self.selectedElementId = newElement.id
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow) { [selectedElementId] in
            // Move the selected element up
            if let elementId = selectedElementId, !isEditingText {
                moveSelectedElement(by: CGPoint(x: 0, y: -10))
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow) { [selectedElementId] in
            // Move the selected element down
            if let elementId = selectedElementId, !isEditingText {
                moveSelectedElement(by: CGPoint(x: 0, y: 10))
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.leftArrow) { [selectedElementId] in
            // Move the selected element left
            if let elementId = selectedElementId, !isEditingText {
                moveSelectedElement(by: CGPoint(x: -10, y: 0))
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) { [selectedElementId] in
            // Move the selected element right
            if let elementId = selectedElementId, !isEditingText {
                moveSelectedElement(by: CGPoint(x: 10, y: 0))
                return .handled
            }
            return .ignored
        }
    }
    
    // Status text based on current drawing mode
    private var drawingStatusText: String {
        switch drawingMode {
        case .inactive:
            return selectedTool == .rectangle ? 
                "Click to set the first corner of your square" :
                "Click to set the first point of your circle"
        case .firstPointSet, .drawing:
            return selectedTool == .rectangle ?
                "Move to adjust size, then click again to create the square" :
                "Move to adjust size, then click again to create the circle"
        }
    }
    
    // Status text for selection mode
    private var selectionStatusText: String {
        if let elementId = selectedElementId, let element = elements.first(where: { $0.id == elementId }) {
            let position = "Position: (\(Int(element.position.x)), \(Int(element.position.y)))"
            let size = "Size: \(Int(element.size.width)) × \(Int(element.size.height))"
            return "\(element.displayName) selected. \(position). \(size). Drag to move, use handles to resize."
        } else {
            return "Click on an element to select it. Use the inspector panel to modify properties."
        }
    }
    
    // Handle tap for the new drawing behavior
    private func handleTap(at location: CGPoint) {
        // Handle selection tool
        if selectedTool == .select {
            // Check if we tapped on any element
            let tappedElement = elements.first(where: { element in
                let elementFrame = CGRect(
                    x: element.position.x - element.size.width/2,
                    y: element.position.y - element.size.height/2,
                    width: element.size.width,
                    height: element.size.height
                )
                return elementFrame.contains(location)
            })
            
            // Update selection
            selectedElementId = tappedElement?.id
            
            // If we selected a text element, prepare for editing
            if let element = tappedElement, element.type == .text {
                isEditingText = true
                editingText = element.text
            } else {
                isEditingText = false
            }
            
            return
        }
        
        // Handle rectangle and ellipse tools
        if selectedTool == .rectangle || selectedTool == .ellipse {
            switch drawingMode {
            case .inactive:
                // First tap - set the starting point
                drawStartPosition = location
                drawingMode = .firstPointSet
                
                // Create initial temporary element
                createTemporaryElement(at: location, size: CGSize(width: 1, height: 1))
                
            case .firstPointSet, .drawing:
                // Second tap - finalize the shape
                if let startPos = drawStartPosition, let tempElement = temporaryElement {
                    // Add the finalized element to the canvas
                    elements.append(tempElement)
                    selectedElementId = tempElement.id
                    
                    // Reset drawing state
                    drawStartPosition = nil
                    temporaryElement = nil
                    drawingMode = .inactive
                }
            }
        }
        // Handle text tool
        else if selectedTool == .text {
            // Create a new text element at the tap location
            let newTextElement = CanvasElement.text(at: location)
            
            // Add the text element to the canvas
            elements.append(newTextElement)
            
            // Select the new text element
            selectedElementId = newTextElement.id
            
            // Start editing the new text element
            isEditingText = true
            editingText = newTextElement.text
        }
    }
    
    // Update preview based on mouse movement (without dragging)
    private func updatePreviewIfNeeded(at location: CGPoint) {
        guard (selectedTool == .rectangle || selectedTool == .ellipse) && drawingMode == .firstPointSet else { return }
        
        if let startPos = drawStartPosition {
            // Calculate the distance from start point to current position
            let deltaX = location.x - startPos.x
            let deltaY = location.y - startPos.y
            
            // For constrained drawing (square/circle), use the larger dimension
            let size = max(abs(deltaX), abs(deltaY))
            
            // Determine the direction to maintain the constraint
            let signX = deltaX >= 0 ? 1.0 : -1.0
            let signY = deltaY >= 0 ? 1.0 : -1.0
            
            // Calculate the constrained size and position
            let constrainedSize = CGSize(width: size, height: size)
            let position = CGPoint(
                x: startPos.x + (signX * size / 2),
                y: startPos.y + (signY * size / 2)
            )
            
            // Update the temporary element
            updateTemporaryElement(at: position, size: constrainedSize)
        }
    }
    
    // Handle drag for preview during drawing
    private func handleDrag(value: DragGesture.Value) {
        guard (selectedTool == .rectangle || selectedTool == .ellipse) && drawingMode == .firstPointSet else { return }
        
        if let startPos = drawStartPosition {
            drawingMode = .drawing
            
            // Calculate the distance from start point to current position
            let deltaX = value.location.x - startPos.x
            let deltaY = value.location.y - startPos.y
            
            // For constrained drawing (square/circle), use the larger dimension
            let size = max(abs(deltaX), abs(deltaY))
            
            // Determine the direction to maintain the constraint
            let signX = deltaX >= 0 ? 1.0 : -1.0
            let signY = deltaY >= 0 ? 1.0 : -1.0
            
            // Calculate the constrained size and position
            let constrainedSize = CGSize(width: size, height: size)
            let position = CGPoint(
                x: startPos.x + (signX * size / 2),
                y: startPos.y + (signY * size / 2)
            )
            
            // Update the temporary element
            updateTemporaryElement(at: position, size: constrainedSize)
        }
    }
    
    // Handle drag end
    private func handleDragEnd(value: DragGesture.Value) {
        // If we're in drawing mode and the user releases the drag, keep the temporary element visible
        // but don't finalize it yet - that happens on the second tap
        if drawingMode == .drawing {
            drawingMode = .firstPointSet
        }
    }
    
    // Create a temporary element during drawing
    private func createTemporaryElement(at position: CGPoint, size: CGSize) {
        if selectedTool == .rectangle {
            temporaryElement = CanvasElement.rectangle(
                at: position,
                size: size
            )
        } else if selectedTool == .ellipse {
            temporaryElement = CanvasElement.ellipse(
                at: position,
                size: size
            )
        }
        
        // Mark as temporary
        if var element = temporaryElement {
            element.displayName = "Drawing \(selectedTool)"
            element.opacity = 0.7 // Make it slightly transparent to indicate it's a preview
            temporaryElement = element
        }
    }
    
    // Update the temporary element during drawing
    private func updateTemporaryElement(at position: CGPoint, size: CGSize) {
        if var element = temporaryElement {
            element.position = position
            element.size = size
            temporaryElement = element
        } else {
            createTemporaryElement(at: position, size: size)
        }
    }
    
    // Helper function to find an element by ID
    private func findElementById(_ id: UUID) -> CanvasElement? {
        return elements.first { $0.id == id }
    }
    
    // Helper function to update an element's position
    private func updateElementPosition(_ id: UUID, _ newPosition: CGPoint) {
        if let index = elements.firstIndex(where: { $0.id == id }) {
            elements[index].position = newPosition
        }
    }
    
    // Helper function to move the selected element
    private func moveSelectedElement(by offset: CGPoint) {
        if let elementId = selectedElementId, let index = elements.firstIndex(where: { $0.id == elementId }) {
            var newElement = elements[index]
            newElement.position = CGPoint(
                x: newElement.position.x + offset.x,
                y: newElement.position.y + offset.y
            )
            elements[index] = newElement
        }
    }
}

// View for drawing guide lines during shape creation
struct DrawingGuideView: View {
    let startPoint: CGPoint
    let currentPoint: CGPoint
    let tool: DesignTool
    
    var body: some View {
        ZStack {
            // Guide lines
            Path { path in
                // Horizontal guide from start point
                path.move(to: startPoint)
                path.addLine(to: CGPoint(x: currentPoint.x, y: startPoint.y))
                
                // Vertical guide to current point
                path.move(to: CGPoint(x: currentPoint.x, y: startPoint.y))
                path.addLine(to: currentPoint)
                
                // Diagonal guide (direct line from start to current)
                path.move(to: startPoint)
                path.addLine(to: currentPoint)
            }
            .stroke(Color.blue.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            // Start point marker
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .position(startPoint)
            
            // Current point marker
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .position(currentPoint)
            
            // Size dimensions text
            let deltaX = abs(currentPoint.x - startPoint.x)
            let deltaY = abs(currentPoint.y - startPoint.y)
            let size = max(deltaX, deltaY)
            
            // Show dimension text
            Text("\(Int(size)) × \(Int(size))")
                .font(.caption)
                .padding(4)
                .background(Color.white.opacity(0.8))
                .cornerRadius(4)
                .position(
                    x: (startPoint.x + currentPoint.x) / 2,
                    y: (startPoint.y + currentPoint.y) / 2
                )
        }
    }
}

struct GridBackground: View {
    let gridSize: CGFloat = 20
    let majorGridEvery: Int = 5
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(NSColor.windowBackgroundColor)
                
                // Minor grid lines
                Path { path in
                    // Vertical lines
                    for i in 0...Int(geometry.size.width / gridSize) {
                        let x = CGFloat(i) * gridSize
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    
                    // Horizontal lines
                    for i in 0...Int(geometry.size.height / gridSize) {
                        let y = CGFloat(i) * gridSize
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                
                // Major grid lines
                Path { path in
                    // Vertical lines
                    for i in 0...Int(geometry.size.width / gridSize) {
                        if i % majorGridEvery == 0 {
                            let x = CGFloat(i) * gridSize
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                    }
                    
                    // Horizontal lines
                    for i in 0...Int(geometry.size.height / gridSize) {
                        if i % majorGridEvery == 0 {
                            let y = CGFloat(i) * gridSize
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                }
                .stroke(Color.gray.opacity(0.4), lineWidth: 1.0)
                
                // Center crosshair
                Path { path in
                    let centerX = geometry.size.width / 2
                    let centerY = geometry.size.height / 2
                    
                    // Horizontal line
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                    
                    // Vertical line
                    path.move(to: CGPoint(x: centerX, y: 0))
                    path.addLine(to: CGPoint(x: centerX, y: geometry.size.height))
                }
                .stroke(Color.blue.opacity(0.5), lineWidth: 1.0)
            }
        }
    }
}

struct TimelineView: View {
    @Binding var currentTime: Double
    let duration: Double
    @Binding var isPlaying: Bool
    let keyframes: [(String, Double, Double)]
    @Binding var selectedProperty: String?
    var onAddKeyframe: (String, Double, Double) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Timeline header
            HStack {
                Text("Timeline")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .padding(.trailing)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Timeline content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Properties list
                    ForEach(["opacity", "scale", "rotation"], id: \.self) { property in
                        PropertyRow(
                            property: property,
                            isSelected: selectedProperty == property,
                            currentTime: currentTime,
                            keyframes: keyframes.filter { $0.0 == property },
                            duration: duration,
                            onSelect: {
                                selectedProperty = property
                            }
                        )
                    }
                }
            }
            
            Divider()
            
            // Timeline ruler and playhead
            TimelineRuler(
                currentTime: $currentTime,
                duration: duration
            )
            .frame(height: 40)
            .padding(.horizontal)
        }
    }
}

struct PropertyRow: View {
    let property: String
    let isSelected: Bool
    let currentTime: Double
    let keyframes: [(String, Double, Double)]
    let duration: Double
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(property.capitalized)
                    .frame(width: 100, alignment: .leading)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                // Keyframe indicators
                ForEach(keyframes, id: \.1) { keyframe in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat(keyframe.1 / duration * 300) - 150)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
            .background(isSelected ? Color.accentColor : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct TimelineRuler: View {
    @Binding var currentTime: Double
    let duration: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Ruler background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                
                // Time markers
                timeMarkers(geometry: geometry)
                
                // Time labels
                timeLabels(geometry: geometry)
                
                // Current time indicator
                currentTimeIndicator(geometry: geometry)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateCurrentTime(value: value, geometry: geometry)
                    }
            )
        }
    }
    
    // Helper function to create time markers
    private func timeMarkers(geometry: GeometryProxy) -> some View {
        let durationInt = Int(duration)
        return ForEach(0...durationInt, id: \.self) { second in
            let height: CGFloat = second % 5 == 0 ? 12 : 8
            let xPosition = calculateXPosition(for: second, width: geometry.size.width)
            
            Rectangle()
                .fill(Color.gray)
                .frame(width: 1, height: height)
                .offset(x: xPosition)
                .alignmentGuide(.leading) { _ in 0 }
        }
    }
    
    // Helper function to create time labels
    private func timeLabels(geometry: GeometryProxy) -> some View {
        let durationInt = Int(duration)
        let stride = stride(from: 0, through: durationInt, by: 5)
        return ForEach(Array(stride), id: \.self) { second in
            let xPosition = calculateXPosition(for: second, width: geometry.size.width) + 2
            
            Text("\(second)s")
                .font(.caption2)
                .offset(x: xPosition)
                .alignmentGuide(.leading) { _ in 0 }
        }
    }
    
    // Helper function to create current time indicator
    private func currentTimeIndicator(geometry: GeometryProxy) -> some View {
        let xPosition = calculateXPosition(for: currentTime, width: geometry.size.width)
        
        return Rectangle()
            .fill(Color.red)
            .frame(width: 2)
            .frame(height: geometry.size.height)
            .position(x: xPosition, y: geometry.size.height / 2)
    }
    
    // Helper function to calculate x position
    private func calculateXPosition(for time: Int, width: CGFloat) -> CGFloat {
        return CGFloat(time) / CGFloat(duration) * width
    }
    
    private func calculateXPosition(for time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(time / duration) * width
    }
    
    // Helper function to update current time
    private func updateCurrentTime(value: DragGesture.Value, geometry: GeometryProxy) {
        let newTime = Double(value.location.x / geometry.size.width) * duration
        currentTime = max(0, min(duration, newTime))
    }
}

#Preview {
    DesignCanvas()
} 
