import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers
import Foundation
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
    // Timeline specific zoom and offset state
    @State private var timelineScale: Double = 1.0
    @State private var timelineOffset: Double = 0.0
    @State private var selectedTool: DesignTool = .select
    @State private var isInspectorVisible = true
    @State private var isEditingText = false
    @State private var editingText: String = ""
    @State private var currentMousePosition: CGPoint?
    @State private var draggedElementId: UUID?
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
    @State private var showAnimationPreview = true // Ensure timeline is visible by default
    @State private var timelineHeight: CGFloat = 400 // Default timeline height
    
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
            // Top navigation bar (commented out for now - we'll fix it properly later)
            // TopBar(
            //     onNewFile: {
            //         print("New file action triggered")
            //     },
            //     onCameraRecord: {
            //         showCameraView = true
            //     },
            //     isPlaying: $isPlaying,
            //     showAnimationPreview: $showAnimationPreview,
            //     onExport: { format in
            //         print("Exporting in format: \(format)")
            //     },
            //     onAccountSettings: {
            //         print("Account settings action triggered")
            //     },
            //     onPreferences: {
            //         print("Preferences action triggered")
            //     },
            //     onHelpAndSupport: {
            //         print("Help and support action triggered")
            //     },
            //     onCheckForUpdates: {
            //         print("Check for updates action triggered")
            //     },
            //     onSignOut: {
            //         print("Sign out action triggered")
            //     }
            // )
            // .background(Color(NSColor.windowBackgroundColor))
            
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
        .sheet(isPresented: $showCameraView) {
            CameraRecordingView(isPresented: $showCameraView)
        }
        .onChange(of: selectedElementId) { newValue in
            if let id = newValue {
                selectedElement = canvasElements.first(where: { $0.id == id })
            } else {
                selectedElement = nil
            }
        }
    }
    
    // MARK: - View Components
    
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
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // Canvas background with click handlers
    private var canvasBackgroundView: some View {
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
    private var canvasContextMenu: some View {
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
    private var gridSettingsMenu: some View {
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
                // Center the view on content
                // This would be implemented to adjust the scroll position
            }) {
                Label("Center Content", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            
            Button(action: {
                // Reset zoom to 100%
                zoom = 1.0
            }) {
                Label("Reset Zoom", systemImage: "1.magnifyingglass")
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
                            draggedElementId = element.id
                            if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                                // Update element position based on drag
                                var newPosition = canvasElements[index].position
                                newPosition.x += value.translation.width
                                newPosition.y += value.translation.height
                                
                                // Apply snap to grid if enabled
                                if snapToGridEnabled {
                                    newPosition.x = round(newPosition.x / gridSize) * gridSize
                                    newPosition.y = round(newPosition.y / gridSize) * gridSize
                                }
                                
                                canvasElements[index].position = newPosition
                            }
                        }
                    }
                    .onEnded { _ in
                        // Clear drag state
                        draggedElementId = nil
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
                    offset: $timelineOffset
                )
                    .frame(height: 30)
                    .padding(.horizontal, 16)
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
        .padding(.vertical, 1)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    DesignCanvas()
} 
#endif

