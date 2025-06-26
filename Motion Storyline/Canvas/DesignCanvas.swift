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
@State internal var canvasElements: [CanvasElement] = []
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
    @EnvironmentObject private var authManager: AuthenticationManager
    
    // Animation controller
    @StateObject internal var animationController = AnimationController()
    @State private var isPlaying = false
    @State private var selectedProperty: String?
    @State private var timelineHeight: CGFloat = 200 // Start with a reasonable default height for visibility
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

    
    // Media management
    @State private var showMediaBrowser = false
    @State private var showCameraView = false
    @State private var showAuthenticationView = false
    
    // Export modal state
    @State internal var showingExportModal = false
    
    // Before the handleExportRequest method, add these properties:
    @State private var showBatchExportSettings = false
    
    // Project initialization tracking
    @State private var hasInitializedProject = false
    
    // Create default elements for new projects
    private func createDefaultCanvasElements() -> [CanvasElement] {
        return [
            CanvasElement(
                type: .ellipse,
                position: CGPoint(x: 640, y: 360),
                size: CGSize(width: 120, height: 120),
                color: Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0),
                displayName: "Blue Circle"
            ),
            CanvasElement(
                type: .text,
                position: CGPoint(x: 640, y: 200),
                size: CGSize(width: 300, height: 50),
                color: Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 1.0),
                text: "Title Text",
                fontSize: 24.0,
                displayName: "Title Text"
            )
        ]
    }
    
    // Initialize animation controller with a test animation
    private func setupInitialAnimations() {
        // Setup the animation controller
        animationController.setup(duration: 3.0)
        
        // Find the blue circle element
        if let blueCircle = canvasElements.first(where: { $0.displayName == "Blue Circle" }) {
            // Create an opacity track for the circle
            let opacityTrack = animationController.addTrack(id: "\(blueCircle.id)_opacity") { (newOpacity: Double) in
                if let index = canvasElements.firstIndex(where: { $0.id == blueCircle.id }) {
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
    
    // State to track if we're in the middle of closing to prevent auto-save loops
    @State private var isClosing: Bool = false
    
    // Debounced auto-save timer to prevent excessive saves during rapid changes
    @State private var autoSaveTimer: Timer?
    
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
                // Use the complete implementation from DesignCanvas+FileOperations
                openProject(url: url)
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
            mainContentViewWithModifiers
        }
        // Add command handlers for saving
        .onCommand(#selector(NSDocument.save(_:))) {
            // Save project implementation
            print("Save command triggered")
        }
    }
    
    // MARK: - View Components
    
    private var mainContentView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topNavigationBar
                Divider()
                toolbarSection
                mainCanvasArea
                timelineSection(availableHeight: geometry.size.height)
            }
            .accessibilityIdentifier("editor-view")
            .accessibilityLabel("Design Canvas Editor")
            .accessibilityHint("Main design interface for creating and editing motion graphics")
        }
    }
    
    private var topNavigationBar: some View {
        CanvasTopBar(
            projectName: appState.selectedProject?.name ?? "Motion Storyline",
            onClose: {
                // Check for unsaved changes before closing
                handleCloseWithUnsavedChanges()
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
                // Account settings handled by TopBar
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
            onShowAuthentication: {
                // Authentication handled by TopBar
            },
            onCut: { print("Cut action") },
            onCopy: { print("Copy action") },
            onPaste: { print("Paste action") },
            onUndo: performUndo,
            onRedo: performRedo,
            showGrid: Binding<Bool>(get: { self.showGrid }, set: { self.showGrid = $0 }),
            showRulers: Binding<Bool>(get: { true }, set: { _ in }),  // Placeholder binding
            isInspectorVisible: $isInspectorVisible,
            onSave: {
                handleSaveWorkingFile()
            },
            onSaveAs: {
                handleExportProjectAs()
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
        .environmentObject(undoRedoManager)
        .environmentObject(authManager)
        .accessibilityIdentifier("canvas-top-bar")
        .accessibilityLabel("Design Canvas Navigation Bar")
    }
    
    private var toolbarSection: some View {
        VStack(spacing: 0) {
            DesignToolbar(selectedTool: $selectedTool)
                .padding(.vertical, 8) // Increased padding for better spacing
                .accessibilityIdentifier("design-toolbar")
                .accessibilityLabel("Design Tools")
                .accessibilityHint("Select tools for creating and editing canvas elements")
            
            // Canvas dimensions indicator
            Text("Canvas: \(Int(canvasWidth))×\(Int(canvasHeight)) (HD 16:9)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 6)
                .accessibilityIdentifier("canvas-dimensions")
                .accessibilityLabel("Canvas dimensions: \(Int(canvasWidth)) by \(Int(canvasHeight)) pixels, HD 16:9 aspect ratio")
            
            Divider() // Add visual separator between toolbar and canvas
        }
        // Enforce that toolbar section doesn't expand or get pushed by canvas
        .frame(maxHeight: 90) // Increased fixed height for toolbar section
        .padding(.top, 4) // Add a little padding at the top to separate from TopBar
    }
    
    private var mainCanvasArea: some View {
        HStack(spacing: 0) {
            // Main canvas area - wrapped in a ScrollView to prevent overflow
            ScrollView([.horizontal, .vertical]) {
                canvasContentView
            }
            .frame(maxWidth: .infinity)
            // Remove maxHeight: .infinity to allow timeline to claim space
            .clipped() // Ensure content doesn't overflow
            .accessibilityIdentifier("canvas-scroll-view")
            .accessibilityLabel("Design Canvas")
            .accessibilityHint("Main canvas area for creating and editing design elements. Use tools from the toolbar to add shapes, text, and other elements.")
            
            // Right sidebar with inspector
            if isInspectorVisible {
                Divider()
                InspectorView(
                    selectedElement: $selectedElement,
                    onClose: {
                        isInspectorVisible = false
                    }
                )
                .accessibilityIdentifier("inspector-panel")
                .accessibilityLabel("Properties Inspector")
                .accessibilityHint("Adjust properties of the selected canvas element")
            }
        }
        .layoutPriority(2) // Give canvas area higher priority than timeline, but allow timeline to expand
        .overlay(
            // Inspector toggle button - only show when inspector is hidden
            Group {
                if !isInspectorVisible {
                    inspectorToggleButton
                }
            },
            alignment: .topTrailing
        )
    }
    
    // MARK: - Inspector Toggle Button
    private var inspectorToggleButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isInspectorVisible = true
            }
        }) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .padding(.trailing, 8)
        .help("Show Inspector (⌘I)")
        .accessibilityIdentifier("inspector-toggle-button")
        .accessibilityLabel("Show Inspector")
        .accessibilityHint("Click to show the properties inspector panel")
        .opacity(0.8) // Slightly transparent to be subtle
        .onHover { hovering in
            // Optional: Could add hover effect here if desired
        }
        .zIndex(100) // Ensure it appears above other elements
    }
    
    @ViewBuilder
    private func timelineSection(availableHeight: CGFloat) -> some View {
        if showAnimationPreview {
            // Timeline panel with proper height constraints and available parent height
            TimelineViewPanel(
                animationController: animationController,
                isPlaying: $isPlaying,
                timelineHeight: $timelineHeight,
                timelineOffset: $timelineOffset,
                selectedElement: $selectedElement,
                timelineScale: $timelineScale,
                availableParentHeight: availableHeight
            )
            .frame(height: timelineHeight)
            .layoutPriority(1) // Give timeline lower priority than canvas but allow it to claim needed space
            .accessibilityIdentifier("timeline-view")
            .accessibilityLabel("Animation Timeline")
            .accessibilityHint("Control animation playback and manage keyframes")
        } else {
            // Show when timeline is hidden with enable button
            HStack {
                Image(systemName: "timeline.selection")
                    .foregroundColor(.secondary)
                Text("Animation Timeline Hidden")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Show Timeline") {
                    showAnimationPreview = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
        }
    }
    
    private var mainContentViewWithModifiers: some View {
        mainContentView
        .onAppear {
            // Only initialize once to prevent duplicate setups
            guard !hasInitializedProject else { return }
            hasInitializedProject = true
            
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
                    }
                }
            )
            
            // Setup canvas keyboard shortcuts
            keyMonitorController.setupCanvasKeyboardShortcuts(
                zoomIn: zoomIn,
                zoomOut: zoomOut,
                resetZoom: resetZoom,
                saveProject: { 
                    print("💾 Manual save triggered via keyboard shortcut")
                    self.autoSaveProject() 
                },
                deleteSelectedElement: {
                    if let elementId = selectedElementId {
                        recordStateBeforeChange(actionName: "Delete Element")
                        canvasElements.removeAll(where: { $0.id == elementId })
                        selectedElementId = nil
                        markDocumentAsChanged(actionName: "Delete Element")
                    }
                }
            )
            
            // Check if we have a selected project and load it
            if let selectedProject = appState.selectedProject {
                print("🎯 Loading project from selection on appear: \(selectedProject.name)")
                loadProjectFromSelection(selectedProject)
            } else {
                print("🆕 No selected project, setting up new project with default elements")
                // Set up default elements and animations for a new project
                canvasElements = createDefaultCanvasElements()
                
                // Setup initial animations only for new projects
                animationController.setup(duration: 3.0)
                setupInitialAnimations()
                
                // Configure DocumentManager with current state
                configureDocumentManager()
                
                // Prepare new project for auto-saving
                prepareNewProjectForAutoSave()
            }
            
            // Register undo/redo actions with AppStateManager
            appState.registerUndoRedoActions(
                undo: performUndo,
                redo: performRedo,
                canUndoPublisher: undoRedoManager.$canUndo.eraseToAnyPublisher(),
                canRedoPublisher: undoRedoManager.$canRedo.eraseToAnyPublisher(),
                hasUnsavedChangesPublisher: documentManager.$hasUnsavedChanges.eraseToAnyPublisher(),
                currentProjectURLPublisher: documentManager.$projectURL.eraseToAnyPublisher()
            )
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
            // Skip if this is a programmatic change (e.g., during drag operations)
            guard !isProgrammaticChange else { return }
            
            // Update the corresponding element in canvasElements when selectedElement is modified
            print("🔍 Selected element changed: \(String(describing: newValue?.displayName))")
            print("🔍 Timeline height: \(timelineHeight), Preview enabled: \(showAnimationPreview)")
            
            // Only update if the element actually changed and avoid circular updates
            if let updatedElement = newValue,
               let index = canvasElements.firstIndex(where: { $0.id == updatedElement.id }) {
                
                // Check if the element actually changed to avoid unnecessary updates
                let currentElement = canvasElements[index]
                let hasChanged = currentElement.position != updatedElement.position ||
                                currentElement.size != updatedElement.size ||
                                currentElement.rotation != updatedElement.rotation ||
                                currentElement.opacity != updatedElement.opacity ||
                                currentElement.color != updatedElement.color ||
                                currentElement.text != updatedElement.text ||
                                currentElement.textAlignment != updatedElement.textAlignment ||
                                currentElement.fontSize != updatedElement.fontSize ||
                                currentElement.displayName != updatedElement.displayName
                
                if hasChanged {
                    // Record state before making changes
                    recordStateBeforeChange(actionName: "Update Element Properties")
                    
                    // Update the element in the canvas elements array
                    canvasElements[index] = updatedElement
                    
                    // Mark document as changed for property changes
                    markDocumentAsChanged(actionName: "Update Element Properties")
                }
            }
        }
        .onDisappear {
            // Cancel any pending auto-save timer
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
            
            // Teardown key monitor when view disappears
            keyMonitorController.teardownMonitor()
            
            // Clear undo/redo actions from AppStateManager
            appState.clearUndoRedoActions()
            
            // Auto-save if there are unsaved changes and we're not in the middle of a close operation
            if documentManager.hasUnsavedChanges && !isClosing {
                print("🔄 Auto-saving project on view disappear...")
                autoSaveProject()
            }
        }
        .onChange(of: appState.scenePhase) { oldPhase, newPhase in
            // Auto-save when app goes to background
            if newPhase == .background && documentManager.hasUnsavedChanges {
                print("🔄 App going to background, auto-saving project...")
                autoSaveProject()
            }
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
                markDocumentAsChanged(actionName: "Add Media Element")
            }, onMediaAssetImported: {
                markDocumentAsChanged(actionName: "Import Media Asset")
            })
                .frame(width: 800, height: 600)
        }
        // Add AuthenticationView sheet for sign in
        .sheet(isPresented: $showAuthenticationView) {
            AuthenticationView()
                .environmentObject(authManager)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            canvasBaseLayersView
            canvasElementsView
            canvasDrawingPreviewsView
            canvasUIOverlaysView
        }
        .scaleEffect(zoom) // Apply zoom scale
        .offset(viewportOffset) // Apply the viewport offset
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("canvas-content")
        .accessibilityLabel("Canvas Content Area")
        .accessibilityHint("Contains \(canvasElements.count) design elements. Current zoom: \(Int(zoom * 100))%")
        .gesture(canvasPanGesture)
        .frame(minWidth: 400, minHeight: 400)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color(NSColor.windowBackgroundColor))
        )
    }
    
    private var canvasBaseLayersView: some View {
        Group {
            // Grid background (bottom layer)
            GridBackground(showGrid: showGrid, gridSize: gridSize)
                .accessibilityIdentifier("canvas-grid")
                .accessibilityLabel("Canvas Grid Background")
                .accessibilityHidden(true) // Grid is decorative, hide from VoiceOver
            
            // Canvas boundary indicator - made more visible with a thicker stroke
            Rectangle()
                .strokeBorder(Color.blue.opacity(0.7), lineWidth: 2.5, antialiased: true)
                .frame(width: canvasWidth, height: canvasHeight)
                .allowsHitTesting(false)
                .accessibilityIdentifier("canvas-boundary")
                .accessibilityLabel("Canvas Boundary")
                .accessibilityHint("Defines the \(Int(canvasWidth)) by \(Int(canvasHeight)) pixel canvas area")
            
            // Background for click capture - MOVED BEFORE ELEMENTS
            canvasBackgroundView
        }
    }
    
    private var canvasElementsView: some View {
        // Canvas elements
        ForEach(canvasElements) { element in
                CanvasElementView(
                    element: element,
                    isSelected: element.id == selectedElementId,
                    onResize: { newSize in
                        if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                            recordStateBeforeChange(actionName: "Resize Element")
                            canvasElements[index].size = newSize
                            
                            // Update selectedElement if this is the selected element
                            if element.id == selectedElementId {
                                isProgrammaticChange = true
                                selectedElement = canvasElements[index]
                                isProgrammaticChange = false
                            }
                            
                            markDocumentAsChanged(actionName: "Resize Element")
                        }
                    },
                    onRotate: { newRotation in
                        if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                            recordStateBeforeChange(actionName: "Rotate Element")
                            canvasElements[index].rotation = newRotation
                            
                            // Update selectedElement if this is the selected element
                            if element.id == selectedElementId {
                                isProgrammaticChange = true
                                selectedElement = canvasElements[index]
                                isProgrammaticChange = false
                            }
                            
                            markDocumentAsChanged(actionName: "Rotate Element")
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
                .accessibilityIdentifier("canvas-element-\(element.id)")
                .accessibilityLabel("\(element.displayName), \(element.type.rawValue)")
                .accessibilityHint("Canvas element. Tap to select, drag to move. \(element.id == selectedElementId ? "Currently selected." : "")")
                .accessibilityValue(elementAccessibilityValue(for: element))
                .contextMenu {
                    elementContextMenu(for: element)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if selectedTool == .select {
                                if draggedElementId != element.id {
                                    // First time this element is being dragged in this gesture
                                    draggedElementId = element.id
                                    recordStateBeforeChange(actionName: "Move Element")
                                    
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
                                    
                                    // Also update selectedElement if this is the selected element
                                    // Use isProgrammaticChange to prevent triggering onChange
                                    if element.id == selectedElementId {
                                        isProgrammaticChange = true
                                        selectedElement = canvasElements[index]
                                        isProgrammaticChange = false
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            // Mark document as changed after drag operation
                            if draggedElementId != nil {
                                markDocumentAsChanged(actionName: "Move Element")
                            }
                            
                            // Reset drag state
                            draggedElementId = nil
                            initialDragElementPosition = nil
                        }
                )
            }
    }
    
    private var canvasDrawingPreviewsView: some View {
        // Drawing previews
        Group {
                // Preview of rectangle being drawn
                if self.isDrawingRectangle, let start = self.rectangleStartPoint, let current = self.rectangleCurrentPoint {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: current.x - start.x, height: current.y - start.y)
                        .accessibilityIdentifier("rectangle-preview")
                        .accessibilityLabel("Rectangle being drawn")
                        .accessibilityHidden(true) // Hide preview from VoiceOver
                }
                
                // Preview of ellipse being drawn
                if self.isDrawingEllipse, let start = self.rectangleStartPoint, let current = self.rectangleCurrentPoint {
                    Ellipse()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: current.x - start.x, height: current.y - start.y)
                        .accessibilityIdentifier("ellipse-preview")
                        .accessibilityLabel("Ellipse being drawn")
                        .accessibilityHidden(true) // Hide preview from VoiceOver
                }
            }
    }
    
    private var canvasUIOverlaysView: some View {
        Group {
            // Mouse tracking view for cursor management
            MousePositionView { location in
                currentMousePosition = location
            }
            .allowsHitTesting(false) // Make sure it doesn't interfere with other interactions
            .accessibilityHidden(true) // Hide mouse tracking from VoiceOver
            
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
                    .accessibilityIdentifier("zoom-indicator")
                    .accessibilityLabel("Zoom level: \(Int(zoom * 100)) percent")
            }
        }
    }
    
    private var canvasPanGesture: some Gesture {
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

    // Canvas background with click handlers
    var canvasBackgroundView: some View {
        Color.clear
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .accessibilityIdentifier("canvas-background")
            .accessibilityLabel("Canvas Background")
            .accessibilityHint("Tap to deselect elements or use tools to create new elements")
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
                    recordStateBeforeChange(actionName: "Create Text")
                    
                    // Create text at the exact click location
                    let newText = CanvasElement.text(at: location)
                    canvasElements.append(newText)
                    handleElementSelection(newText)
                    isEditingText = true
                    editingText = newText.text
                    
                    // Mark document as changed
                    markDocumentAsChanged(actionName: "Create Text")
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
                    }
                }
            }
            .gesture(canvasDrawingGesture)
    }
    
    // Canvas context menu content is now in DesignCanvas+ContextMenus.swift
    
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
                            recordStateBeforeChange(actionName: "Create Rectangle")
                            
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
                            
                            // Mark document as changed
                            markDocumentAsChanged(actionName: "Create Rectangle")
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
                            recordStateBeforeChange(actionName: "Create Ellipse")
                            
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
                            
                            // Mark document as changed
                            markDocumentAsChanged(actionName: "Create Ellipse")
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
        
        // Update the current project with loaded media assets
        if self.appState.selectedProject != nil {
            self.appState.selectedProject?.mediaAssets = projectData.mediaAssets
            print("Loaded \(projectData.mediaAssets.count) media assets into project")
        }
        
        // Rebuild AnimationController state
        self.animationController.reset()
        self.animationController.setup(duration: projectData.duration)
        
        // Reconstruct animation tracks and keyframes from saved data
        print("Reconstructing \(projectData.tracks.count) animation tracks...")
        for trackData in projectData.tracks {
            // Parse track ID to get element ID and property name
            let components = trackData.id.split(separator: "_", maxSplits: 1)
            guard components.count == 2, 
                  let elementID = UUID(uuidString: String(components[0])) else {
                print("Warning: Could not parse trackId \(trackData.id) into elementID and propertyName.")
                continue
            }
            
            let propertyName = String(components[1])
            
            // Find the element index for the update callback
            guard let elementIndex = self.canvasElements.firstIndex(where: { $0.id == elementID }) else {
                print("Warning: Element with ID \(elementID) not found for track \(trackData.id).")
                continue
            }
            
            // Create the appropriate track based on value type
            switch trackData.valueType {
            case "Double":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: Double) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        switch propertyName {
                        case "opacity": 
                            self.canvasElements[elementIndex].opacity = newValue
                        case "rotation": 
                            self.canvasElements[elementIndex].rotation = newValue
                        case "scale": 
                            self.canvasElements[elementIndex].scale = CGFloat(newValue)
                        default: 
                            print("Warning: Update callback for Double property \(propertyName) not implemented.")
                        }
                    }
                }
                // Add keyframes with proper easing restoration
                for keyframeData in trackData.keyframes {
                    if let value = Double(keyframeData.value) {
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } else {
                        print("Warning: Could not parse Double for keyframe value: \(keyframeData.value)")
                    }
                }
                
            case "CGFloat":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGFloat) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        switch propertyName {
                        case "size":
                            // Handle size as width scaling, maintaining aspect ratio if locked
                            let element = self.canvasElements[elementIndex]
                            if element.isAspectRatioLocked && element.size.width > 0 {
                                let ratio = element.size.height / element.size.width
                                self.canvasElements[elementIndex].size = CGSize(width: newValue, height: newValue * ratio)
                            } else {
                                self.canvasElements[elementIndex].size.width = newValue
                            }
                        case "fontSize":
                            self.canvasElements[elementIndex].fontSize = newValue
                        default:
                            print("Warning: Update callback for CGFloat property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    if let value = Double(keyframeData.value).map({ CGFloat($0) }) {
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } else {
                        print("Warning: Could not parse CGFloat for keyframe value: \(keyframeData.value)")
                    }
                }
                
            case "CGPoint":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGPoint) in
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
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } catch {
                        print("Warning: Could not parse CGPoint for keyframe value: \(keyframeData.value). Error: \(error.localizedDescription)")
                    }
                }
                
            case "CGSize":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: CGSize) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "size" {
                            self.canvasElements[elementIndex].size = newValue
                        } else {
                            print("Warning: Update callback for CGSize property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    do {
                        let value = try CanvasElement.decodeCGSize(from: keyframeData.value)
                        let easing = self.documentManager.easingFromString(keyframeData.easing)
                        track.add(keyframe: Keyframe(time: keyframeData.time, value: value, easingFunction: easing))
                    } catch {
                        print("Warning: Could not parse CGSize for keyframe value: \(keyframeData.value). Error: \(error.localizedDescription)")
                    }
                }
                
            case "Color":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: Color) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "color" {
                            self.canvasElements[elementIndex].color = newValue
                        } else {
                            print("Warning: Update callback for Color property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    let color = self.documentManager.colorFromString(keyframeData.value)
                    let easing = self.documentManager.easingFromString(keyframeData.easing)
                    track.add(keyframe: Keyframe(time: keyframeData.time, value: color, easingFunction: easing))
                }
                
            case "String":
                let track = self.animationController.addTrack(id: trackData.id) { (newValue: String) in
                    if self.canvasElements.indices.contains(elementIndex) {
                        if propertyName == "text" {
                            self.canvasElements[elementIndex].text = newValue
                        } else {
                            print("Warning: Update callback for String property \(propertyName) not implemented.")
                        }
                    }
                }
                for keyframeData in trackData.keyframes {
                    let easing = self.documentManager.easingFromString(keyframeData.easing)
                    track.add(keyframe: Keyframe(time: keyframeData.time, value: keyframeData.value, easingFunction: easing))
                }
                
            case "[CGPoint]":
                // TODO: Implement path/custom shape support in CanvasElement
                print("Warning: [CGPoint] track type not yet supported. CanvasElement needs a path property.")
                
            default:
                print("Warning: Unsupported track valueType '\(trackData.valueType)' for track \(trackData.id) during project load.")
            }
        }
        
        // Notify the animation controller that tracks have been updated
        self.animationController.objectWillChange.send()
        print("Successfully reconstructed \(projectData.tracks.count) animation tracks with all keyframes and easing functions.")

        // Configure DocumentManager with the newly loaded state and URL
        // Note: documentManager.projectURL is already set by loadProject(from:)
        configureDocumentManager()

        // Update AppState
        if let projectURL = documentManager.projectURL {
            appState.currentProjectName = projectURL.deletingPathExtension().lastPathComponent
            print("Project name set to: \(appState.currentProjectName)")
        }
        appState.currentProjectURLToLoad = nil // Clear the request to load this URL

        // Reset UI states only when loading from file (not during undo/redo)
        if !isProgrammaticChange {
            self.selectedElementId = nil
            self.zoom = 1.0
            self.viewportOffset = .zero
            self.appState.currentTimelineScale = 1.0 // Reset timeline zoom
            self.appState.currentTimelineOffset = 0.0 // Reset timeline offset
            self.undoRedoManager.clearHistory() // Clear undo/redo history for the newly loaded project
            self.documentManager.hasUnsavedChanges = false // A freshly loaded project has no unsaved changes
        } else {
            print("🔄 Preserving UI state during programmatic change (undo/redo)")
        }

        self.isProgrammaticChange = false // Reset programmatic change flag
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("Project data applied and UI reset for loaded project.")
    }
    
    internal func configureDocumentManager() {
        documentManager.configure(
            canvasElements: self.canvasElements,
            animationController: self.animationController,
            canvasSize: CGSize(width: self.canvasWidth, height: self.canvasHeight),
            currentProject: appState.selectedProject
        )
        print("🔧 DocumentManager configured with \(canvasElements.count) elements, \(animationController.getAllTracks().count) tracks, hasUnsavedChanges: \(documentManager.hasUnsavedChanges)")
    }
    
    internal func recordUndoState(actionName: String) {
        // Ensure DocumentManager has the latest state before capturing
        configureDocumentManager()
        
        // Use DocumentManager's method to get consistent state format
        guard let stateData = documentManager.getCurrentProjectStateData() else {
            print("Failed to capture current state for undo: \(actionName)")
            return
        }
        
        undoRedoManager.addUndoState(stateBeforeOperation: stateData)
        print("Recorded undo state for: \(actionName)")
    }
    
    // MARK: - Document State Management
    
    /// Records the current state before a change and marks the document as changed
    /// This should be called before any user action that modifies the canvas
    internal func recordStateBeforeChange(actionName: String) {
        // Skip if this is a programmatic change (e.g., during project loading)
        guard !isProgrammaticChange else { return }
        
        // Record the current state for undo/redo BEFORE the change
        recordUndoState(actionName: actionName)
        
        print("State recorded before change: \(actionName)")
    }
    
    /// Marks the document as changed after a modification
    /// This should be called after any user action that modifies the canvas
    internal func markDocumentAsChanged(actionName: String) {
        // Skip if this is a programmatic change (e.g., during project loading)
        guard !isProgrammaticChange else { 
            print("⏩ Skipping markDocumentAsChanged for programmatic change: \(actionName)")
            return 
        }
        
        // Update the document manager with the current state FIRST
        // This ensures the DocumentManager always has the latest data for auto-save
        configureDocumentManager()
        
        // Then mark the document as having unsaved changes
        documentManager.hasUnsavedChanges = true
        
        print("📝 Document marked as changed: \(actionName), hasUnsavedChanges = \(documentManager.hasUnsavedChanges)")
        print("📝 DocumentManager now has \(documentManager.currentElementCount) elements and \(documentManager.currentTrackCount) tracks")
        
        // Schedule debounced auto-save to ensure changes are saved after a brief delay
        scheduleAutoSave()
    }
    
    // MARK: - Undo/Redo Operations
    
    /// Performs undo operation by restoring the previous state
    internal func performUndo() {
        print("🔄 Starting undo operation...")
        
        // Ensure DocumentManager has the latest state before undo
        configureDocumentManager()
        
        // Get current state for potential redo
        guard let currentState = documentManager.getCurrentProjectStateData() else {
            print("❌ Cannot get current state for undo operation")
            return
        }
        
        // Perform undo and get the state to restore
        guard let stateToRestore = undoRedoManager.undo(currentStateForRedo: currentState) else {
            print("❌ No undo state available")
            return
        }
        
        // Decode and apply the restored state
        guard let projectData = documentManager.decodeProjectState(from: stateToRestore) else {
            print("❌ Failed to decode undo state")
            return
        }
        
        print("🔄 Restoring state with \(projectData.elements.count) elements and \(projectData.tracks.count) tracks")
        
        // Apply the restored state
        isProgrammaticChange = true
        applyProjectData(projectData: projectData)
        isProgrammaticChange = false
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("✅ Undo operation completed")
    }
    
    /// Performs redo operation by restoring the next state
    internal func performRedo() {
        print("🔄 Starting redo operation...")
        
        // Ensure DocumentManager has the latest state before redo
        configureDocumentManager()
        
        // Get current state for potential undo
        guard let currentState = documentManager.getCurrentProjectStateData() else {
            print("❌ Cannot get current state for redo operation")
            return
        }
        
        // Perform redo and get the state to restore
        guard let stateToRestore = undoRedoManager.redo(currentStateForUndo: currentState) else {
            print("❌ No redo state available")
            return
        }
        
        // Decode and apply the restored state
        guard let projectData = documentManager.decodeProjectState(from: stateToRestore) else {
            print("❌ Failed to decode redo state")
            return
        }
        
        print("🔄 Restoring state with \(projectData.elements.count) elements and \(projectData.tracks.count) tracks")
        
        // Apply the restored state
        isProgrammaticChange = true
        applyProjectData(projectData: projectData)
        isProgrammaticChange = false
        
        // UI will automatically refresh due to @State changes in SwiftUI
        
        print("✅ Redo operation completed")
    }
    
    // MARK: - Element Selection
    
    /// Handles element selection when an element is tapped
    internal func handleElementSelection(_ element: CanvasElement) {
        print("🎯 Element selected: \(element.displayName)")
        print("🎯 Timeline enabled: \(showAnimationPreview), Timeline height: \(timelineHeight)")
        
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
            // Add initial keyframe at time 0 with current element position
            track.add(keyframe: Keyframe(time: 0.0, value: element.position))
        } else if let track = canvas.animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> {
            // Update the initial keyframe with current element position if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.position, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.position))
            }
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
            // Add initial keyframe at time 0 with current element size
            track.add(keyframe: Keyframe(time: 0.0, value: element.size))
        } else if let track = canvas.animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> {
            // Update the initial keyframe with current element size if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.size, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.size))
            }
        }
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        if canvas.animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = canvas.animationController.addTrack(id: rotationTrackId) { [canvas] (newRotation: Double) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].rotation = newRotation
                }
            }
            // Add initial keyframe at time 0 with current element rotation
            track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
        } else if let track = canvas.animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> {
            // Update the initial keyframe with current element rotation if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
            }
        }
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        if canvas.animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = canvas.animationController.addTrack(id: colorTrackId) { [canvas] (newColor: Color) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].color = newColor
                }
            }
            // Add initial keyframe at time 0 with current element color
            track.add(keyframe: Keyframe(time: 0.0, value: element.color))
        } else if let track = canvas.animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> {
            // Update the initial keyframe with current element color if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.color, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.color))
            }
        }
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        if canvas.animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = canvas.animationController.addTrack(id: opacityTrackId) { [canvas] (newOpacity: Double) in
                if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                    canvas.canvasElements[index].opacity = newOpacity
                }
            }
            // Add initial keyframe at time 0 with current element opacity
            track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
        } else if let track = canvas.animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> {
            // Update the initial keyframe with current element opacity if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity, easingFunction: existingKeyframe.easingFunction))
            } else {
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
            }
        }
        
        // Font size track (only for text elements)
        if element.type == .text {
            let fontSizeTrackId = "\(idPrefix)_fontSize"
            if canvas.animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> == nil {
                let track = canvas.animationController.addTrack(id: fontSizeTrackId) { [canvas] (newFontSize: CGFloat) in
                    if let index = canvas.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        canvas.canvasElements[index].fontSize = max(8, min(200, newFontSize)) // Constrain between 8pt and 200pt
                    }
                }
                // Add initial keyframe at time 0 with current element font size
                track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
            } else if let track = canvas.animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> {
                // Update the initial keyframe with current element font size if it exists
                if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                    track.removeKeyframe(at: 0.0)
                    track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize, easingFunction: existingKeyframe.easingFunction))
                } else {
                    track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
                }
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

// MARK: - Document Management Methods
extension DesignCanvas {
    
    /// Handles closing the canvas with unsaved changes
    private func handleCloseWithUnsavedChanges() {
        print("🔍 Handling close with unsaved changes check...")
        print("🔍 documentManager.hasUnsavedChanges = \(documentManager.hasUnsavedChanges)")
        print("🔍 canvasElements.count = \(canvasElements.count)")
        print("🔍 documentManager.currentElementCount = \(documentManager.currentElementCount)")
        print("🔍 documentManager.projectURL = \(documentManager.projectURL?.path ?? "nil")")
        
        // Always save when closing, regardless of unsaved changes flag
        // This ensures we never lose user work
        isClosing = true
        
        // Auto-save the project before closing
        print("🔄 Auto-saving project before closing...")
        autoSaveProject()
        
        // Small delay to ensure save completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.performClose()
        }
    }
    
    /// Performs the actual close operation
    private func performClose() {
        print("Closing canvas and returning to home")
        appState.selectedProject = nil
        appState.navigateToHome()
        isClosing = false // Reset the flag
    }
    
    /// Schedules a debounced auto-save to prevent excessive saves during rapid changes
    private func scheduleAutoSave() {
        // Cancel any existing timer
        autoSaveTimer?.invalidate()
        
        // Capture the values locally to avoid main actor isolation issues
        let hasUnsavedChanges = documentManager.hasUnsavedChanges
        let currentIsClosing = isClosing
        
        // Schedule a new auto-save after a 3-second delay
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [self] _ in
            // Only auto-save if we have unsaved changes and aren't closing
            if hasUnsavedChanges && !currentIsClosing {
                print("⏰ Scheduled auto-save triggered")
                self.autoSaveProject()
            }
        }
    }
    
    /// Auto-saves the project without showing dialogs
    private func autoSaveProject() {
        print("🔄 Starting auto-save process...")
        print("🔄 Current canvas state: \(canvasElements.count) elements")
        
        // Configure the document manager with current state to ensure consistency
        configureDocumentManager()
        
        // Validate that DocumentManager has the correct state before saving
        let expectedElementCount = canvasElements.count
        let actualElementCount = documentManager.currentElementCount
        
        if expectedElementCount != actualElementCount {
            print("⚠️ WARNING: State mismatch detected!")
            print("⚠️ Expected \(expectedElementCount) elements, DocumentManager has \(actualElementCount)")
            print("⚠️ Reconfiguring DocumentManager...")
            
            // Force reconfigure if there's a mismatch
            configureDocumentManager()
        }
        
        print("🔄 DocumentManager configured with \(documentManager.currentElementCount) elements, \(documentManager.currentTrackCount) tracks")
        
        // Always use project file for auto-save
        let success = documentManager.saveWorkingFile()
        if success {
            print("✅ Project auto-saved successfully")
        } else {
            print("❌ Failed to auto-save project - no project URL set")
            // If no project URL is set, create one
            createDefaultProjectFile()
        }
    }
    
    /// Creates a default project file location for new projects
    private func createDefaultProjectFile() {
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            print("Could not create default project file: unable to create projects directory")
            return
        }
        
        // Generate a filename based on the project name or a default
        let projectName = appState.selectedProject?.name ?? "Untitled Project"
        let sanitizedName = projectName.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Use exact project name - no auto-incrementing numbers
        let filename = "\(baseFilename).storyline"
        let saveURL = projectsFolder.appendingPathComponent(filename)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = saveURL.deletingPathExtension().lastPathComponent
        
        // Now actually save the project file
        let success = documentManager.saveWorkingFile()
        
        if success {
            print("Project file auto-saved to: \(saveURL.path)")
        } else {
            print("Failed to auto-save project file to: \(saveURL.path)")
        }
    }
    

    
    /// Shows an error alert when save fails
    private func showSaveErrorAlert() {
        let alert = NSAlert()
        alert.messageText = "Save Failed"
        alert.informativeText = "Could not save the project. Please try again or choose a different location."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Creates the projects directory if it doesn't exist
    private func ensureProjectsDirectoryExists() -> URL? {
        let fileManager = FileManager.default
        
        // Get the Documents directory
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access Documents directory")
            return nil
        }
        
        // Create Motion Storyline Projects folder if it doesn't exist
        let projectsFolder = documentsURL.appendingPathComponent("Motion Storyline Projects")
        if !fileManager.fileExists(atPath: projectsFolder.path) {
            do {
                try fileManager.createDirectory(at: projectsFolder, withIntermediateDirectories: true)
                print("Created projects directory at: \(projectsFolder.path)")
            } catch {
                print("Failed to create projects folder: \(error.localizedDescription)")
                return nil
            }
        }
        
        return projectsFolder
    }
    
    /// Prepares a new project for auto-save by setting up a default project file URL
    private func prepareNewProjectForAutoSave() {
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            print("Could not prepare project for auto-save: unable to create projects directory")
            return
        }
        
        let projectName = appState.selectedProject?.name ?? "Untitled Project"
        let sanitizedName = projectName.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Use exact project name - no auto-incrementing numbers
        let filename = "\(baseFilename).storyline"
        let saveURL = projectsFolder.appendingPathComponent(filename)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = saveURL.deletingPathExtension().lastPathComponent
        
        print("Prepared new project for auto-save at: \(saveURL.path)")
    }
    
    /// Loads a project from the file system based on the selected project
    private func loadProjectFromSelection(_ project: Project) {
        print("🔄 Loading project from selection: \(project.name)")
        
        // Create the expected file path based on project name
        let projectURL = constructProjectURL(for: project.name)
        
        // Check if the project file exists
        if FileManager.default.fileExists(atPath: projectURL.path) {
            print("📁 Found existing project file at: \(projectURL.path)")
            
            // Load the existing project file
            do {
                guard let loadedTuple = try documentManager.loadProject(from: projectURL) else {
                    print("❌ Failed to load project data from: \(projectURL.path)")
                    setupNewProject(for: project)
                    return
                }
                
                // Construct ProjectData from the loaded tuple
                let projectDataInstance = ProjectData(
                    elements: loadedTuple.elements,
                    tracks: loadedTuple.tracksData,
                    duration: loadedTuple.duration,
                    canvasWidth: loadedTuple.canvasWidth,
                    canvasHeight: loadedTuple.canvasHeight,
                    mediaAssets: loadedTuple.mediaAssets
                )
                
                print("✅ Successfully loaded project with \(loadedTuple.elements.count) elements")
                
                        // Apply the loaded project data
        applyProjectData(projectData: projectDataInstance)
        
        // The DocumentManager.loadProject() should have set projectURL correctly
        // No additional setup needed since we use a single URL
        
        // Update project name in AppState
        appState.selectedProject?.name = loadedTuple.projectName
        
        print("🎯 Project '\(project.name)' loaded successfully from file")
                
            } catch {
                print("❌ Error loading project file: \(error.localizedDescription)")
                // Fall back to creating a new project
                setupNewProject(for: project)
            }
        } else {
            print("📄 No existing file found for '\(project.name)', setting up new project")
            // No existing file, set up as a new project
            setupNewProject(for: project)
        }
    }
    
    /// Constructs the expected file URL for a project name
    private func constructProjectURL(for projectName: String) -> URL {
        // Ensure the projects directory exists and get its URL
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            fatalError("Could not access or create Motion Storyline Projects directory")
        }
        
        // Sanitize the project name for filename (same logic as save methods)
        let sanitizedName = projectName.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Always use the exact project name - no auto-incrementing or version scanning
        let filename = "\(baseFilename).storyline"
        return projectsFolder.appendingPathComponent(filename)
    }
    
    /// Sets up a new project with default elements and prepares it for saving
    private func setupNewProject(for project: Project) {
        print("🆕 Setting up new project: \(project.name)")
        
        // Reset to default canvas elements for new projects
        isProgrammaticChange = true
        
        // Set default elements for new projects
        canvasElements = createDefaultCanvasElements()
        
        // Reset canvas properties
        canvasWidth = 1280
        canvasHeight = 720
        zoom = 1.0
        viewportOffset = .zero
        selectedElementId = nil
        selectedElement = nil
        
        // Reset animation controller
        animationController.reset()
        animationController.setup(duration: 3.0)
        
        // Set up initial animations for default elements
        setupInitialAnimations()
        
        // Clear document manager state
        documentManager.projectURL = nil
        documentManager.hasUnsavedChanges = false
        
        // Configure DocumentManager with the new state
        configureDocumentManager()
        
        // Prepare for auto-saving with the correct internal working file URL
        prepareNewProjectForAutoSave()
        
        isProgrammaticChange = false
        
        print("✅ New project '\(project.name)' set up with default elements")
    }
}

// MARK: - Accessibility Helper Functions

/// Provides accessibility value information for canvas elements
private func elementAccessibilityValue(for element: CanvasElement) -> String {
    var valueComponents: [String] = []
    
    // Position information
    valueComponents.append("Position: \(Int(element.position.x)), \(Int(element.position.y))")
    
    // Size information
    valueComponents.append("Size: \(Int(element.size.width)) by \(Int(element.size.height))")
    
    // Rotation if not zero
    if element.rotation != 0 {
        valueComponents.append("Rotation: \(Int(element.rotation)) degrees")
    }
    
    // Opacity if not full
    if element.opacity != 1.0 {
        valueComponents.append("Opacity: \(Int(element.opacity * 100))%")
    }
    
    // Text content for text elements
    if element.type == .text && !element.text.isEmpty {
        valueComponents.append("Text: \(element.text)")
    }
    
    return valueComponents.joined(separator: ", ")
}