import SwiftUI
import AppKit
@preconcurrency import AVFoundation
import UniformTypeIdentifiers
import Foundation
import CoreGraphics
import UserNotifications
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
        position: CGPoint(x: 640, y: 360),
        size: CGSize(width: 120, height: 120),
        color: .green,
        displayName: "Green Circle"
    ),
    CanvasElement(
        type: .text,
        position: CGPoint(x: 640, y: 200),
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
    @State private var exportResolution: (width: Int, height: Int) = (1280, 720) // Default to HD
    @State private var exportFrameRate: Float = 30.0
    @State private var exportDuration: Double = 5.0
    @State private var exportingError: Error?
    
    // Key event monitor for tracking space bar
    @StateObject private var keyMonitorController = KeyEventMonitorController()
    
    // Canvas dimensions - HD aspect ratio (16:9)
    @State private var canvasWidth: CGFloat = 1280
    @State private var canvasHeight: CGFloat = 720
    
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
            .onChange(of: selectedElementId) { oldValue, newValue in
                if let id = newValue {
                    selectedElement = canvasElements.first(where: { $0.id == id })
                } else {
                    selectedElement = nil
                }
            }
            .onChange(of: selectedElement) { oldValue, newValue in
                if let updatedElement = newValue, let index = canvasElements.firstIndex(where: { $0.id == updatedElement.id }) {
                    // Update the element in the canvasElements array to ensure it's rendered correctly
                    canvasElements[index] = updatedElement
                }
            }
            .onAppear {
                // Setup initial animations
                setupInitialAnimations()
                // Setup key event monitor with the current state
                keyMonitorController.setupMonitor(
                    onSpaceDown: {
                        self.isSpaceBarPressed = true
                        NSCursor.closedHand.set()
                    },
                    onSpaceUp: {
                        self.isSpaceBarPressed = false
                        if self.selectedTool == .select {
                            NSCursor.arrow.set()
                        } else if self.selectedTool == .rectangle || self.selectedTool == .ellipse {
                            NSCursor.crosshair.set()
                        }
                    }
                )
            }
            .onDisappear {
                keyMonitorController.teardownMonitor()
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
            
            // Add a Divider to clearly separate the top bar from the toolbar
            Divider()
            
            // Design toolbar full width below top bar - moved inside its own VStack to ensure it stays visible
            VStack(spacing: 0) {
                DesignToolbar(selectedTool: $selectedTool)
                    .padding(.vertical, 8) // Increased padding for better spacing
                
                // Canvas dimensions indicator
                Text("Canvas: \(Int(canvasWidth))×\(Int(canvasHeight)) (HD 16:9)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
                
                Divider() // Add visual separator between toolbar and canvas
            }
            // Enforce that toolbar section doesn't expand or get pushed by canvas
            .frame(maxHeight: 90) // Increased fixed height for toolbar section
            .padding(.top, 4) // Add a little padding at the top to separate from TopBar
            
            // Main content area with canvas and inspector
            HStack(spacing: 0) {
                // Main canvas area - wrapped in a ScrollView to prevent overflow
                ScrollView([.horizontal, .vertical]) {
                    canvasContentView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Right sidebar with inspector
                if isInspectorVisible {
                    Divider()
                    inspectorView
                }
            }
            .layoutPriority(1) // Give this section priority to expand
            
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
    private var canvasContentView: some View {
        ZStack {
            // Grid background (bottom layer)
            GridBackground(showGrid: showGrid, gridSize: gridSize)
            
            // Canvas boundary indicator - made more visible with a thicker stroke
            Rectangle()
                .strokeBorder(Color.blue.opacity(0.7), lineWidth: 2.5, antialiased: true)
                .frame(width: canvasWidth, height: canvasHeight)
                .allowsHitTesting(false)
            
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
        // Add some padding for better visibility
        .padding(20)
        // Add a background with a subtle border to clearly show canvas area
        .background(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color(NSColor.windowBackgroundColor))
        )
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
                    // Removed constraint to canvas bounds
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
                    // Removed constraint to canvas bounds
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
                    // Removed constraint to canvas bounds
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
                Label("Center Content", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .keyboardShortcut(KeyEquivalent("a"), modifiers: [.command])
            
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
                                
                                // Calculate direct translation vector regardless of rotation
                                let translationX = value.location.x - value.startLocation.x
                                let translationY = value.location.y - value.startLocation.y
                                
                                // Calculate new position by adding translation directly to initial position
                                // This ignores the rotation of the element, ensuring consistent drag behavior
                                var newPosition = CGPoint(
                                    x: initialPosition.x + translationX,
                                    y: initialPosition.y + translationY
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
        let canvasElements = self.canvasElements // Capture canvasElements
        
        return Group {
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
                    self.canvasElements.append(newElement)
                    self.selectedElementId = newElement.id
                }
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Button(action: {
                // Delete the element
                self.canvasElements.removeAll(where: { $0.id == element.id })
                self.selectedElementId = nil
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
        return Group {
            Button(action: {
                // Edit text
                self.selectedElementId = element.id
                self.isEditingText = true
                self.editingText = element.text
            }) {
                Label("Edit Text", systemImage: "pencil")
            }
            
            Menu("Text Alignment") {
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .leading
                    }
                }) {
                    Label("Left", systemImage: "text.alignleft")
                }
                
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .center
                    }
                }) {
                    Label("Center", systemImage: "text.aligncenter")
                }
                
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .trailing
                    }
                }) {
                    Label("Right", systemImage: "text.alignright")
                }
            }
        }
    }
    
    // Element color options
    private func elementColorOptions(for element: CanvasElement) -> some View {
        return Menu("Color") {
            ForEach(["Red", "Blue", "Green", "Orange", "Purple", "Black"], id: \.self) { colorName in
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].color = colorForName(colorName)
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
        return Menu("Opacity") {
            ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { opacity in
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].opacity = opacity
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
            if self.isDrawingRectangle, let start = self.rectangleStartPoint, let current = self.rectangleCurrentPoint {
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: current.x - start.x, height: current.y - start.y)
            }
            
            // Preview of ellipse being drawn
            if self.isDrawingEllipse, let start = self.rectangleStartPoint, let current = self.rectangleCurrentPoint {
                Ellipse()
                    .stroke(Color.black, lineWidth: 1)
                    .frame(width: current.x - start.x, height: current.y - start.y)
            }
        }
    }
    
    // Inspector view component
    private var inspectorView: some View {
        Group {
            if let selectedElementId = self.selectedElementId, 
               let selectedElement = self.canvasElements.first(where: { $0.id == selectedElementId }) {
                InspectorView(
                    selectedElement: Binding<CanvasElement?>(
                        get: { selectedElement },
                        set: { newValue in
                            if let newValue = newValue, let index = self.canvasElements.firstIndex(where: { $0.id == selectedElementId }) {
                                self.canvasElements[index] = newValue
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

    // Helper method to handle text creation
    private func handleTextCreation(at location: CGPoint) {
        // Create text at the exact click location
        let newText = CanvasElement.text(at: location)
        canvasElements.append(newText)
        selectedElementId = newText.id
        isEditingText = true
        editingText = newText.text
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
            Task {
                await exportProject()
            }
        }
    }
    
    /// Export the project as a JSON file
    @MainActor
    private func exportProject() async {
        // Configure save panel for project file
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "msproj") ?? UTType.json]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Project"
        savePanel.message = "Choose a location to save your project file"
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = "Motion_Storyline_Project"
        
        // Show save panel
        let response = savePanel.runModal()
        
        if response != .OK {
            print("Project export cancelled")
            return
        }
        
        guard let outputURL = savePanel.url else {
            print("No output URL selected")
            return
        }
        
        // Create project data structure to export
        let projectData: [String: Any] = [
            "version": "1.0",
            "timestamp": Date().ISO8601Format(),
            "projectSettings": [
                "name": "Motion Storyline Project",
                "gridSize": gridSize,
                "showGrid": showGrid,
                "snapToGridEnabled": snapToGridEnabled,
                "timelineHeight": timelineHeight,
                "zoom": zoom
            ],
            "canvas": [
                "elements": canvasElements.map { element in
                    [
                        "id": element.id.uuidString,
                        "type": String(describing: element.type),
                        "position": [
                            "x": element.position.x,
                            "y": element.position.y
                        ],
                        "size": [
                            "width": element.size.width,
                            "height": element.size.height
                        ],
                        "color": [
                            "red": 0.5, // Simplified for now - would need real color components
                            "green": 0.5,
                            "blue": 0.5,
                            "alpha": 1.0
                        ],
                        "rotation": element.rotation,
                        "opacity": element.opacity,
                        "text": element.text,
                        "textAlignment": String(describing: element.textAlignment),
                        "displayName": element.displayName
                    ]
                }
            ],
            "animation": [
                "duration": animationController.duration,
                "tracks": animationController.getAllTracksWithKeyframes().map { track in
                    [
                        "id": track.id,
                        "keyframes": track.keyframes.map { keyframe in
                            [
                                "time": keyframe.time,
                                "value": String(describing: keyframe.anyValue)
                            ]
                        }
                    ]
                }
            ]
        ]
        
        do {
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: projectData, options: .prettyPrinted)
            
            // Write to file
            try jsonData.write(to: outputURL)
            
            // Get file size for the success message
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let fileSizeBytes = fileAttributes[.size] as? Int64 ?? 0
            let fileSizeKB = Double(fileSizeBytes) / 1024.0
            let formattedSize = String(format: "%.1f KB", fileSizeKB)
            
            // Show success message and open containing folder
            DispatchQueue.main.async {
                // Show a success notification
                let center = UNUserNotificationCenter.current()
                
                // Create notification content
                let content = UNMutableNotificationContent()
                content.title = "Project Exported"
                content.body = "Project successfully exported to \(outputURL.lastPathComponent) (\(formattedSize))"
                content.sound = .default
                
                // Create a notification request
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                
                // Add request to notification center
                center.add(request) { error in
                    if let error = error {
                        print("Error showing notification: \(error.localizedDescription)")
                    }
                }
                
                // Reveal in Finder
                NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: "")
            }
        } catch let error as NSError {
            // Handle specific error types
            print("Error exporting project: \(error.localizedDescription)")
            
            DispatchQueue.main.async {
                // Show error alert with more specific information
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                
                // Customize error message based on error type
                switch error.domain {
                case NSCocoaErrorDomain:
                    switch error.code {
                    case NSFileWriteNoPermissionError:
                        alert.informativeText = "You don't have permission to save to this location. Try choosing a different folder."
                    case NSFileWriteOutOfSpaceError:
                        alert.informativeText = "Not enough disk space to save the project file."
                    case NSFileWriteVolumeReadOnlyError:
                        alert.informativeText = "The disk is read-only. Choose a different location."
                    default:
                        alert.informativeText = "Failed to write the project file: \(error.localizedDescription)"
                    }
                default:
                    if error.localizedDescription.contains("JSON") {
                        alert.informativeText = "Failed to create project data. Some elements may contain invalid values."
                    } else {
                        alert.informativeText = "Failed to export project: \(error.localizedDescription)"
                    }
                }
                
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                
                // Add a button to retry
                if error.domain != NSCocoaErrorDomain || error.code != NSFileWriteOutOfSpaceError {
                    alert.addButton(withTitle: "Try Again")
                    if alert.runModal() == .alertSecondButtonReturn {
                        // User clicked "Try Again", so call the export function again
                        Task {
                            await self.exportProject()
                        }
                        return
                    }
                } else {
                    alert.runModal()
                }
            }
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
                                default:           return 2 // Default to 720p
                            }
                        },
                        set: { newValue in
                            switch newValue {
                                case 0: exportResolution = (3840, 2160) // 4K
                                case 1: exportResolution = (1920, 1080) // 1080p
                                case 2: exportResolution = (1280, 720)  // 720p
                                default: exportResolution = (1280, 720) // Default to 720p
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
        
        // Get window information for debugging
        if NSApplication.shared.keyWindow != nil {
            print("Debug: Found keyWindow")
        } else if NSApplication.shared.mainWindow != nil {
            print("Debug: Found mainWindow")
        } else if NSApplication.shared.windows.count > 0 {
            print("Debug: Found at least one window")
        }
        
        // Show save panel as a separate modal dialog, not as a sheet
        print("Debug: About to display save panel")
        let response = savePanel.runModal()
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

            // Add a fallback timer to ensure progress doesn't stall
            let progressFallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                if !self.isExporting {
                    timer.invalidate()
                    return
                }
                
                // If progress hasn't changed in the last 3 seconds, increment it slightly
                // to show the user that export is still working
                if self.exportProgress < 0.95 {
                    // Store the last time we saw progress change
                    let progressIncrement: Float = 0.01
                    self.exportProgress = min(0.95, self.exportProgress + progressIncrement)
                }
            }

            // Export the video with detailed error handling
            await exporter.export(with: configuration, progressHandler: { progress in
                // Direct progress updates from exporter will be handled here as a fallback
                // Ensure we're not getting stuck by applying the progress directly
                DispatchQueue.main.async {
                    self.exportProgress = max(self.exportProgress, progress)
                }
            }, completion: { [self] result in
                // Remove observers when done
                NotificationCenter.default.removeObserver(progressObserver)
                progressFallbackTimer.invalidate()
                
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
                        // Set progress to 1.0 even on failure so it doesn't appear stuck
                        self.exportProgress = 1.0
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
        
        // Scale factor for positioning elements - use canvas dimensions
        let scaleFactor = min(
            CGFloat(width) / canvasWidth,
            CGFloat(height) / canvasHeight
        )
        
        // Center offset to position elements in the center of the frame
        let xOffset = (CGFloat(width) - canvasWidth * scaleFactor) / 2
        let yOffset = (CGFloat(height) - canvasHeight * scaleFactor) / 2
        
        // Draw each element
        for element in canvasElements {
            let scaledSize = CGSize(
                width: element.size.width * scaleFactor,
                height: element.size.height * scaleFactor
            )
            
            let scaledPosition = CGPoint(
                x: element.position.x * scaleFactor + xOffset,
                y: element.position.y * scaleFactor + yOffset
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
            var lastReportTime: CFTimeInterval = CACurrentMediaTime()
            
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
                            
                            // Calculate progress based on frames processed
                            let currentProgress = Float(frameIdx + 1) / Float(frameCount)
                            let currentTime = CACurrentMediaTime()
                            
                            // Send progress updates:
                            // 1. When progress changes by at least 1%
                            // 2. OR when at least 0.5 seconds have passed since last update
                            // 3. BUT limit maximum update frequency to avoid overwhelming the main thread
                            if currentProgress - lastReportedProgress > 0.01 || 
                               currentTime - lastReportTime > 0.5 {
                                
                                // Ensure we're not sending progress updates too frequently
                                if currentTime - lastReportTime > 0.1 {
                                    DispatchQueue.main.async {
                                        NSApp.mainWindow?.contentViewController?.view.window?.isDocumentEdited = true
                                        NotificationCenter.default.post(
                                            name: Notification.Name("ExportProgressUpdate"),
                                            object: nil,
                                            userInfo: ["progress": currentProgress]
                                        )
                                    }
                                    lastReportedProgress = currentProgress
                                    lastReportTime = currentTime
                                }
                            }
                        } else {
                            // If appending fails, report the error and signal completion
                            print("Debug: Failed to append pixel buffer - \(assetWriter.error?.localizedDescription ?? "unknown error")")
                            semaphore.signal()
                            return
                        }
                    }
                }
            }
            
            // Send final progress update of 100% for this stage
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("ExportProgressUpdate"),
                    object: nil,
                    userInfo: ["progress": Float(0.95)] // Leave some progress for finalization
                )
            }
            
            // Finish writing - this should be outside the loop
            writerInput.markAsFinished()
            
            // Signal that we're done writing frames
            semaphore.signal()
        }
        
        // Wait for media writing to complete in a non-blocking way
        // This uses DispatchGroup instead of direct semaphore.wait() to avoid Swift 6 async context issues
        let group = DispatchGroup()
        group.enter()
        
        mediaQueue.async {
            // This runs on mediaQueue, not in the async context
            _ = semaphore.wait(timeout: .distantFuture)
            group.leave()
        }
        
        // Convert DispatchGroup to async/await
        _ = await withCheckedContinuation { continuation in
            group.notify(queue: .main) {
                continuation.resume(returning: true)
            }
        }
        
        // Check for any errors after processing is complete
        if let error = assetWriter.error {
            throw NSError(domain: "MotionStoryline", code: 105, userInfo: [NSLocalizedDescriptionKey: "Failed to create video: \(error.localizedDescription)"])
        }
        
        // Return the final asset
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

// MARK: - Key Event Monitor Controller
// Separate class to handle key event monitoring
class KeyEventMonitorController: ObservableObject {
    private var keyEventMonitor: Any?
    
    func setupMonitor(onSpaceDown: @escaping () -> Void, onSpaceUp: @escaping () -> Void) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            // Check for space bar
            if event.keyCode == 49 { // 49 is the keycode for space
                if event.type == .keyDown {
                    onSpaceDown()
                } else if event.type == .keyUp {
                    onSpaceUp()
                }
            }
            
            return event
        }
    }
    
    func teardownMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    deinit {
        teardownMonitor()
    }
}
