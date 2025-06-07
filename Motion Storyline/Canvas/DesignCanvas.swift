import SwiftUI
import Combine
import Foundation
import AppKit
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import CoreText
import UserNotifications
// Add import for haptic feedback
import os.log
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
// - Canvas/CanvasExport.swift: Export functionality
// - Canvas/DesignCanvas+ContextMenus.swift: Context menu extensions
// - Canvas/DesignCanvas+ProjectSave.swift: Project save functionality
// - Utilities/KeyEventMonitorController.swift: Keyboard event handling

// Note: ElementType is defined in CanvasElement.swift
// Do not create duplicate definitions

struct DesignCanvas: View {
@State internal var canvasElements: [CanvasElement] = [
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
    @State internal var zoom: CGFloat = 1.0
    @State private var showZoomIndicator: Bool = false
    // Timeline specific zoom and offset state
    @State private var timelineScale: Double = 1.0
    @State private var timelineOffset: Double = 0.0
    @State internal var selectedTool: DesignTool = .select
    @State private var isInspectorVisible = true
    
    // State for viewport dragging with space bar
    @State private var isSpaceBarPressed: Bool = false
    @State internal var viewportOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint?
    @State internal var isEditingText = false
    @State internal var editingText: String = ""
    @State internal var currentMousePosition: CGPoint?
    @State private var draggedElementId: UUID?
    @State private var initialDragElementPosition: CGPoint?
    @State internal var selectedElementId: UUID?
    @State private var selectedElement: CanvasElement?
    
    // Drawing state variables
    @State private var isDrawingRectangle = false
    @State private var isDrawingEllipse = false
    @State private var rectangleStartPoint: CGPoint?
    @State private var rectangleCurrentPoint: CGPoint?
    @State private var isBreakingAspectRatio = false
    @State private var aspectRatioInfoVisible = false
    
    // Grid settings that will be passed to CanvasContentView
    @State internal var showGrid: Bool = true
    @State internal var gridSize: CGFloat = 20
    @State internal var snapToGridEnabled: Bool = true
    
    // Navigation state
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject internal var appState: AppStateManager
    
    // Animation controller
    @StateObject internal var animationController = AnimationController()
    @State private var isPlaying = false
    @State private var selectedProperty: String?
    @State private var timelineHeight: CGFloat = 120 // Changed from 400 to 120 (approx 2x play/pause bar height)
    @State private var showAnimationPreview: Bool = true // Control if animation preview is shown
    
    // Export state
    @State internal var isExporting = false
    @State internal var exportProgress: Float = 0
    @State internal var exportFormat: ExportFormat = .video
    @State private var showExportSettings = false
    @State private var exportResolution: (width: Int, height: Int) = (1280, 720) // Default to HD
    @State private var exportFrameRate: Float = 30.0
    @State private var exportDuration: Double = 5.0
    @State internal var exportingError: Error?
    
    // Key event monitor for tracking space bar
    @StateObject private var keyMonitorController = KeyEventMonitorController()
    
    // Canvas dimensions - HD aspect ratio (16:9)
    @State internal var canvasWidth: CGFloat = 1280
    @State internal var canvasHeight: CGFloat = 720
    
    // State variables for path drawing
    @State private var isDrawingPath: Bool = false
    @State private var pathPoints: [CGPoint] = []
    @State private var currentPathPoint: CGPoint? = nil
    
    // Media management
    @State private var showMediaBrowser = false
    @State private var showCameraView = false
    
    // Export modal state
    @State internal var showingExportModal = false
    
    // Before the handleExportRequest method, add these properties:
    @State private var showBatchExportSettings = false
    
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
    
    // Sample keyframes for demonstration
    let keyframes: [(String, Double, Double)] = [
        ("opacity", 0.0, 0.0),
        ("opacity", 1.0, 0.5),
        ("opacity", 0.0, 1.0),
        ("scale", 1.0, 0.0),
        ("scale", 1.5, 0.5),
        ("scale", 1.0, 1.0)
    ]
    
    // Add this property to store the current AVAsset for export
    @State internal var currentExportAsset: AVAsset?
    
    // Add the missing state variables
    @State private var isCreatingElement: Bool = false
    @State private var dragStartPoint: CGPoint?
    
    // Document manager for saving/exporting
    internal let documentManager = DocumentManager()
    @State private var currentDragPoint: CGPoint?
    @State private var showOnboarding: Bool = false
    @State internal var isProgrammaticChange: Bool = false
    @StateObject internal var undoRedoManager = UndoRedoManager()
    
    // MARK: - Main View

    // MARK: - File Operations
    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "storyline")].compactMap { $0 }

        if panel.runModal() == .OK {
            if let url = panel.url {
                print("Attempting to open project file: \(url.path)")
                do {
                    if let loadedData = try documentManager.loadProject(from: url) {
                        self.canvasElements = loadedData.elements
                        self.canvasWidth = loadedData.canvasWidth
                        self.canvasHeight = loadedData.canvasHeight

                        // Update project name in AppState
                        if self.appState.selectedProject != nil {
                            self.appState.selectedProject?.name = loadedData.projectName
                        } else {
                            print("Warning: No project currently selected in AppState. Project name from file not set.")
                        }

                        // Reset and re-populate the existing animationController
                        self.animationController.reset() // Clear existing tracks and data
                        self.animationController.setup(duration: loadedData.duration)

                        // Recreate animation tracks
                        for trackData in loadedData.tracksData {
                            let components = trackData.id.split(separator: "_", maxSplits: 1)
                            guard components.count == 2, let elementID = UUID(uuidString: String(components[0])) else {
                                print("Warning: Could not parse trackId \(trackData.id) into elementID and propertyName.")
                                continue
                            }
                            let propertyName = String(components[1])

                            guard let elementIndex = self.canvasElements.firstIndex(where: { $0.id == elementID }) else {
                                print("Warning: Element with ID \(elementID) not found for track \(trackData.id).")
                                continue
                            }

                            switch trackData.valueType {
                            case "Double":
                                let newTrack = self.animationController.addTrack(id: trackData.id) { (newValue: Double) in
                                    if self.canvasElements.indices.contains(elementIndex) {
                                        switch propertyName {
                                        case "opacity": self.canvasElements[elementIndex].opacity = newValue
                                        case "scale": self.canvasElements[elementIndex].scale = CGFloat(newValue) // Assuming scale is CGFloat
                                        case "rotation": self.canvasElements[elementIndex].rotation = newValue // Assign Double directly
                                        default: print("Warning: Update callback for Double property \(propertyName) not implemented.")
                                        }
                                    }
                                }
                                for keyframeData in trackData.keyframes {
                                    if let value = Double(keyframeData.value) {
                                        let easing = EasingFunction.linear // Default easing as placeholder
                                        newTrack.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                                    } else {
                                        print("Warning: Could not parse Double for keyframe value: \(keyframeData.value) in track \(trackData.id)")
                                    }
                                }
                            case "CGPoint":
                                let newTrack = self.animationController.addTrack(id: trackData.id) { (newValue: CGPoint) in
                                    if self.canvasElements.indices.contains(elementIndex) {
                                        if propertyName == "position" {
                                            self.canvasElements[elementIndex].position = newValue
                                        } else {
                                            print("Warning: Update callback for CGPoint property \(propertyName) not implemented.")
                                        }
                                    }
                                }
                                for keyframeData in trackData.keyframes {
                                    do {
                                        let value = try CanvasElement.decodeCGPoint(from: keyframeData.value)
                                        let easing = EasingFunction.linear // Default easing as placeholder
                                        newTrack.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                                    } catch {
                                        print("Warning: Could not parse CGPoint for keyframe value: \(keyframeData.value) in track \(trackData.id). Error: \(error.localizedDescription)")
                                    }
                                }
                            case "CGSize":
                                let newTrack = self.animationController.addTrack(id: trackData.id) { (newValue: CGSize) in
                                    if self.canvasElements.indices.contains(elementIndex) {
                                        if propertyName == "size" { // Assuming 'size' is the property name for CGSize
                                            self.canvasElements[elementIndex].size = newValue
                                        } else {
                                            print("Warning: Update callback for CGSize property \(propertyName) not implemented.")
                                        }
                                    }
                                }
                                for keyframeData in trackData.keyframes {
                                    do {
                                        let value = try CanvasElement.decodeCGSize(from: keyframeData.value)
                                        let easing = EasingFunction.linear // Default easing as placeholder
                                        newTrack.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                                    } catch {
                                        print("Warning: Could not parse CGSize for keyframe value: \(keyframeData.value) in track \(trackData.id). Error: \(error.localizedDescription)")
                                    }
                                }
                            // Add cases for other supported ValueTypes (e.g., Color) here
                            default:
                                print("Warning: Unsupported track valueType '\(trackData.valueType)' for track \(trackData.id) during project load.")
                            }
                        }
                        self.animationController.objectWillChange.send() // Notify UI after updates
                        
                        // Perform any other necessary UI updates or state resets
                        self.selectedElementId = nil
                        self.zoom = 1.0
                        self.viewportOffset = .zero
                        print("Project loaded successfully: \(loadedData.projectName)")
                    }
                } catch {
                    print("Error loading project from DesignCanvas: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Zoom Control Functions
    
    // Zoom control functions
    internal func zoomIn() {
        zoom = min(zoom * 1.25, 5.0) // Increase zoom by 25%, max 5x
        showTemporaryZoomIndicator()
    }
    
    internal func zoomOut() {
        zoom = max(zoom * 0.8, 0.1) // Decrease zoom by 20%, min 0.1x
        showTemporaryZoomIndicator()
    }
    
    internal func resetZoom() {
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
        ZStack {
            mainContentView
        }
        // Add command handlers for saving
        .onCommand(#selector(NSDocument.save(_:))) {
            // Save project implementation
            print("Save command triggered")
        }
    }
    
    // MARK: - View Components
    
    private var mainContentView: some View {
        return VStack(spacing: 0) {
            // Top navigation bar
            CanvasTopBar(
                projectName: appState.selectedProject?.name ?? "Motion Storyline",
                onClose: {
                    // Close the canvas and return to project selection
                    appState.selectedProject = nil
                    appState.navigateToHome()
                },
                onCameraRecord: {
                    showCameraView = true
                },
                onMediaLibrary: {
                    showMediaBrowser = true
                },
                showAnimationPreview: $showAnimationPreview,
                onExport: { format in
                    self.exportFormat = format
                    // Handle export placeholder
                    print("Export requested with format: \(format)")
                },
                onAccountSettings: {
                    print("Account settings")
                },
                onHelpAndSupport: {
                    print("Help and support")
                },
                onCheckForUpdates: {
                    print("Check for updates")
                },
                onSignOut: {
                    print("Sign out")
                },
                onCut: { print("Cut action") },
                onCopy: { print("Copy action") },
                onPaste: { print("Paste action") },
                showGrid: Binding<Bool>(get: { self.showGrid }, set: { self.showGrid = $0 }),
                showRulers: Binding<Bool>(get: { true }, set: { _ in }),  // Placeholder binding
                onSave: {
                    print("Save action triggered")
                },
                onSaveAs: {
                    print("Save As action triggered")
                },
                onOpenProject: openProject,
                onZoomIn: zoomIn,
                onZoomOut: zoomOut,
                onZoomReset: resetZoom,
                documentManager: documentManager,
                liveCanvasElements: { self.canvasElements },
                liveAnimationController: { self.animationController },
                canvasWidth: Int(canvasWidth),
                canvasHeight: Int(canvasHeight)
            )
            .environmentObject(UndoRedoManager())
            
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
                    InspectorView(
                        selectedElement: $selectedElement,
                        onClose: {
                            isInspectorVisible = false
                        }
                    )
                }
            }
            .layoutPriority(1) // Give this section priority to expand
            
            // Timeline area at the bottom (if needed)
            if showAnimationPreview {
                TimelineViewPanel(
                    animationController: animationController,
                    isPlaying: $isPlaying,
                    timelineHeight: $timelineHeight,
                    timelineOffset: $timelineOffset,
                    selectedElement: $selectedElement,
                    timelineScale: $timelineScale
                )
            }
        }
        .accessibilityIdentifier("editor-view")
        .onAppear {
            // Setup key monitor for space bar panning
            keyMonitorController.setupMonitor(
                onSpaceDown: {
                    // When space bar is pressed, change cursor and enable pan mode
                    isSpaceBarPressed = true
                    NSCursor.openHand.set()
                },
                onSpaceUp: {
                    // When space bar is released, restore cursor and disable pan mode
                    isSpaceBarPressed = false
                    // Reset to default cursor based on current tool
                    if selectedTool == .select {
                        NSCursor.arrow.set()
                    } else if selectedTool == .rectangle || selectedTool == .ellipse {
                        NSCursor.crosshair.set()
                    } else if selectedTool == .path {
                        NSCursor.crosshair.set()
                    }
                }
            )
            
            // Setup canvas keyboard shortcuts
            keyMonitorController.setupCanvasKeyboardShortcuts(
                zoomIn: zoomIn,
                zoomOut: zoomOut,
                resetZoom: resetZoom,
                saveProject: { print("Save project action triggered") }
            )
            
            // Setup initial animations (if present)
            setupInitialAnimations()
        }
        .onChange(of: selectedElementId) { oldValue, newValue in
            // Update selectedElement based on the selected ID
            if let elementId = newValue {
                selectedElement = canvasElements.first(where: { $0.id == elementId })
            } else {
                selectedElement = nil
            }
        }
        .onChange(of: selectedElement) { oldValue, newValue in
            // Update the corresponding element in canvasElements when selectedElement is modified
            print("Selected element changed: \(String(describing: newValue))")
            
            if let updatedElement = newValue,
               let index = canvasElements.firstIndex(where: { $0.id == updatedElement.id }) {
                // Update the element in the canvas elements array
                canvasElements[index] = updatedElement
                
                // Record undo state for property changes
                recordUndoState(actionName: "Update Element Properties")
            }
        }
        .onDisappear {
            // Teardown key monitor when view disappears
            keyMonitorController.teardownMonitor()
        }
        // Add the ExportModal sheet here
        .sheet(isPresented: $showingExportModal) {
            if let asset = currentExportAsset {
                ExportModal(
                    asset: asset,
                    canvasWidth: Int(canvasWidth),
                    canvasHeight: Int(canvasHeight),
                    getAnimationController: { self.animationController },
                    getCanvasElements: { self.canvasElements },
                    onDismiss: {
                        showingExportModal = false
                    }
                )
            }
        }
        // Add CameraRecordingView sheet for camera button
        .sheet(isPresented: $showCameraView) {
            CameraRecordingView(isPresented: $showCameraView)
                .frame(width: 480, height: 360)
        }
        // Add MediaBrowserView sheet for media button
        .sheet(isPresented: $showMediaBrowser) {
            let projectBinding = Binding<Project>(
                get: { appState.selectedProject ?? Project(name: "Untitled", thumbnail: "placeholder", lastModified: Date()) },
                set: { appState.selectedProject = $0 }
            )
            MediaBrowserView(project: projectBinding, onAddElementToCanvas: { newElement in
                canvasElements.append(newElement)
                handleElementSelection(newElement)
            })
                .frame(width: 800, height: 600)
        }
        .overlay {
            // Show export progress overlay when exporting
            if isExporting {
                // Export progress view placeholder
                VStack {
                    ProgressView(value: exportProgress)
                        .padding()
                    Text("Exporting... \(Int(exportProgress * 100))%")
                }
                .frame(width: 200)
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    // MARK: - View Components
    
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
                    onTap: { tappedElement in
                        if selectedTool == .select {
                            handleElementSelection(tappedElement)
                        }
                    },
                    isTemporary: false,
                    isDragging: element.id == draggedElementId,
                    currentTime: animationController.currentTime
                )
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
                                    
                                    // Update the element's position
                                    canvasElements[index].position = newPosition
                                }
                            }
                        }
                        .onEnded { _ in
                            // Reset drag state
                            draggedElementId = nil
                            initialDragElementPosition = nil
                        }
                )
            }
            
            // Drawing previews
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
                
                // Preview of path being drawn
                if self.isDrawingPath && pathPoints.count > 1 {
                    Path { path in
                        path.move(to: pathPoints.first!)
                        
                        for point in pathPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        
                        if let currentPoint = currentPathPoint {
                            path.addLine(to: currentPoint)
                        }
                    }
                    .stroke(Color.purple, lineWidth: 2)
                }
            }
            
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
        // Add the drag gesture for viewport panning
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Pan when using select tool or when space bar is pressed (temporary pan tool)
                    if selectedTool == .select || isSpaceBarPressed {
                        // Change cursor to closed hand during drag
                        if isSpaceBarPressed {
                            NSCursor.closedHand.set()
                        }
                        
                        viewportOffset = CGSize(
                            width: viewportOffset.width + value.translation.width,
                            height: viewportOffset.height + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    // Reset cursor to open hand when drag ends but space is still pressed
                    if isSpaceBarPressed {
                        NSCursor.openHand.set()
                    }
                }
        )
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
                    // Create text at the exact click location
                    let newText = CanvasElement.text(at: location)
                    canvasElements.append(newText)
                    handleElementSelection(newText)
                    isEditingText = true
                    editingText = newText.text
                } else if selectedTool == .select {
                    // Deselect the current element when clicking on empty canvas area
                    selectedElementId = nil
                } else if selectedTool == .path {
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
                } else {
                    // Update currentMousePosition but don't change cursor when not hovering
                    if isSpaceBarPressed {
                        // When space bar is pressed, show the hand cursor
                        NSCursor.openHand.set()
                    } else if selectedTool == .select {
                        // Change cursor to arrow when in selection mode
                        NSCursor.arrow.set()
                    } else if selectedTool == .rectangle || selectedTool == .ellipse {
                        // Change cursor to crosshair when in shape drawing mode
                        NSCursor.crosshair.set()
                    } else if selectedTool == .path {
                        // Change cursor to pen when in path drawing mode
                        NSCursor.crosshair.set()
                    }
                }
            }
            .gesture(canvasDrawingGesture)
    }
    
    // Canvas context menu content is now in DesignCanvas+ContextMenus.swift
    
    // Grid settings submenu
    private var gridSettingsMenuOriginal: some View {
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
    
    // Canvas drawing gesture
    private var canvasDrawingGesture: some Gesture {
        if selectedTool == .rectangle {
            return AnyGesture(
                DragGesture(minimumDistance: 4)
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
                            handleElementSelection(newRectangle)
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
                }
            )
        } else if selectedTool == .ellipse {
            return AnyGesture(
                DragGesture(minimumDistance: 4)
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
                            handleElementSelection(newEllipse)
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
                }
            )
        } else if selectedTool == .path {
            return AnyGesture(
                DragGesture(minimumDistance: 2)
                .onChanged { value in
                    // Start path drawing if not already started
                    if !isDrawingPath {
                        isDrawingPath = true
                        pathPoints = [value.startLocation]
                    }
                    
                    // Add current point to path
                    pathPoints.append(value.location)
                    currentPathPoint = value.location
                }
                .onEnded { value in
                    // Finalize path
                    if isDrawingPath && pathPoints.count > 1 {
                        // Create path element
                        let path = CanvasElement.path(
                            at: pathPoints.first ?? CGPoint.zero,
                            points: pathPoints
                        )
                        
                        // Add the path to the canvas
                        canvasElements.append(path)
                        
                        // Select the new path
                        handleElementSelection(path)
                    }
                    
                    // Reset path drawing state
                    isDrawingPath = false
                    pathPoints = []
                    currentPathPoint = nil
                }
            )
        } else {
            return AnyGesture(DragGesture().onChanged { _ in }.onEnded { _ in })
        }
    }
    
    // Helper function to calculate constrained rectangle
    private func calculateConstrainedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        
        let finalWidth: CGFloat
        let finalHeight: CGFloat
        
        if isBreakingAspectRatio {
            // Maintain aspect ratio (square)
            let size = min(width, height)
            finalWidth = size
            finalHeight = size
        } else {
            finalWidth = width
            finalHeight = height
        }
        
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        
        return CGRect(x: x, y: y, width: finalWidth, height: finalHeight)
    }
    
    // MARK: - Project Data Management
    
    internal func applyProjectData(projectData: ProjectData) {
        print("Project loaded successfully. Applying data...")
        isProgrammaticChange = true // Prevent marking as changed during state restoration

        // Apply loaded data
        self.canvasElements = projectData.elements
        self.canvasWidth = projectData.canvasWidth
        self.canvasHeight = projectData.canvasHeight
        
        // Rebuild AnimationController state
        self.animationController.reset()
        self.animationController.setup(duration: projectData.duration)
        // TODO: Reconstruct animation tracks and keyframes from projectData.tracksData
        // This requires mapping trackData.propertyName and trackData.valueType to actual types
        // and correctly setting up the updateCallback for each track.

        // Configure DocumentManager with the newly loaded state and URL
        // Note: documentManager.currentProjectURL is already set by loadProject(from:)
        configureDocumentManager()

        // Update AppState
        if let currentURL = documentManager.currentProjectURL {
            appState.currentProjectName = currentURL.deletingPathExtension().lastPathComponent
            print("Project name set to: \(appState.currentProjectName)")
        }
        appState.currentProjectURLToLoad = nil // Clear the request to load this URL

        // Reset UI states
        self.selectedElementId = nil
        self.zoom = 1.0
        self.viewportOffset = .zero
        self.appState.currentTimelineScale = 1.0 // Reset timeline zoom
        self.appState.currentTimelineOffset = 0.0 // Reset timeline offset

        self.undoRedoManager.clearHistory() // Clear undo/redo history for the newly loaded project
        self.documentManager.hasUnsavedChanges = false // A freshly loaded project has no unsaved changes

        self.isProgrammaticChange = false // Reset programmatic change flag
        print("Project data applied and UI reset for loaded project.")
    }
    
    internal func configureDocumentManager() {
        documentManager.configure(
            canvasElements: self.canvasElements,
            animationController: self.animationController,
            canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight)
        )
        print("DocumentManager configured with current canvas state. URL: \(documentManager.currentProjectURL?.path ?? "None")")
    }
    
    internal func recordUndoState(actionName: String) {
        // Create current state data for undo
        let currentState = ProjectState(
            canvasElements: canvasElements,
            animationControllerState: Data(), // TODO: Serialize animation controller state
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight)
        )
        
        if let stateData = try? JSONEncoder().encode(currentState) {
            undoRedoManager.addUndoState(stateBeforeOperation: stateData)
        }
    }
    
    // MARK: - Element Selection
    
    /// Handles element selection when an element is tapped
    internal func handleElementSelection(_ element: CanvasElement) {
        print("Element selected: \(element.displayName)")
        
        // Update selected element state
        selectedElementId = element.id
        selectedElement = element
        
        // If the selected element is a text element, start editing
        if element.type == .text {
            isEditingText = true
            editingText = element.text
        } else {
            isEditingText = false
        }
        
        // Update inspector and animation data
        updateAnimationPropertiesForSelectedElement(selectedElement)
        
        // Force UI update by triggering objectWillChange
        isProgrammaticChange = true
        isProgrammaticChange = false
    }
    
    // MARK: - Animation Property Management
    
    /// Updates the animation properties when an element is selected
    func updateAnimationPropertiesForSelectedElement(_ element: CanvasElement?) {
        guard let element = element else { return }
        
        print("Updating animation properties for: \(element.displayName)")
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        // Capture self strongly for use in closures
        let canvas = self
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        if canvas.animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = canvas.animationController.addTrack(id: positionTrackId) { [canvas] (newPosition: CGPoint) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].position = newPosition
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.position))
        }
        
        // Size track (using width as the animatable property for simplicity)
        let sizeTrackId = "\(idPrefix)_size"
        if canvas.animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> == nil {
            let track = canvas.animationController.addTrack(id: sizeTrackId) { [canvas] (newSize: CGSize) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    // If aspect ratio is locked, maintain it
                    if canvas.canvasElements[index].isAspectRatioLocked {
                        let ratio = canvas.canvasElements[index].size.height / canvas.canvasElements[index].size.width
                        canvas.canvasElements[index].size = CGSize(width: newSize.width, height: newSize.width * ratio)
                    } else {
                        canvas.canvasElements[index].size = newSize
                    }
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.size))
        }
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        if canvas.animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = canvas.animationController.addTrack(id: rotationTrackId) { [canvas] (newRotation: Double) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].rotation = newRotation
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
        }
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        if canvas.animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = canvas.animationController.addTrack(id: colorTrackId) { [canvas] (newColor: Color) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].color = newColor
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.color))
        }
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        if canvas.animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = canvas.animationController.addTrack(id: opacityTrackId) { [canvas] (newOpacity: Double) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].opacity = newOpacity
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
        }
        
        // Path track - only for path elements
        if element.type == .path {
            let pathTrackId = "\(idPrefix)_path"
            if canvas.animationController.getTrack(id: pathTrackId) as? KeyframeTrack<[CGPoint]> == nil {
                let track = canvas.animationController.addTrack(id: pathTrackId) { [canvas] (newPath: [CGPoint]) in
                    if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvas.canvasElements[index].path = newPath
                    }
                }
                // Add initial keyframe at time 0
                track.add(keyframe: Keyframe(time: 0.0, value: element.path))
            }
        }
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

// Add accessibility identifier for UI testing
extension DesignCanvas {
    func withUITestIdentifier() -> some View {
        self
            .accessibilityIdentifier("editor-view")
    }
}

// MARK: - Export Helpers
// Export helpers are implemented in DesignCanvas+ExportHelpers.swift