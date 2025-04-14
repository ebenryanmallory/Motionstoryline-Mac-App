import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import Foundation
import CoreGraphics
// Add import for Canvas components

// Note: Components have been organized into folders:
// - Common/ExportFormat.swift: Export format options
// - Animation/AnimationController.swift: Animation playback control
// - Canvas/CanvasElement.swift: Canvas element model and types
// - Canvas/CanvasElementView.swift: Views for canvas elements
// - Canvas/GridBackground.swift: Grid background component
// - Utilities/MousePositionView.swift: Mouse position tracking
// - UI Components/DesignToolbar.swift: UI controls and tools
// - UI Components/TopBar.swift: Top navigation bar

// Note: ElementType is defined in CanvasElement.swift
// Do not create duplicate definitions

struct DesignCanvas: View {
@State private var canvasElements: [CanvasElement] = [
    CanvasElement(
        type: .ellipse,
        position: CGPoint(x: 500, y: 300),
        size: CGSize(width: 120, height: 120),
        color: .green,
        displayName: "Green Circle"
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
    @State private var zoom: CGFloat = 1.0
    @State private var showZoomIndicator: Bool = false
    // Timeline specific zoom and offset state
    @State private var timelineScale: Double = 1.0
    @State private var timelineOffset: Double = 0.0
    @State private var selectedTool: DesignTool = .select
    @State private var isInspectorVisible = true
    
    // State for viewport dragging with space bar
    @State private var isSpaceBarPressed: Bool = false
    @State private var viewportOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint?
    @State private var isEditingText = false
    @State private var editingText: String = ""
    @State private var currentMousePosition: CGPoint?
    @State private var draggedElementId: UUID?
    @State private var initialDragElementPosition: CGPoint?
    @State private var selectedElementId: UUID?
    @State private var selectedElement: CanvasElement?
    
    // Drawing state variables
    @State private var isDrawingRectangle = false
    @State private var isDrawingEllipse = false
    @State private var rectangleStartPoint: CGPoint?
    @State private var rectangleCurrentPoint: CGPoint?
    @State private var isBreakingAspectRatio = false
    @State private var aspectRatioInfoVisible = false
    
    // Grid settings that will be passed to CanvasContentView
    @State private var showGrid: Bool = true
    @State private var gridSize: CGFloat = 20
    @State private var snapToGridEnabled: Bool = true
    
    // Navigation state
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var appState: AppStateManager
    
    // Animation controller
    @StateObject private var animationController = AnimationController()
    @State private var isPlaying = false
    @State private var selectedProperty: String?
    @State private var timelineHeight: CGFloat = 400 // Default timeline height
    @State private var showAnimationPreview: Bool = true // Control if animation preview is shown
    
    // Export state
    @State private var isExporting = false
    @State private var exportProgress: Float = 0
    @State private var exportFormat: ExportFormat = .video
    @State private var selectedProResProfile: VideoExporter.ProResProfile = .proRes422HQ
    @State private var showExportSettings = false
    @State private var exportResolution: (width: Int, height: Int) = (1920, 1080)
    @State private var exportFrameRate: Float = 30.0
    @State private var exportDuration: Double = 5.0
    @State private var exportingError: Error?
    
    // Initialize animation controller with a test animation
    private func setupInitialAnimations() {
        // Setup the animation controller
        animationController.setup(duration: 3.0)
        
        // Find the green circle element
        if let greenCircle = canvasElements.first(where: { $0.displayName == "Green Circle" }) {
            // Create an opacity track for the circle
            let opacityTrack = animationController.addTrack(id: "\(greenCircle.id)_opacity") { (newOpacity: Double) in
                if let index = canvasElements.firstIndex(where: { $0.id == greenCircle.id }) {
                    canvasElements[index].opacity = newOpacity
                }
            }
            
            // Add keyframes for the opacity animation
            opacityTrack.add(keyframe: Keyframe(time: 0.0, value: 1.0))
            opacityTrack.add(keyframe: Keyframe(time: 1.5, value: 0.3))
            opacityTrack.add(keyframe: Keyframe(time: 3.0, value: 1.0))
        }
    }
    
    // Camera recording state
    @State private var isRecording = false
    @State private var showCameraView = false
    
    // Key event monitor for tracking space bar
    private var keyEventMonitor: Any?
    
    // Sample keyframes for demonstration
    let keyframes: [(String, Double, Double)] = [
        ("opacity", 0.0, 0.0),
        ("opacity", 1.0, 0.5),
        ("opacity", 0.0, 1.0),
        ("scale", 1.0, 0.0),
        ("scale", 1.5, 0.5),
        ("scale", 1.0, 1.0)
    ]
    
    // MARK: - Main View
    
    // MARK: - Zoom Control Functions
    
    // Zoom control functions
    private func zoomIn() {
        zoom = min(zoom * 1.25, 5.0) // Increase zoom by 25%, max 5x
        showTemporaryZoomIndicator()
    }
    
    private func zoomOut() {
        zoom = max(zoom * 0.8, 0.1) // Decrease zoom by 20%, min 0.1x
        showTemporaryZoomIndicator()
    }
    
    private func resetZoom() {
        zoom = 1.0 // Reset to 100%
        showTemporaryZoomIndicator()
    }
    
    private func showTemporaryZoomIndicator() {
        // Show the zoom indicator
        showZoomIndicator = true
        
        // Hide it after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut) {
                showZoomIndicator = false
            }
        }
    }

    var body: some View {
        mainContentView
            .sheet(isPresented: $showCameraView) {
                CameraRecordingView(isPresented: $showCameraView)
            }
            .sheet(isPresented: $showExportSettings) {
                exportSettingsView
            }
            .overlay {
                if isExporting {
                    exportProgressView
                }
            }
            .alert(
                "Export Error",
                isPresented: Binding<Bool>(
                    get: { exportingError != nil && !isExporting },
                    set: { if !$0 { exportingError = nil } }
                ),
                presenting: exportingError
            ) { error in
                Button("OK") {
                    exportingError = nil
                }
            } message: { error in
                if let videoError = error as? VideoExporter.ExportError {
                    Text(videoError.localizedDescription)
                } else {
                    Text(error.localizedDescription)
                }
            }
            .onChange(of: selectedElementId) { newValue in
                if let id = newValue {
                    selectedElement = canvasElements.first(where: { $0.id == id })
                } else {
                    selectedElement = nil
                }
            }
            .onChange(of: selectedElement) { newValue in
                if let updatedElement = newValue, let index = canvasElements.firstIndex(where: { $0.id == updatedElement.id }) {
                    // Update the element in the canvasElements array to ensure it's rendered correctly
                    canvasElements[index] = updatedElement
                }
            }
            .onAppear {
                setupKeyEventMonitor()
            }
            .onDisappear {
                teardownKeyEventMonitor()
            }
    }
    
    // Setup key event monitor for detecting space bar press
    private func setupKeyEventMonitor() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            
            // Check for space bar
            if event.keyCode == 49 { // 49 is the keycode for space
                if event.type == .keyDown && !self.isSpaceBarPressed {
                    self.isSpaceBarPressed = true
                    // Change cursor to hand when space is pressed
                    NSCursor.closedHand.set()
                } else if event.type == .keyUp && self.isSpaceBarPressed {
                    self.isSpaceBarPressed = false
                    // Restore cursor based on current tool
                    if self.selectedTool == .select {
                        NSCursor.arrow.set()
                    } else if self.selectedTool == .rectangle || self.selectedTool == .ellipse {
                        NSCursor.crosshair.set()
                    }
                }
            }
            
            return event
        }
    }
    
    private func teardownKeyEventMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // Viewport drag gesture for panning when space is pressed
    private var viewportDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard isSpaceBarPressed else { return }
                
                if dragStartLocation == nil {
                    dragStartLocation = value.startLocation
                }
                
                // Calculate new offset based on drag movement
                viewportOffset = CGSize(
                    width: viewportOffset.width + value.translation.width - (dragStartLocation?.x ?? 0),
                    height: viewportOffset.height + value.translation.height - (dragStartLocation?.y ?? 0)
                )
                
                // Update drag start location for next change
                dragStartLocation = CGPoint(x: value.translation.width, y: value.translation.height)
            }
            .onEnded { _ in
                guard isSpaceBarPressed else { return }
                dragStartLocation = nil
            }
    }

    // Main content view for better compiler performance
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            // Top navigation bar
            CanvasTopBar(
                projectName: "Motion Storyline",
                onClose: {
                    appState.navigateToHome()
                },
                onNewFile: {
                    print("New file action triggered")
                },
                onCameraRecord: {
                    showCameraView = true
                },
                isPlaying: $isPlaying,
                showAnimationPreview: $showAnimationPreview,
                onExport: { format in
                    self.exportFormat = format
                    handleExportRequest(format: format)
                },
                onAccountSettings: {
                    print("Account settings action triggered")
                },
                onPreferences: {
                    print("Preferences action triggered")
                },
                onHelpAndSupport: {
                    print("Help and support action triggered")
                },
                onCheckForUpdates: {
                    print("Check for updates action triggered")
                },
                onSignOut: {
                    print("Sign out action triggered")
                },
                onZoomIn: zoomIn,
                onZoomOut: zoomOut,
                onZoomReset: resetZoom
            )
            // Design toolbar full width below top bar
            DesignToolbar(selectedTool: $selectedTool)
                .padding(.vertical, 4)
            
            Divider() // Add visual separator between toolbar and canvas
            
            // Main content area with canvas and inspector
            HStack(spacing: 0) {
                // Main canvas area
                canvasContentView
                
                // Right sidebar with inspector
                if isInspectorVisible {
                    Divider()
                    inspectorView
                }
            }
            
            // Timeline area at the bottom (if needed)
            if showAnimationPreview {
                timelineResizeHandle
                timelineView
                    .frame(height: timelineHeight)
            }
        }
    }
    
    // MARK: - View Components
    
    // Canvas content component
    // Canvas content component
    private var canvasContentView: some View {
        ZStack {
            // Grid background (bottom layer)
            GridBackground(showGrid: showGrid, gridSize: gridSize)
            
            // Background for click capture - MOVED BEFORE ELEMENTS
            canvasBackgroundView
            
            // Canvas elements
            canvasElementsView
            
            // Drawing previews
            drawingPreviewView
            
            // Mouse tracking view for cursor management
            MousePositionView { location in
                currentMousePosition = location
            }
            .allowsHitTesting(false) // Make sure it doesn't interfere with other interactions
            
            // Zoom level indicator (only shown temporarily)
            if showZoomIndicator {
                Text("\(Int(zoom * 100))%")
                    .font(.system(size: 18, weight: .bold))
                    .padding(10)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .transition(.opacity)
                    .zIndex(1000) // Ensure it's on top
            }
        }
        .scaleEffect(zoom) // Apply zoom scale
        .offset(viewportOffset) // Apply the viewport offset
        .gesture(viewportDragGesture) // Add the drag gesture
        .frame(minWidth: 400, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Canvas background with click handlers
    var canvasBackgroundView: some View {
        Color.clear
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .onTapGesture { location in
                // If we're editing text, finish editing
                if isEditingText {
                    if let elementId = selectedElementId, let _ = canvasElements.firstIndex(where: { $0.id == elementId }) {
                        // Ensure the textAlignment is maintained after editing
                        // No additional code needed as we're already using the element's textAlignment
                        // in the view and it's preserved in the model
                    }
                    isEditingText = false
                } else if selectedTool == .text {
                    // Handle text tool - create text at tap location
                    handleTextCreation(at: location)
                } else if selectedTool == .select {
                    // Deselect the current element when clicking on empty canvas area
                    selectedElementId = nil
                }
            }
            .contextMenu {
                canvasContextMenu
            }
            .onHover { isHovering in
                if !isHovering {
                    currentMousePosition = nil
                } else if selectedTool == .select {
                    // Change cursor to arrow when in selection mode
                    NSCursor.arrow.set()
                } else if selectedTool == .rectangle || selectedTool == .ellipse {
                    // Change cursor to crosshair when in shape drawing mode
                    NSCursor.crosshair.set()
                }
            }
            .gesture(canvasDrawingGesture)
    }
    
    // Canvas context menu content
    var canvasContextMenu: some View {
        Group {
            // Context menu for empty canvas area
            Button(action: {
                // Create rectangle at cursor position
                if let position = currentMousePosition {
                    let newRectangle = CanvasElement.rectangle(
                        at: position,
                        size: CGSize(width: 150, height: 100)
                    )
                    canvasElements.append(newRectangle)
                    selectedElementId = newRectangle.id
                }
            }) {
                Label("Add Rectangle", systemImage: "rectangle")
            }
            
            Button(action: {
                // Create ellipse at cursor position
                if let position = currentMousePosition {
                    let newEllipse = CanvasElement.ellipse(
                        at: position,
                        size: CGSize(width: 100, height: 100)
                    )
                    canvasElements.append(newEllipse)
                    selectedElementId = newEllipse.id
                }
            }) {
                Label("Add Ellipse", systemImage: "circle")
            }
            
            Button(action: {
                // Create text element at cursor position
                if let position = currentMousePosition {
                    let newText = CanvasElement.text(at: position)
                    canvasElements.append(newText)
                    selectedElementId = newText.id
                    isEditingText = true
                    editingText = newText.text
                }
            }) {
                Label("Add Text", systemImage: "text.cursor")
            }
            
            Divider()
            
            gridSettingsMenu
            
            Divider()
            
            viewSettingsMenu
            
            if !canvasElements.isEmpty {
                Divider()
                
                elementSelectionMenu
            }
            
            if canvasElements.count > 0 {
                Divider()
                
                Button(action: {
                    // Clear canvas (remove all elements)
                    // Show confirmation dialog (in a real app)
                    canvasElements.removeAll()
                    selectedElementId = nil
                }) {
                    Label("Clear Canvas", systemImage: "xmark.square")
                }
            }
        }
    }
    
    // Grid settings submenu
    var gridSettingsMenu: some View {
        Menu("Grid Settings") {
            Toggle(isOn: $showGrid) {
                Label("Show Grid", systemImage: "grid")
            }
            
            Toggle(isOn: $snapToGridEnabled) {
                Label("Snap to Grid", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            
            Menu("Grid Size") {
                Button(action: {
                    gridSize = 10
                }) {
                    Label("Small (10px)", systemImage: gridSize == 10 ? "checkmark" : "")
                }
                
                Button(action: {
                    gridSize = 20
                }) {
                    Label("Medium (20px)", systemImage: gridSize == 20 ? "checkmark" : "")
                }
                
                Button(action: {
                    gridSize = 40
                }) {
                    Label("Large (40px)", systemImage: gridSize == 40 ? "checkmark" : "")
                }
            }
            
            Divider()
            
            Text("Keyboard Shortcuts:")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⌘G: Toggle Grid")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⇧⌘G: Toggle Snap to Grid")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    // View settings submenu
    private var viewSettingsMenu: some View {
        Menu("View") {
            Button(action: {
                // Center the view on content by resetting viewport offset
                viewportOffset = .zero
            }) {
                }) {
                    Label("Center Content", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
                }
                Button(action: {
                    // Zoom in
                    zoomIn()
                }) {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button(action: {
                    // Zoom out
                    zoomOut()
                }) {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button(action: {
                    // Reset zoom to 100%
                    resetZoom()
                }) {
                    Label("Reset Zoom", systemImage: "1.magnifyingglass")
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            Divider()
            
            Text("Keyboard Shortcuts:")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⌘0: Reset Zoom")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⌘+: Zoom In")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⌘-: Zoom Out")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    // Element selection menu items
    private var elementSelectionMenu: some View {
        Group {
            Button(action: {
                // Select a tool from the quick menu
                selectedTool = .select
            }) {
                Label("Select Tool", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button(action: {
                // Select all elements (in a real app, this would select multiple elements)
                if !canvasElements.isEmpty {
                    selectedElementId = canvasElements.first?.id
                }
            }) {
                Label("Select All", systemImage: "checkmark.circle")
            }
            
            if selectedElementId != nil {
                Button(action: {
                    // Deselect all
                    selectedElementId = nil
                }) {
                    Label("Deselect All", systemImage: "rectangle.dashed")
                }
            }
        }
    }
    
    // Canvas drawing gesture logic
    private var canvasDrawingGesture: some Gesture {
        selectedTool == .rectangle ? 
        DragGesture()
            .onChanged { value in
                if !isDrawingRectangle {
                    // Start drawing rectangle
                    isDrawingRectangle = true
                    rectangleStartPoint = value.startLocation
                    
                    // Show aspect ratio helper the first time we draw
                    aspectRatioInfoVisible = true
                    
                    // Check for shift key to break aspect ratio
                    isBreakingAspectRatio = NSEvent.modifierFlags.contains(.shift)
                }
                // Update current point as drag continues
                rectangleCurrentPoint = value.location
                
                // Continuously check for the shift key
                isBreakingAspectRatio = NSEvent.modifierFlags.contains(.shift)
            }
            .onEnded { value in
                // Finalize rectangle
                if let start = rectangleStartPoint, isDrawingRectangle {
                    let rect = calculateConstrainedRect(from: start, to: value.location)
                    
                    // Only create rectangle if it has a meaningful size
                    if rect.width > 5 && rect.height > 5 {
                        // Create rectangle at the calculated position and size
                        let centerPosition = CGPoint(x: rect.midX, y: rect.midY)
                        let newRectangle = CanvasElement.rectangle(
                            at: centerPosition,
                            size: CGSize(width: rect.width, height: rect.height)
                        )
                        
                        // Add the rectangle to the canvas
                        canvasElements.append(newRectangle)
                        
                        // Select the new rectangle
                        selectedElementId = newRectangle.id
                    }
                }
                
                // Reset rectangle drawing state
                isDrawingRectangle = false
                rectangleStartPoint = nil
                rectangleCurrentPoint = nil
                isBreakingAspectRatio = false
                
                // Hide the aspect ratio helper after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    aspectRatioInfoVisible = false
                }
            } : 
        selectedTool == .ellipse ? 
        DragGesture()
            .onChanged { value in
                if !isDrawingEllipse {
                    // Start drawing ellipse
                    isDrawingEllipse = true
                    rectangleStartPoint = value.startLocation
                    
                    // Show aspect ratio helper the first time we draw
                    aspectRatioInfoVisible = true
                    
                    // Check for shift key to break aspect ratio
                    isBreakingAspectRatio = NSEvent.modifierFlags.contains(.shift)
                }
                // Update current point as drag continues
                rectangleCurrentPoint = value.location
                
                // Continuously check for the shift key
                isBreakingAspectRatio = NSEvent.modifierFlags.contains(.shift)
            }
            .onEnded { value in
                // Finalize ellipse
                if let start = rectangleStartPoint, isDrawingEllipse {
                    let rect = calculateConstrainedRect(from: start, to: value.location)
                    
                    // Only create ellipse if it has a meaningful size
                    if rect.width > 5 && rect.height > 5 {
                        // Create ellipse at the calculated position and size
                        let centerPosition = CGPoint(x: rect.midX, y: rect.midY)
                        let newEllipse = CanvasElement.ellipse(
                            at: centerPosition,
                            size: CGSize(width: rect.width, height: rect.height)
                        )
                        
                        // Add the ellipse to the canvas
                        canvasElements.append(newEllipse)
                        
                        // Select the new ellipse
                        selectedElementId = newEllipse.id
                    }
                }
                
                // Reset ellipse drawing state
                isDrawingEllipse = false
                rectangleStartPoint = nil
                rectangleCurrentPoint = nil
                isBreakingAspectRatio = false
                
                // Hide the aspect ratio helper after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    aspectRatioInfoVisible = false
                }
            } :
        DragGesture().onChanged { _ in }.onEnded { _ in }
    }
    
    // Canvas elements view
    private var canvasElementsView: some View {
        ForEach(canvasElements) { element in
            CanvasElementView(
                element: element,
                isSelected: element.id == selectedElementId,
                onResize: { newSize in
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].size = newSize
                    }
                },
                onRotate: { newRotation in
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].rotation = newRotation
                    }
                },
                isTemporary: false,
                isDragging: element.id == draggedElementId
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if selectedTool == .select {
                            if draggedElementId != element.id {
                                // First time this element is being dragged in this gesture
                                draggedElementId = element.id
                                
                                // Store the initial position of the element
                                if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                                    initialDragElementPosition = canvasElements[index].position
                                }
                            }
                            
                            // Only proceed if we have the initial position
                            if let initialPosition = initialDragElementPosition,
                               let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                                
                                // Calculate new position based on start location and current location
                                var newPosition = CGPoint(
                                    x: initialPosition.x + (value.location.x - value.startLocation.x),
                                    y: initialPosition.y + (value.location.y - value.startLocation.y)
                                )
                                
                                // Apply snap to grid if enabled
                                if snapToGridEnabled {
                                    newPosition.x = round(newPosition.x / gridSize) * gridSize
                                    newPosition.y = round(newPosition.y / gridSize) * gridSize
                                }
                                
                                // Update element position
                                canvasElements[index].position = newPosition
                            }
                        }
                    }
                    .onEnded { _ in
                        // Clear drag state
                        draggedElementId = nil
                        initialDragElementPosition = nil
                    }
            )
            .contextMenu {
                elementContextMenu(for: element)
            }
        }
    }
    
    // Element context menu
    private func elementContextMenu(for element: CanvasElement) -> some View {
        Group {
            // Context menu for elements
            Button(action: {
                // Duplicate the element
                if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                    var newElement = canvasElements[index]
                    newElement.id = UUID()
                    newElement.position = CGPoint(
                        x: newElement.position.x + 20,
                        y: newElement.position.y + 20
                    )
                    newElement.displayName = "Copy of \(newElement.displayName)"
                    canvasElements.append(newElement)
                    selectedElementId = newElement.id
                }
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Button(action: {
                // Delete the element
                canvasElements.removeAll(where: { $0.id == element.id })
                selectedElementId = nil
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Divider()
            
            if element.type == .text {
                textElementOptions(for: element)
            }
            
            elementColorOptions(for: element)
            elementOpacityOptions(for: element)
        }
    }
    
    // Text element options
    private func textElementOptions(for element: CanvasElement) -> some View {
        Group {
            Button(action: {
                // Edit text
                selectedElementId = element.id
                isEditingText = true
                editingText = element.text
            }) {
                Label("Edit Text", systemImage: "pencil")
            }
            
            Menu("Text Alignment") {
                Button(action: {
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].textAlignment = .leading
                    }
                }) {
                    Label("Left", systemImage: "text.alignleft")
                }
                
                Button(action: {
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].textAlignment = .center
                    }
                }) {
                    Label("Center", systemImage: "text.aligncenter")
                }
                
                Button(action: {
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].textAlignment = .trailing
                    }
                }) {
                    Label("Right", systemImage: "text.alignright")
                }
            }
        }
    }
    
    // Element color options
    private func elementColorOptions(for element: CanvasElement) -> some View {
        Menu("Color") {
            ForEach(["Red", "Blue", "Green", "Orange", "Purple", "Black"], id: \.self) { colorName in
                Button(action: {
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].color = colorForName(colorName)
                    }
                }) {
                    Label {
                        Text(colorName)
                    } icon: {
                        Circle()
                            .fill(colorForName(colorName))
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
    }
    
    // Helper function to convert color name to Color
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "black": return .black
        default: return .gray
        }
    }
    
    // Element opacity options
    private func elementOpacityOptions(for element: CanvasElement) -> some View {
        Menu("Opacity") {
            ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { opacity in
                Button(action: {
                    if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvasElements[index].opacity = opacity
                    }
                }) {
                    Label("\(Int(opacity * 100))%", systemImage: "circle.fill")
                        .foregroundColor(.yellow.opacity(opacity))
                }
            }
        }
    }
    
    // Drawing preview views
    private var drawingPreviewView: some View {
        Group {
            // Preview of rectangle being drawn
            if isDrawingRectangle, let start = rectangleStartPoint, let current = rectangleCurrentPoint {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: current.x - start.x, height: current.y - start.y)
            }
            
            // Preview of ellipse being drawn
            if isDrawingEllipse, let start = rectangleStartPoint, let current = rectangleCurrentPoint {
                Ellipse()
                    .stroke(Color.black, lineWidth: 1)
                    .frame(width: current.x - start.x, height: current.y - start.y)
            }
        }
    }
    
    // Inspector view component
    private var inspectorView: some View {
        Group {
            if let selectedElementId = selectedElementId, 
               let selectedElement = canvasElements.first(where: { $0.id == selectedElementId }) {
                InspectorView(
                    selectedElement: Binding<CanvasElement?>(
                        get: { selectedElement },
                        set: { newValue in
                            if let newValue = newValue, let index = canvasElements.firstIndex(where: { $0.id == selectedElementId }) {
                                canvasElements[index] = newValue
                            }
                        }
                    ),
                    onClose: {
                        // Deselect the element
                        self.selectedElementId = nil
                    }
                )
                .frame(width: 260)
            } else {
                // Show empty inspector with project settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Inspector")
                        .font(.headline)
                        .padding(.top, 12)
                    
                    Text("No element selected")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .frame(width: 260)
                .padding(.horizontal)
            }
        }
    }
    
    // Timeline component
    private var timelineView: some View {
        VStack(spacing: 0) {
            // Animation controls toolbar
            HStack {
                HStack(spacing: 12) {
                    Button(action: {
                        isPlaying.toggle()
                        if isPlaying {
                            animationController.play()
                        } else {
                            animationController.pause()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 30, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    .help(isPlaying ? "Pause Animation" : "Play Animation")
                    
                    Button(action: {
                        animationController.reset()
                        isPlaying = false
                    }) {
                        Image(systemName: "stop.fill")
                            .frame(width: 30, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: [])
                    .help("Reset Animation")
                }
                
                Spacer()
                
                Text(String(format: "%.1fs / %.1fs", animationController.currentTime, animationController.duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Animation editor area (timeline + keyframe editor)
            VStack(spacing: 4) {
                // Simple animation timeline ruler
                TimelineRuler(
                    duration: animationController.duration,
                    currentTime: Binding(
                        get: { animationController.currentTime },
                        set: { animationController.currentTime = $0 }
                    ),
                    scale: timelineScale,
                    offset: $timelineOffset,
                    keyframeTimes: animationController.getAllKeyframeTimes()
                )
                    .padding(.top, 8)
                
                // Divider between timeline ruler and keyframe editor
                Divider()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                
                // KeyframeEditorView component (main section)
                KeyframeEditorView(animationController: animationController, selectedElement: $selectedElement)
                    .layoutPriority(1) // Give this component layout priority
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity) // Let this section expand
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // Helper method to handle text creation
    private func handleTextCreation(at location: CGPoint) {
        let newText = CanvasElement.text(at: location)
        canvasElements.append(newText)
        selectedElementId = newText.id
        isEditingText = true
        editingText = newText.text
    }
    
    // Helper method to calculate constrained rectangle
    private func calculateConstrainedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        var width = end.x - start.x
        var height = end.y - start.y
        
        // If shift is pressed, constrain to a square or circle (equal width and height)
        if !isBreakingAspectRatio {
            let minDimension = min(abs(width), abs(height))
            width = width < 0 ? -minDimension : minDimension
            height = height < 0 ? -minDimension : minDimension
        }
        
        // Calculate the origin point to ensure the rectangle is properly positioned
        // regardless of which direction the user drags
        let originX = width < 0 ? start.x + width : start.x
        let originY = height < 0 ? start.y + height : start.y
        
        return CGRect(x: originX, y: originY, width: abs(width), height: abs(height))
    }

    // MARK: - Export Methods
    
    /// Handle export request based on the selected format
    private func handleExportRequest(format: ExportFormat) {
        switch format {
        case .video:
            // Show export settings sheet to let user confirm settings
            showExportSettings = true
        case .gif:
            print("GIF export not implemented yet")
        case .imageSequence:
            print("Image sequence export not implemented yet")
        case .projectFile:
            print("Project file export not implemented yet")
        }
    }
    
    // MARK: - Export Views
    
    /// Export progress overlay view
    private var exportProgressView: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Exporting Video...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: exportProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 300)
                
                Text("\(Int(exportProgress * 100))%")
                    .foregroundColor(.white)
                    .font(.subheadline)
                    .monospacedDigit()
                
                Button("Cancel") {
                    // TODO: Implement export cancellation
                    isExporting = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(30)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            .cornerRadius(16)
            .shadow(radius: 20)
        }
    }
    
    /// Export settings configuration view
    private var exportSettingsView: some View {
        VStack(spacing: 20) {
            Text("Export Settings")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                Section(header: Text("Format")) {
                    Picker("Format", selection: $exportFormat) {
                        Text("Video").tag(ExportFormat.video)
                        Text("GIF").tag(ExportFormat.gif)
                        Text("Image Sequence (PNG)").tag(ExportFormat.imageSequence(.png))
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if exportFormat == .video {
                        Picker("Quality", selection: $selectedProResProfile) {
                            Text("Standard MP4").tag(VideoExporter.ProResProfile.proRes422HQ)
                            Divider()
                            Text("ProRes 422 Proxy").tag(VideoExporter.ProResProfile.proRes422Proxy)
                            Text("ProRes 422 LT").tag(VideoExporter.ProResProfile.proRes422LT)
                            Text("ProRes 422").tag(VideoExporter.ProResProfile.proRes422)
                            Text("ProRes 422 HQ").tag(VideoExporter.ProResProfile.proRes422HQ)
                            Text("ProRes 4444").tag(VideoExporter.ProResProfile.proRes4444)
                            Text("ProRes 4444 XQ").tag(VideoExporter.ProResProfile.proRes4444XQ)
                        }
                    }
                }
                
                Section(header: Text("Resolution")) {
                    Picker("Resolution", selection: Binding<Int>(
                        get: { 
                            switch (exportResolution.width, exportResolution.height) {
                                case (3840, 2160): return 0 // 4K
                                case (1920, 1080): return 1 // 1080p
                                case (1280, 720):  return 2 // 720p
                                default:           return 1 // Default to 1080p
                            }
                        },
                        set: { newValue in
                            switch newValue {
                                case 0: exportResolution = (3840, 2160) // 4K
                                case 1: exportResolution = (1920, 1080) // 1080p
                                case 2: exportResolution = (1280, 720)  // 720p
                                default: exportResolution = (1920, 1080) // Default to 1080p
                            }
                        }
                    )) {
                        Text("4K (3840×2160)").tag(0)
                        Text("Full HD (1920×1080)").tag(1)
                        Text("HD (1280×720)").tag(2)
                    }
                }
                
                Section(header: Text("Frame Rate")) {
                    Picker("Frame Rate", selection: $exportFrameRate) {
                        Text("24 fps").tag(Float(24))
                        Text("30 fps").tag(Float(30))
                        Text("60 fps").tag(Float(60))
                    }
                }
                
                Section(header: Text("Duration")) {
                    HStack {
                        Text("Duration: \(String(format: "%.1f", exportDuration)) seconds")
                        Spacer()
                        Slider(value: $exportDuration, in: 1...30, step: 0.5)
                            .frame(width: 200)
                    }
                }
            }
            .padding()
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    showExportSettings = false
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Button("Export") {
                    showExportSettings = false
                    Task {
                        await exportVideo(
                            resolution: exportResolution,
                            frameRate: exportFrameRate,
                            duration: exportDuration
                        )
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 600)
    }
    
    // MARK: - Timeline Resize Handle
    
    /// A resize handle for the timeline area
    private var timelineResizeHandle: some View {
        ZStack {
            // Background line/divider
            Divider()
            
            // Visual handle indicator
            HStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(NSColor.separatorColor))
                        .frame(width: 20, height: 3)
                }
            }
            
            // Invisible hit area for the gesture
            Color.clear
                .contentShape(Rectangle())
                .frame(height: 12) // Larger hit area for better UX
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Calculate new height based on drag
                            let proposedHeight = timelineHeight - value.translation.height
                            
                            // Enforce constraints (min: 70, max: 600)
                            timelineHeight = min(600, max(70, proposedHeight))
                        }
                )
                .onHover { isHovering in
                    // Change cursor to vertical resize cursor when hovering
                    if isHovering {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
        .frame(height: 12) // Height of the resize handle area
        .frame(height: 12) // Height of the resize handle area
        .frame(height: 12) // Height of the resize handle area
        .padding(.vertical, 1)
    }
    
    /// Export the canvas as a video file
    @MainActor
    private func exportVideo(
        resolution: (width: Int, height: Int) = (1920, 1080),
        frameRate: Float = 30,
        duration: Double = 5.0
    ) async {
        isExporting = true
        exportProgress = 0
        exportingError = nil
        
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            print("Debug: Error - exportVideo called from background thread")
            await MainActor.run {
                isExporting = false
                exportingError = NSError(domain: "MotionStoryline", code: 100, userInfo: [NSLocalizedDescriptionKey: "Export must be initiated from the main thread"])
            }
            return
        }
        
        // Ask user to choose save location
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.quickTimeMovie]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save Video"
        savePanel.message = "Choose a location to save your video"
        savePanel.nameFieldLabel = "File name:"
        
        let usingProRes = selectedProResProfile != .proRes422HQ
        if usingProRes {
            // For ProRes, use .mov extension
            savePanel.allowedContentTypes = [UTType.quickTimeMovie]
            savePanel.nameFieldStringValue = "Motion_Storyline"
            // Explicitly set the expected extension
            if let fileType = savePanel.allowedContentTypes.first?.preferredFilenameExtension {
                savePanel.nameFieldStringValue = "Motion_Storyline.\(fileType)"
            }
        } else {
            // For MP4, use .mp4 extension
            savePanel.allowedContentTypes = [UTType.mpeg4Movie]
            savePanel.nameFieldStringValue = "Motion_Storyline"
            // Explicitly set the expected extension 
            if let fileType = savePanel.allowedContentTypes.first?.preferredFilenameExtension {
                savePanel.nameFieldStringValue = "Motion_Storyline.\(fileType)"
            }
        }
        
        // Important: Get the main window from the application's delegate to ensure it's the active window
        let windowCount = NSApplication.shared.windows.count
        print("Debug: Found \(windowCount) windows in the application")
        
        // Try to find the keyWindow or the main window
        var parentWindow: NSWindow?
        if let keyWindow = NSApplication.shared.keyWindow {
            parentWindow = keyWindow
            print("Debug: Using keyWindow as parent")
        } else if let mainWindow = NSApplication.shared.mainWindow {
            parentWindow = mainWindow
            print("Debug: Using mainWindow as parent")
        } else if let firstWindow = NSApplication.shared.windows.first {
            parentWindow = firstWindow
            print("Debug: Using first window as parent")
        }
        
        // Show save panel as a separate modal dialog, not as a sheet
        print("Debug: About to display save panel")
        let response = await savePanel.runModal()
        print("Debug: Save panel returned response code: \(response.rawValue)")
        
        if response != .OK {
            print("Debug: Save operation cancelled with response: \(response)")
            isExporting = false
            return
        }
        guard let outputURL = savePanel.url else {
            print("Debug: No output URL selected")
            isExporting = false
            return
        }
        
        // After this point, we have a valid outputURL to export to

        print("Debug: Selected output URL: \(outputURL.path)")
        
        // Check if file exists and delete it if needed
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
                print("Debug: Deleted existing file at \(outputURL.path)")
            } catch {
                print("Debug: Failed to delete existing file: \(error.localizedDescription)")
                isExporting = false
                exportingError = error
                return
            }
        }
        
        do {
            // Create a composition from the canvas
            let composition = try await createCompositionFromCanvas(
                width: resolution.width,
                height: resolution.height,
                duration: duration,
                frameRate: frameRate
            )
            
            // Create the video exporter
            let exporter = VideoExporter(asset: composition)
            
            // Configure export settings
            let configuration = VideoExporter.ExportConfiguration(
                format: .video,
                width: resolution.width,
                height: resolution.height,
                frameRate: frameRate,
                proResProfile: usingProRes ? selectedProResProfile : nil,
                outputURL: outputURL
            )
            
            // Export the video with detailed error handling
            print("Debug: Starting export with configuration: width=\(configuration.width), height=\(configuration.height), frameRate=\(configuration.frameRate)")
            print("Debug: Export destination: \(outputURL.path)")
            
            // Subscribe to progress notifications
            let progressObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("ExportProgressUpdate"),
                object: nil,
                queue: .main
            ) { notification in
                guard let progress = notification.userInfo?["progress"] as? Float else { return }
                print("Debug: Export progress update: \(progress * 100)%")
                self.exportProgress = progress
            }
            // Export the video with detailed error handling
            await exporter.export(with: configuration, progressHandler: { progress in
                // We'll use our custom progress notification instead
            }, completion: { [self] result in
                // Remove the observer when done
                NotificationCenter.default.removeObserver(progressObserver)
                
                switch result {
                case .success(let url):
                    print("Debug: Export successful to \(url.path)")
                    DispatchQueue.main.async {
                        // Make sure progress shows 100% on success
                        self.exportProgress = 1.0
                        
                        // Verify the file exists before trying to open it
                        if FileManager.default.fileExists(atPath: url.path) {
                            NSWorkspace.shared.open(url)
                        } else {
                            print("Debug: Warning - File doesn't exist after successful export: \(url.path)")
                        }
                        self.isExporting = false
                    }
                case .failure(let error):
                    print("Debug: Export failed with error: \(error.localizedDescription)")
                    // More detailed debug info
                    if case .exportFailed(let underlyingError) = error as VideoExporter.ExportError {
                        print("Debug: Underlying error: \(underlyingError.localizedDescription)")
                    }
                    DispatchQueue.main.async {
                        self.exportingError = error
                        self.isExporting = false
                    }
                }
            })
        } catch {
            // Now properly catch errors from createCompositionFromCanvas
            print("Debug: Composition creation failed with error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.exportingError = error
                self.isExporting = false
            }
        }
    }
    /// Create an AVComposition from the canvas elements
    private func createCompositionFromCanvas(
        width: Int,
        height: Int,
        duration: Double,
        frameRate: Float
    ) async throws -> AVAsset {
        // Create a simple blank video with a still image approach
        let frameCount = Int(duration * Double(frameRate))
        let tempDir = FileManager.default.temporaryDirectory
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        // Create a CGContext to render our frames into
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw NSError(domain: "MotionStoryline", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context"])
        }
        
        // Draw the canvas elements onto the context
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)) // White background
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Scale factor for positioning elements
        let scaleFactor = min(
            CGFloat(width) / 1000.0,  // Assuming canvas width is 1000
            CGFloat(height) / 800.0   // Assuming canvas height is 800
        )
        
        // Draw each element
        for element in canvasElements {
            let scaledSize = CGSize(
                width: element.size.width * scaleFactor,
                height: element.size.height * scaleFactor
            )
            
            let scaledPosition = CGPoint(
                x: element.position.x * scaleFactor,
                y: element.position.y * scaleFactor
            )
            
            // Position the element (convert from center to top-left origin)
            let rect = CGRect(
                x: scaledPosition.x - scaledSize.width / 2,
                y: scaledPosition.y - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            
            // Save the context state before transformations
            context.saveGState()
            
            // Apply rotation (around the center of the element)
            context.translateBy(x: scaledPosition.x, y: scaledPosition.y)
            context.rotate(by: element.rotation * .pi / 180)
            context.translateBy(x: -scaledPosition.x, y: -scaledPosition.y)
            
            // Apply opacity
            context.setAlpha(CGFloat(element.opacity))
            
            // Draw based on element type
            switch element.type {
            case .rectangle:
                context.setFillColor(element.color.cgColor ?? CGColor(gray: 0, alpha: 1.0))
                context.fill(rect)
                
            case .ellipse:
                context.setFillColor(element.color.cgColor ?? CGColor(gray: 0, alpha: 1.0))
                context.fillEllipse(in: rect)
            case .text:
                // For text, we'll draw a colored rectangle as a placeholder
                // (Full text rendering would require Core Text)
                context.setFillColor(element.color.cgColor ?? CGColor(gray: 0, alpha: 1.0))
                context.fill(rect)
            case .image, .video:
                // Draw a placeholder for images/videos
                context.setFillColor(CGColor(gray: 0.8, alpha: 1.0))
                context.fill(rect)
            }
            
            // Restore the context state
            context.restoreGState()
        }
        
        // Create an image from the context
        guard let image = context.makeImage() else {
            throw NSError(domain: "MotionStoryline", code: 102, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from context"])
        }
        
        // Create an asset writer to generate a video
        guard let assetWriter = try? AVAssetWriter(outputURL: temporaryVideoURL, fileType: .mov) else {
            throw NSError(domain: "MotionStoryline", code: 103, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset writer"])
        }
        
        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        // Create a writer input
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        // Create a pixel buffer adaptor
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: attributes
        )
        
        // Add the input to the writer
        if assetWriter.canAdd(writerInput) {
            assetWriter.add(writerInput)
        } else {
            throw NSError(domain: "MotionStoryline", code: 104, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input to asset writer"])
        }
        
        // Start writing
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        // Write frames
        var frameTime = CMTime.zero
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // Create a queue for writing
        let mediaQueue = DispatchQueue(label: "mediaQueue")
        
        let semaphore = DispatchSemaphore(value: 0)
        writerInput.requestMediaDataWhenReady(on: mediaQueue) {
            // Track the last reported progress to avoid duplicate updates
            var lastReportedProgress: Float = 0
            
            // We'll just write the same frame multiple times for a still image video
            for frameIdx in 0..<frameCount {
                if writerInput.isReadyForMoreMediaData {
                    var pixelBuffer: CVPixelBuffer?
                    let status = CVPixelBufferCreate(
                        kCFAllocatorDefault,
                        width,
                        height,
                        kCVPixelFormatType_32ARGB,
                        attributes as CFDictionary,
                        &pixelBuffer
                    )
                    
                    if status == kCVReturnSuccess, let pixelBuffer = pixelBuffer {
                        CVPixelBufferLockBaseAddress(pixelBuffer, [])
                        
                        if let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer) {
                            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                            
                            // Create a context with the pixel buffer
                            let context = CGContext(
                                data: pixelData,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: bitmapInfo.rawValue
                            )
                            
                            // Draw the image to the context
                            if let context = context {
                                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                            }
                        }
                        
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                        
                        // Append the frame to the video
                        if adaptor.append(pixelBuffer, withPresentationTime: frameTime) {
                            // If successful, increment time for next frame
                            frameTime = CMTimeAdd(frameTime, frameDuration)
                            
                            // Calculate and report progress based on frames processed
                            let currentProgress = Float(frameIdx + 1) / Float(frameCount)
                            
                            // Only dispatch progress updates when significant changes occur (> 1%)
                            if currentProgress - lastReportedProgress > 0.01 {
                                DispatchQueue.main.async {
                                    NSApp.mainWindow?.contentViewController?.view.window?.isDocumentEdited = true
                                    NotificationCenter.default.post(
                                        name: Notification.Name("ExportProgressUpdate"),
                                        object: nil,
                                        userInfo: ["progress": currentProgress]
                                    )
                                }
                                lastReportedProgress = currentProgress
                            }
                        } else {
                            // If appending fails, report the error
                            print("Debug: Failed to append pixel buffer - \(assetWriter.error?.localizedDescription ?? "unknown error")")
                            semaphore.signal()
                            return
                        }
                    }
                }
            }
            
            // Finish writing - this should be outside the loop
            writerInput.markAsFinished()
            assetWriter.finishWriting {
                if let error = assetWriter.error {
                    print("Debug: Error finishing writing: \(error.localizedDescription)")
                } else {
                    print("Debug: Successfully finished writing temporary video file")
                }
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        // Return the composed asset
        if assetWriter.status == .failed {
            throw NSError(domain: "MotionStoryline", code: 105, userInfo: [NSLocalizedDescriptionKey: "Failed to create video: \(assetWriter.error?.localizedDescription ?? "Unknown error")"])
        }
        
        print("Debug: Created temporary video at: \(temporaryVideoURL.path)")
        return AVAsset(url: temporaryVideoURL)
    }
/// Create a black pixel buffer for use in video compositions
private func createBlackFramePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        if status != kCVReturnSuccess {
            print("Debug: Failed to create pixel buffer")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer!)
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            
            // Fill with black
            context?.setFillColor(CGColor(gray: 0, alpha: 1.0))
            context?.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

// MARK: - Preview (Separated to avoid circular reference)
#if !DISABLE_PREVIEWS
struct DesignCanvasPreview: View {
    var body: some View {
        DesignCanvas()
    }
}

#Preview {
    DesignCanvasPreview()
}
#endif
