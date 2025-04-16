import SwiftUI
import AppKit
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import UniformTypeIdentifiers
import Foundation
import UserNotifications
// Add import for haptic feedback
import Foundation

// Import for haptic feedback
import Foundation

@preconcurrency import UniformTypeIdentifiers
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
    @State private var timelineHeight: CGFloat = 120 // Changed from 400 to 120 (approx 2x play/pause bar height)
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
    
    // State variables for path drawing
    @State private var isDrawingPath: Bool = false
    @State private var pathPoints: [CGPoint] = []
    @State private var currentPathPoint: CGPoint? = nil
    
    // Media management
    @State private var showMediaBrowser = false
    @State private var showCameraView = false
    
    // Export modal state
    @State private var showingExportModal = false
    
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
    @State private var currentExportAsset: AVAsset?
    
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
        VStack(spacing: 0) {
            // Top navigation bar
            CanvasTopBar(
                projectName: appState.selectedProject?.name ?? "Motion Storyline",
                onClose: {
                    appState.navigateToHome()
                },
                onNewFile: {
                    print("New file action triggered")
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
                    handleExportRequest(format: format)
                },
                onAccountSettings: {
                    print("Account settings action triggered")
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
                onZoomReset: resetZoom,
                // Pass the canvas dimensions for export
                canvasWidth: Int(canvasWidth),
                canvasHeight: Int(canvasHeight)
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
                resetZoom: resetZoom
            )
            
            // Setup initial animations (if present)
            setupInitialAnimations()
        }
        .onChange(of: selectedElement) { oldValue, newValue in
            // ... existing onChange code ...
            
            // Update animation properties for the selected element
            updateAnimationPropertiesForSelectedElement(newValue)
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
                    onDismiss: {
                        showingExportModal = false
                    }
                )
            }
        }
        
        // Export sheet
        if showExportSettings {
            // ... existing export sheet code ...
        }
        
        // Show export progress overlay when exporting
        if isExporting {
            exportProgressView
        }
    }
    
    // MARK: - View Components
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            CanvasTopBar(
                projectName: appState.selectedProject?.name ?? "Motion Storyline",
                onClose: {
                    appState.navigateToHome()
                },
                onNewFile: {
                    print("New file action triggered")
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
                    handleExportRequest(format: format)
                },
                onAccountSettings: {
                    print("Account settings action triggered")
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
                onZoomReset: resetZoom,
                // Pass the canvas dimensions for export
                canvasWidth: Int(canvasWidth),
                canvasHeight: Int(canvasHeight)
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
        // Add the ExportModal sheet here
        .sheet(isPresented: $showingExportModal) {
            if let asset = currentExportAsset {
                ExportModal(
                    asset: asset,
                    canvasWidth: Int(canvasWidth),
                    canvasHeight: Int(canvasHeight),
                    onDismiss: {
                        showingExportModal = false
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    // Define viewport drag gesture for panning the canvas
    private var viewportDragGesture: some Gesture {
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
    }
    
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
    
    // Canvas drawing gesture
    private var canvasDrawingGesture: some Gesture {
        selectedTool == .rectangle ? 
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
        selectedTool == .path ?
            DragGesture(minimumDistance: 2)
            .onChanged { value in
                // Start path drawing if not already started
                if !isDrawingPath {
                    isDrawingPath = true
                    pathPoints = [value.startLocation]
                }
                
                // Add the current point to the path
                pathPoints.append(value.location)
                currentPathPoint = value.location
            }
            .onEnded { value in
                // Finalize path
                if isDrawingPath {
                    // Only create path if it has enough points
                    if pathPoints.count > 2 {
                        // Calculate the bounds of the path to determine position and size
                        let xPoints = pathPoints.map { $0.x }
                        let yPoints = pathPoints.map { $0.y }
                        
                        let minX = xPoints.min() ?? 0
                        let maxX = xPoints.max() ?? 0
                        let minY = yPoints.min() ?? 0
                        let maxY = yPoints.max() ?? 0
                        
                        let width = max(50, maxX - minX)
                        let height = max(50, maxY - minY)
                        let center = CGPoint(x: minX + width / 2, y: minY + height / 2)
                        
                        // Normalize the points relative to the element's coordinate space (0-1)
                        let normalizedPoints = pathPoints.map { point in
                            CGPoint(
                                x: (point.x - minX) / width,
                                y: (point.y - minY) / height
                            )
                        }
                        
                        // Create path element
                        let newPath = CanvasElement.path(
                            at: center,
                            points: normalizedPoints
                        )
                        
                        // Set the size based on the path bounds
                        var mutablePath = newPath
                        mutablePath.size = CGSize(width: width, height: height)
                        
                        // Add the path to the canvas
                        canvasElements.append(mutablePath)
                        
                        // Select the new path
                        selectedElementId = mutablePath.id
                    }
                }
                
                // Reset path drawing state
                isDrawingPath = false
                pathPoints = []
                currentPathPoint = nil
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
                            // Provide play haptic feedback
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                        } else {
                            animationController.pause()
                            // Provide pause haptic feedback
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 30, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("p", modifiers: [])
                    .help(isPlaying ? "Pause Animation (P)" : "Play Animation (P)")
                    
                    Button(action: {
                        animationController.reset()
                        isPlaying = false
                        // Provide reset haptic feedback
                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                    }) {
                        Image(systemName: "stop.fill")
                            .frame(width: 30, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("r", modifiers: [])
                    .help("Reset Animation (R)")
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
        // Create the AVAsset for export if needed
        Task {
            do {
                // Show export progress while creating the composition
                DispatchQueue.main.async {
                    self.exportProgress = 0.01 // Show some initial progress
                    self.isExporting = true
                }
                
                // Create a composition with current canvas state
                let asset = try await createCompositionFromCanvas(
                    width: Int(canvasWidth),
                    height: Int(canvasHeight),
                    duration: animationController.duration,
                    frameRate: 30.0
                )
                
                // Update the asset for use in the export modal
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.currentExportAsset = asset
                    
                    // Now handle the export request
                    self.continueExportRequest(format: format)
                }
            } catch {
                print("Failed to create composition: \(error.localizedDescription)")
                // Show error alert
                DispatchQueue.main.async {
                    self.isExporting = false
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not create video composition from canvas: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Continue export after asset is prepared
    private func continueExportRequest(format: ExportFormat) {
        // Safety check - make sure we have a valid asset
        guard currentExportAsset != nil else {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not prepare content for export. Please try again with a different selection."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        // Ensure we're not showing the export progress indicator
        self.isExporting = false
        
        switch format {
        case .video:
            // Show the custom export modal which can handle all formats
            showingExportModal = true
        case .gif:
            // Show export modal for GIF
            showingExportModal = true
        case .imageSequence:
            // Show export modal for image sequence
            showingExportModal = true
        case .projectFile:
            Task {
                await exportProject()
            }
        case .batchExport:
            // Either show the export modal or batch export settings
            showingExportModal = true
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
                Text("Preparing Export...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ProgressView(value: exportProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 300)
                
                if exportProgress > 0 {
                    Text("\(Int(exportProgress * 100))%")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .monospacedDigit()
                } else {
                    ProgressView() // Show indeterminate spinner if no progress yet
                        .scaleEffect(0.8)
                        .padding(.top, 8)
                }
                
                Button("Cancel") {
                    // Cancel export
                    isExporting = false
                    
                    // Show cancellation message
                    let alert = NSAlert()
                    alert.messageText = "Export Cancelled"
                    alert.informativeText = "The export operation was cancelled."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
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
        // Check if we have elements to export
        if canvasElements.isEmpty {
            // Add a placeholder element if the canvas is empty
            // This ensures we can still create a valid video file
            var placeholderText = CanvasElement.text(
                at: CGPoint(x: Double(width)/2, y: Double(height)/2)
            )
            placeholderText.text = "Motion Storyline Export"
            placeholderText.size = CGSize(width: 500, height: 100)
            placeholderText.color = .black
            placeholderText.textAlignment = .center
            
            // Temporarily add the placeholder to canvas elements
            DispatchQueue.main.sync {
                canvasElements.append(placeholderText)
            }
        }
        
        // Create a video with animated frames
        let frameCount = Int(duration * Double(frameRate))
        
        // Ensure we have a valid duration
        if frameCount <= 0 || duration <= 0 {
            throw NSError(domain: "MotionStoryline", code: 102, userInfo: [NSLocalizedDescriptionKey: "Invalid export duration. Duration must be greater than 0."])
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let temporaryVideoURL = tempDir.appendingPathComponent("temp_canvas_\(UUID().uuidString).mov")
        
        // If a temporary file already exists, delete it
        if FileManager.default.fileExists(atPath: temporaryVideoURL.path) {
            try FileManager.default.removeItem(at: temporaryVideoURL)
        }
        
        // Helper function to properly convert SwiftUI Color to CGColor
        func convertToCGColor(_ color: Color) -> CGColor {
            // Convert through NSColor to ensure consistent color space
            let nsColor = NSColor(color)
            // Use sRGB color space for consistent rendering across canvas and export
            let colorInRGB = nsColor.usingColorSpace(.sRGB) ?? nsColor
            return colorInRGB.cgColor
        }
        
        // Store the current animation state
        let currentAnimationTime = animationController.currentTime
        let isCurrentlyPlaying = animationController.isPlaying
        
        // Pause the animation during export (if playing)
        if isCurrentlyPlaying {
            animationController.pause()
        }
        
        // Create a copy of the current canvas elements to restore later
        let originalElements = canvasElements
        
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
        
        // Bitmap info for context creation
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        // Scale factor for positioning elements
        let scaleFactor = min(
            CGFloat(width) / canvasWidth,
            CGFloat(height) / canvasHeight
        )
        
        // Center offset to position elements in the center of the frame
        let xOffset = (CGFloat(width) - canvasWidth * scaleFactor) / 2
        let yOffset = (CGFloat(height) - canvasHeight * scaleFactor) / 2
        
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
            
            // Render each frame with the animation state at that time
            for frameIdx in 0..<frameCount {
                if writerInput.isReadyForMoreMediaData {
                    // Calculate time for this frame
                    let frameTimeInSeconds = Double(frameIdx) / Double(frameRate)
                    
                    // Update animation controller to this time and update canvas elements
                    DispatchQueue.main.sync {
                        // Set animation time (this updates all animated properties)
                        animationController.currentTime = frameTimeInSeconds
                    }
                    
                    // Create a context for this frame
                    guard let context = CGContext(
                        data: nil,
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: width * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: bitmapInfo.rawValue
                    ) else {
                        continue
                    }
                    
                    // Draw white background
                    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    // Get current elements state (which may have been updated by the animation controller)
                    let elementsToRender = canvasElements
                    
                    // Draw each element
                    for element in elementsToRender {
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
                            // Save graphics state
                            context.saveGState()
                            
                            // Apply opacity to the fill color
                            let fillColor = convertToCGColor(element.color)
                            context.setFillColor(fillColor)
                            context.setAlpha(element.opacity)
                            
                            // Draw the rectangle
                            context.fill(rect)
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .ellipse:
                            // Save graphics state
                            context.saveGState()
                            
                            // Apply opacity to the fill color
                            let fillColor = convertToCGColor(element.color)
                            context.setFillColor(fillColor)
                            context.setAlpha(element.opacity)
                            
                            // Draw the ellipse
                            context.fillEllipse(in: rect)
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .path:
                            // Save graphics state
                            context.saveGState()
                            
                            // Set stroke color and width
                            let pathColor = convertToCGColor(element.color)
                            context.setStrokeColor(pathColor)
                            context.setAlpha(element.opacity)
                            context.setLineWidth(2.0)
                            
                            // Draw the path if points are available
                            if element.path.count > 1 {
                                context.beginPath()
                                
                                // Scale points to the element rect
                                let scaledPoints = element.path.map { point in
                                    CGPoint(
                                        x: rect.origin.x + point.x * rect.width,
                                        y: rect.origin.y + point.y * rect.height
                                    )
                                }
                                
                                // Start at the first point
                                context.move(to: scaledPoints[0])
                                
                                // Add lines to remaining points
                                for point in scaledPoints.dropFirst() {
                                    context.addLine(to: point)
                                }
                                
                                // Stroke the path
                                context.strokePath()
                            }
                            
                            // Restore graphics state
                            context.restoreGState()
                        case .text:
                            // Implement proper text rendering using Core Text
                            let attributedString = NSAttributedString(
                                string: element.text,
                                attributes: [
                                    // Use a size relative to the element's height for better proportional scaling
                                    .font: NSFont.systemFont(ofSize: min(rect.height * 0.7, 36)),
                                    // Ensure consistent color conversion
                                    .foregroundColor: {
                                        // First create NSColor from SwiftUI Color
                                        let nsColor = NSColor(element.color)
                                        // Then try to use a consistent color space
                                        return nsColor.usingColorSpace(.sRGB) ?? nsColor
                                    }(),
                                    .paragraphStyle: {
                                        let style = NSMutableParagraphStyle()
                                        switch element.textAlignment {
                                        case .leading:
                                            style.alignment = .left
                                        case .center:
                                            style.alignment = .center
                                        case .trailing:
                                            style.alignment = .right
                                        default:
                                            style.alignment = .left
                                        }
                                        return style
                                    }()
                                ]
                            )
                            
                            // Save the graphics state before drawing text
                            context.saveGState()
                            
                            // Apply element opacity to the entire text
                            context.setAlpha(element.opacity)
                            
                            // Create the text frame to draw in
                            let textPath = CGPath(rect: rect, transform: nil)
                            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
                            let textFrame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: attributedString.length), textPath, nil)
                            
                            // Draw the text
                            CTFrameDraw(textFrame, context)
                            
                            // Restore the graphics state after drawing
                            context.restoreGState()
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
                        continue
                    }
                    
                    // Create a pixel buffer
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
                            
                            // Send progress updates
                            if currentProgress - lastReportedProgress > 0.01 || 
                               currentTime - lastReportTime > 0.5 {
                                
                                // Ensure we're not sending progress updates too frequently
                                if currentTime - lastReportTime > 0.1 {
                                    DispatchQueue.main.async {
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
                            
                            // Restore original animation state
                            DispatchQueue.main.async {
                                self.canvasElements = originalElements
                                self.animationController.currentTime = currentAnimationTime
                                if isCurrentlyPlaying {
                                    self.animationController.play()
                                }
                            }
                            
                            semaphore.signal()
                            return
                        }
                    }
                }
            }
            
            // Send final progress update
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("ExportProgressUpdate"),
                    object: nil,
                    userInfo: ["progress": Float(0.95)]
                )
            }
            
            // Restore original animation state
            DispatchQueue.main.async {
                self.canvasElements = originalElements
                self.animationController.currentTime = currentAnimationTime
                if isCurrentlyPlaying {
                    self.animationController.play()
                }
            }
            
            // Finish writing
            writerInput.markAsFinished()
            
            // Signal completion
            semaphore.signal()
        }
        
        // Wait for media writing to complete in a non-blocking way
        let group = DispatchGroup()
        group.enter()
        
        mediaQueue.async {
            _ = semaphore.wait(timeout: .distantFuture)
            group.leave()
        }
        
        // Convert DispatchGroup to async/await
        _ = await withCheckedContinuation { continuation in
            group.notify(queue: .main) {
                // Provide haptic feedback when export is completed
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
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
    
    // MARK: - Animation Property Management
    
    /// Updates the animation properties when an element is selected
    private func updateAnimationPropertiesForSelectedElement(_ element: CanvasElement?) {
        guard let element = element else { return }
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = animationController.addTrack(id: positionTrackId) { (newPosition: CGPoint) in
                // Update the element's position when the animation plays
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].position = newPosition
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.position))
        }
        
        // Size track (using width as the animatable property for simplicity)
        let sizeTrackId = "\(idPrefix)_size"
        if animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat> == nil {
            let track = animationController.addTrack(id: sizeTrackId) { (newSize: CGFloat) in
                // Update the element's size when the animation plays
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    // If aspect ratio is locked, maintain it
                    if self.canvasElements[index].isAspectRatioLocked {
                        let ratio = self.canvasElements[index].size.height / self.canvasElements[index].size.width
                        self.canvasElements[index].size = CGSize(width: newSize, height: newSize * ratio)
                    } else {
                        self.canvasElements[index].size.width = newSize
                    }
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.size.width))
        }
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        if animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: rotationTrackId) { (newRotation: Double) in
                // Update the element's rotation when the animation plays
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].rotation = newRotation
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
        }
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        if animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = animationController.addTrack(id: colorTrackId) { (newColor: Color) in
                // Update the element's color when the animation plays
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].color = newColor
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.color))
        }
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        if animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: opacityTrackId) { (newOpacity: Double) in
                // Update the element's opacity when the animation plays
                if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.canvasElements[index].opacity = newOpacity
                }
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
        }
        
        // Path track - only for path elements
        if element.type == .path {
            let pathTrackId = "\(idPrefix)_path"
            if animationController.getTrack(id: pathTrackId) as? KeyframeTrack<[CGPoint]> == nil {
                let track = animationController.addTrack(id: pathTrackId) { (newPath: [CGPoint]) in
                    // Update the element's path when the animation plays
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].path = newPath
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

// MARK: - Timeline Keyboard Shortcuts Extension
extension KeyEventMonitorController {
    /// Setup keyboard shortcuts for timeline navigation and keyframe manipulation
    func setupTimelineKeyboardShortcuts(
        animationController: AnimationController,
        selectedElement: CanvasElement?,
        selectedKeyframeTime: Binding<Double?>,
        onAddKeyframe: @escaping (Double) -> Void,
        onDeleteKeyframe: @escaping (Double) -> Void
    ) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak animationController, weak self] event in
            guard let animationController = animationController, let self = self else { return event }
            
            // Only process events if we have focus (not in a text field, etc.)
            guard !NSApp.isActive || !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            
            switch event.keyCode {
            // Left arrow key - move back by 0.1 seconds
            case 123:
                let newTime = max(0, animationController.currentTime - 0.1)
                animationController.seek(to: newTime)
                return nil // Consume the event
                
            // Right arrow key - move forward by 0.1 seconds
            case 124:
                let newTime = min(animationController.duration, animationController.currentTime + 0.1)
                animationController.seek(to: newTime)
                return nil // Consume the event
                
            // K key - add keyframe at current time
            case 40: // K key
                if selectedElement != nil {
                    onAddKeyframe(animationController.currentTime)
                }
                return nil // Consume the event
                
            // Delete or Backspace key - delete selected keyframe
            case 51, 117: // Backspace or Delete
                if let time = selectedKeyframeTime.wrappedValue {
                    onDeleteKeyframe(time)
                    selectedKeyframeTime.wrappedValue = nil
                }
                return nil // Consume the event
                
            // Tab key - jump to next keyframe
            case 48: // Tab
                if let nextKeyframeTime = self.findNextKeyframeTime(after: animationController.currentTime, in: animationController) {
                    animationController.seek(to: nextKeyframeTime)
                }
                return nil // Consume the event
                
            // Shift + Tab key - jump to previous keyframe
            case 48 where event.modifierFlags.contains(.shift): // Shift+Tab
                if let prevKeyframeTime = self.findPreviousKeyframeTime(before: animationController.currentTime, in: animationController) {
                    animationController.seek(to: prevKeyframeTime)
                }
                return nil // Consume the event
                
            // P key - toggle playback (changed from space)
            case 35: // P key
                if animationController.isPlaying {
                    animationController.pause()
                } else {
                    animationController.play()
                }
                return nil // Consume the event
                
            // Home key - go to beginning of timeline
            case 115: // Home
                animationController.seek(to: 0)
                return nil // Consume the event
                
            // End key - go to end of timeline
            case 119: // End
                animationController.seek(to: animationController.duration)
                return nil // Consume the event
                
            default:
                break
            }
            
            return event
        }
    }
    
    /// Find the next keyframe time after the specified time
    private func findNextKeyframeTime(after time: Double, in animationController: AnimationController) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes(from: animationController)
        return allKeyframeTimes.first { $0 > time }
    }
    
    /// Find the previous keyframe time before the specified time
    private func findPreviousKeyframeTime(before time: Double, in animationController: AnimationController) -> Double? {
        let allKeyframeTimes = getAllKeyframeTimes(from: animationController)
        return allKeyframeTimes.last { $0 < time }
    }
    
    /// Get all keyframe times from all tracks in the animation controller
    private func getAllKeyframeTimes(from animationController: AnimationController) -> [Double] {
        var times: Set<Double> = []
        
        let tracks = animationController.getAllTracks()
        for trackId in tracks {
            if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGPoint> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<CGFloat> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Double> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<Color> {
                times.formUnion(track.allKeyframes.map { $0.time })
            } else if let track = animationController.getTrack(id: trackId) as? KeyframeTrack<[CGPoint]> {
                times.formUnion(track.allKeyframes.map { $0.time })
            }
        }
        
        return Array(times).sorted()
    }
}

// MARK: - Canvas Keyboard Shortcuts Extension
extension KeyEventMonitorController {
    /// Setup keyboard shortcuts for common canvas operations
    func setupCanvasKeyboardShortcuts(
        zoomIn: @escaping () -> Void,
        zoomOut: @escaping () -> Void,
        resetZoom: @escaping () -> Void
    ) {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Only process events if we have focus (not in a text field, etc.)
            guard !NSApp.isActive || !(NSApp.keyWindow?.firstResponder is NSTextView) else {
                return event
            }
            
            // Check for Command key (or Command+Shift for some shortcuts)
            let isCommandPressed = event.modifierFlags.contains(.command)
            
            if isCommandPressed {
                switch event.keyCode {
                // Plus key (Command+Plus: Zoom In)
                case 24: // Equal/Plus key
                    zoomIn()
                    return nil // Consume the event
                    
                // Minus key (Command+Minus: Zoom Out)  
                case 27: // Minus key
                    zoomOut()
                    return nil // Consume the event
                    
                // 0 key (Command+0: Reset Zoom)
                case 29: // 0 key
                    resetZoom()
                    return nil // Consume the event
                    
                default:
                    break
                }
            }
            
            return event
        }
    }
}

// Add this extension at the end of the file
extension DesignCanvas {
    // Adds accessibility identifier for UI testing
    func withUITestIdentifier() -> some View {
        self
            .accessibilityIdentifier("editor-view")
    }
}
