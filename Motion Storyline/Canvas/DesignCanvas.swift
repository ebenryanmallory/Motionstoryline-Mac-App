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
// - Services/CanvasExport.swift: Export functionality
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
    
    // Grid & rulers settings
    @State internal var showGrid: Bool = true
    @State internal var gridSize: CGFloat = 20
    @State internal var snapToGridEnabled: Bool = true
    @State internal var showRulers: Bool = false
    
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
    
    // Animation property manager
    private var animationPropertyManager: AnimationPropertyManager {
        AnimationPropertyManager(animationController: animationController)
    }
    
    // Audio layer management
    @StateObject internal var audioLayerManager = AudioLayerManager()
    @State internal var audioLayers: [AudioLayer] = []
    
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
    
    // Preferences for canvas settings
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    
    // Canvas dimensions - HD aspect ratio (16:9)
    @State internal var canvasWidth: CGFloat = 1280
    @State internal var canvasHeight: CGFloat = 720
    
    // CRITICAL: Store the original project URL for restoration during save operations
    // This prevents filename mismatches that cause changes not to persist between sessions
    // The URL is stored when a project is loaded and used to restore the correct projectURL
    // when it gets cleared by DocumentManager configuration operations
    @State private var originalProjectURL: URL?
    
    // Computed property for aspect ratio text
    private var aspectRatioText: String {
        let ratio = canvasWidth / canvasHeight
        let gcd = greatestCommonDivisor(Int(canvasWidth), Int(canvasHeight))
        let simplifiedWidth = Int(canvasWidth) / gcd
        let simplifiedHeight = Int(canvasHeight) / gcd
        
        // Check for common aspect ratios
        if abs(ratio - 16.0/9.0) < 0.01 {
            return "16:9"
        } else if abs(ratio - 4.0/3.0) < 0.01 {
            return "4:3"
        } else if abs(ratio - 1.0) < 0.01 {
            return "1:1"
        } else if abs(ratio - 21.0/9.0) < 0.01 {
            return "21:9"
        } else if abs(ratio - 3.0/2.0) < 0.01 {
            return "3:2"
        } else {
            return "\(simplifiedWidth):\(simplifiedHeight)"
        }
    }
    
    // Helper function to calculate greatest common divisor
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        return b == 0 ? a : greatestCommonDivisor(b, a % b)
    }
    
    // State variables for path drawing

    
    // Media management
    @State private var showMediaBrowser = false
    @State private var showCameraView = false
    @State private var showScreenRecordingView = false
    @State private var showRecordingPicker = false
    @State private var showAuthenticationView = false
    
    // Recording settings
    @State private var recordingIncludeMicrophone = true
    @State private var recordingCountdown = true
    
    // Notification state
    @State private var showSuccessNotification = false
    @State private var notificationMessage = ""
    @State private var isNotificationError = false
    
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
            
            // Success notification overlay
            if showSuccessNotification {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: isNotificationError ? "xmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(isNotificationError ? .red : .green)
                        Text(notificationMessage)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Add command handlers for saving
        .onCommand(#selector(NSDocument.save(_:))) {
            handleSaveWorkingFile()
        }
        .onCommand(#selector(NSDocument.saveAs(_:))) {
            handleExportProjectAs()
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
            project: appState.selectedProject, // Pass the full project
            onClose: {
                // Check for unsaved changes before closing
                handleCloseWithUnsavedChanges()
            },
            onCameraRecord: {
                showRecordingPicker = true
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
            showRulers: Binding<Bool>(get: { self.showRulers }, set: { self.showRulers = $0 }),
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
            liveAudioLayers: { self.audioLayers },
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
            
            // Canvas dimensions indicator with proper z-index positioning
            HStack {
                Text("Canvas: \(Int(canvasWidth))×\(Int(canvasHeight)) (\(aspectRatioText))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .opacity(0.8)
                    )
                    .accessibilityIdentifier("canvas-dimensions")
                    .accessibilityLabel("Canvas dimensions: \(Int(canvasWidth)) by \(Int(canvasHeight)) pixels, \(aspectRatioText) aspect ratio")
                
                Spacer()
            }
            .padding(.bottom, 8)
            .zIndex(10) // Ensure it appears above canvas background
            
            Divider() // Add visual separator between toolbar and canvas
        }
        // Enforce that toolbar section doesn't expand or get pushed by canvas
        .frame(maxHeight: 100) // Increased fixed height for toolbar section to accommodate background
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
                audioLayers: audioLayers,
                audioLayerManager: audioLayerManager,
                onRemoveAudioLayer: removeAudioLayer,
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
            handleViewAppear()
        }
        .onChange(of: selectedElementId) { oldValue, newValue in
            handleSelectedElementIdChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: selectedElement) { oldValue, newValue in
            handleSelectedElementChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: appState.selectedProject) { oldValue, newValue in
            print("🔄 Selected project changed from \(oldValue?.name ?? "none") to \(newValue?.name ?? "none")")
            loadCurrentProject()
        }
        .onChange(of: showSuccessNotification) { oldValue, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessNotification = false
                    }
                }
            }
        }
        .onDisappear {
            handleViewDisappear()
        }
        .modifier(AppStateChangeModifier(
            appState: appState,
            documentManager: documentManager,
            autoSaveProject: autoSaveProject
        ))
        .modifier(PreferencesChangeModifier(
            preferencesViewModel: preferencesViewModel,
            documentManager: documentManager,
            hasInitializedProject: hasInitializedProject,
            canvasWidth: $canvasWidth,
            canvasHeight: $canvasHeight,
            showGrid: $showGrid,
            gridSize: $gridSize,
            snapToGridEnabled: $snapToGridEnabled,
            markDocumentAsChanged: markDocumentAsChanged
        ))
        .modifier(SheetModifier(
            showingExportModal: $showingExportModal,
            showCameraView: $showCameraView,
            showScreenRecordingView: $showScreenRecordingView,
            showRecordingPicker: $showRecordingPicker,
            showMediaBrowser: $showMediaBrowser,
            showAuthenticationView: $showAuthenticationView,
            recordingIncludeMicrophone: $recordingIncludeMicrophone,
            recordingCountdown: $recordingCountdown,
            currentExportAsset: currentExportAsset,
            canvasWidth: Int(canvasWidth),
            canvasHeight: Int(canvasHeight),
            appState: appState,
            animationController: animationController,
            canvasElements: canvasElements,
            audioLayers: audioLayers,
            authManager: authManager,
            addElementToCanvas: { newElement in
                canvasElements.append(newElement)
                handleElementSelection(newElement)
                markDocumentAsChanged(actionName: "Add Media Element")
            },
            addAudioToTimeline: { audioLayer in
                addAudioLayerToTimeline(audioLayer)
                markDocumentAsChanged(actionName: "Add Audio Layer")
            },
            onMediaAssetImported: {
                markDocumentAsChanged(actionName: "Import Media Asset")
            },
            currentTimelineTime: animationController.currentTime
        ))
        .overlay {
            exportProgressOverlay
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
        // Accept drops from the media browser (plain text JSON payload or file URL)
        .onDrop(of: [UTType.plainText, UTType.fileURL], delegate: MediaAssetDropDelegate(
            performAdd: { newElement in
                canvasElements.append(newElement)
                handleElementSelection(newElement)
                markDocumentAsChanged(actionName: "Add Media Element (Drop)")
            },
            computeCanvasPosition: { point in
                // Convert drop point from view space into canvas coordinate space by inverting transforms
                let unoffsetX = point.x - viewportOffset.width
                let unoffsetY = point.y - viewportOffset.height
                return CGPoint(x: unoffsetX / zoom, y: unoffsetY / zoom)
            }
        ))
    }
    
    private var canvasBaseLayersView: some View {
        Group {
            // Grid background (bottom layer)
            GridBackground(
                showGrid: showGrid,
                gridSize: gridSize,
                gridColor: preferencesViewModel.gridColor,
                canvasBackgroundColor: preferencesViewModel.canvasBackgroundColor
            )
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
        
        // Set canvas dimensions in document model as single source of truth
        documentManager.canvasWidth = Double(projectData.canvasWidth)
        documentManager.canvasHeight = Double(projectData.canvasHeight)
        
        // Update grid settings to match loaded preferences
        showGrid = preferencesViewModel.showGrid
        gridSize = CGFloat(preferencesViewModel.gridSize)
        
        // Update the current project with loaded media assets
        if self.appState.selectedProject != nil {
            self.appState.selectedProject?.mediaAssets = projectData.mediaAssets
        }
        
        // Load and apply audio layers
        self.audioLayers = projectData.audioLayers
        self.audioLayerManager.clearAllAudioLayers()
        for audioLayer in projectData.audioLayers {
            self.audioLayerManager.addAudioLayer(audioLayer)
        }
        print("Loaded \(projectData.audioLayers.count) audio layers into timeline")
        
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
        
        // Set animation controller for audio layer manager
        self.audioLayerManager.setAnimationController(self.animationController)
        
        // Set up audio layer change callback for document tracking
        self.audioLayerManager.onAudioLayerChanged = { actionName in
            Task { @MainActor in
                self.markDocumentAsChanged(actionName: actionName)
            }
        }

        // Configure DocumentManager with the newly loaded state
        // The projectURL is preserved during this configuration
        configureDocumentManager()

        // Update AppState
        if let projectURL = documentManager.projectURL {
            let rawName = projectURL.deletingPathExtension().lastPathComponent
            appState.currentProjectName = appState.cleanProjectName(rawName)
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
            currentProject: appState.selectedProject,
            audioLayers: self.audioLayers,
            preferencesViewModel: self.preferencesViewModel
        )
        print("🔧 DocumentManager configured with \(canvasElements.count) elements, \(animationController.getAllTracks().count) tracks, \(audioLayers.count) audio layers, hasUnsavedChanges: \(documentManager.hasUnsavedChanges)")
    }
    
    internal func recordUndoState(actionName: String) {
        // CRITICAL: Restore projectURL if it was cleared by previous operations
        // This prevents save failures that cause changes not to persist between sessions
        if documentManager.projectURL == nil {
            if let originalURL = originalProjectURL {
                // Use the original URL from when the project was loaded
                documentManager.projectURL = originalURL
            } else if let selectedProject = appState.selectedProject {
                // Fallback: reconstruct URL from selectedProject (maintains original structure)
                documentManager.projectURL = constructProjectURL(for: selectedProject)
            }
        }
        
        // Preserve the projectURL around DocumentManager configuration
        let preservedProjectURL = documentManager.projectURL
        
        // Ensure DocumentManager has the latest state before capturing
        configureDocumentManager()
        
        // Restore the projectURL if it was cleared during configuration
        if documentManager.projectURL == nil && preservedProjectURL != nil {
            documentManager.projectURL = preservedProjectURL
        }
        
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
        
        // CRITICAL: Restore projectURL if it was cleared by previous operations
        // This prevents save failures that cause changes not to persist between sessions
        if documentManager.projectURL == nil {
            if let originalURL = originalProjectURL {
                // Use the original URL from when the project was loaded
                documentManager.projectURL = originalURL
            } else if let selectedProject = appState.selectedProject {
                // Fallback: reconstruct URL from selectedProject (maintains original structure)
                documentManager.projectURL = constructProjectURL(for: selectedProject)
            }
        }
        
        // Preserve the projectURL around DocumentManager configuration
        let preservedProjectURL = documentManager.projectURL
        
        // Update the document manager with the current state FIRST
        // This ensures the DocumentManager always has the latest data for auto-save
        configureDocumentManager()
        
        // Restore the projectURL if it was cleared during configuration
        if documentManager.projectURL == nil && preservedProjectURL != nil {
            documentManager.projectURL = preservedProjectURL
        }
        
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
        animationPropertyManager.updateAnimationPropertiesForSelectedElement(selectedElement, canvasElements: $canvasElements)
        
        // Force UI update by triggering objectWillChange
        isProgrammaticChange = true
        isProgrammaticChange = false
    }
    
    // MARK: - Audio Management
    
    /// Adds an audio layer to the timeline and audio layer manager
    internal func addAudioLayerToTimeline(_ audioLayer: AudioLayer) {
        // Use the enhanced AudioLayerManager method
        audioLayerManager.addAudioLayerToTimeline(
            audioLayer,
            project: &appState.selectedProject,
            markChanged: { actionName in
                self.markDocumentAsChanged(actionName: actionName)
            }
        )
        
        // Update local audioLayers array to stay in sync
        audioLayers = audioLayerManager.audioLayers
    }
    
    /// Removes an audio layer from the timeline
    internal func removeAudioLayer(_ audioLayer: AudioLayer) {
        // Use the enhanced AudioLayerManager method
        audioLayerManager.removeAudioLayerFromTimeline(
            audioLayer,
            project: &appState.selectedProject,
            markChanged: { actionName in
                self.markDocumentAsChanged(actionName: actionName)
            }
        )
        
        // Update local audioLayers array to stay in sync
        audioLayers = audioLayerManager.audioLayers
    }
    
    // MARK: - Element Deletion Management
    
    /// Centralized function to delete an element and clean up all associated animation tracks
    /// This function should be called from all element deletion entry points
    /// - Parameters:
    ///   - elementId: The ID of the element to delete
    ///   - actionName: The name of the action for undo/redo tracking
    internal func deleteElementAndCleanupTracks(elementId: UUID, actionName: String) {
        // Record state before deletion for undo/redo
        recordStateBeforeChange(actionName: actionName)
        
        // Remove element from canvas
        canvasElements.removeAll { $0.id == elementId }
        
        // Clean up all animation tracks associated with this element
        cleanupAnimationTracksForElement(elementId: elementId)
        
        // Clear selection if this element was selected
        if selectedElementId == elementId {
            selectedElementId = nil
        }
        
        // Mark document as changed
        markDocumentAsChanged(actionName: actionName)
        
        print("🗑️ Element deleted and \(actionName) completed. Animation tracks cleaned up for element: \(elementId)")
    }
    
    /// Removes all animation tracks associated with a specific element
    /// - Parameter elementId: The ID of the element whose tracks should be removed
    private func cleanupAnimationTracksForElement(elementId: UUID) {
        // Use the AnimationController's built-in cleanup method
        animationController.removeTracksForElement(elementId: elementId)
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
        
        // Cancel any pending auto-save timer to prevent conflicts
        autoSaveTimer?.invalidate()
        
        // Auto-save the project before closing
        print("🔄 Auto-saving project before closing...")
        autoSaveProject()
        
        // Small delay to ensure save completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
        
        // Schedule a new auto-save after a 3-second delay
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            
            // Check current state at the time of execution, not when timer was set
            let hasUnsavedChanges = self.documentManager.hasUnsavedChanges
            let currentIsClosing = self.isClosing
            
            // Only auto-save if we have unsaved changes and aren't closing
            if hasUnsavedChanges && !currentIsClosing {
                print("⏰ Scheduled auto-save triggered")
                self.autoSaveProject()
            } else {
                print("⏰ Scheduled auto-save skipped - hasUnsavedChanges: \(hasUnsavedChanges), isClosing: \(currentIsClosing)")
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
        guard let project = appState.selectedProject else {
            print("Could not create default project file: no selected project")
            return
        }
        
        // Use the UUID-based URL construction for uniqueness
        let saveURL = constructProjectURL(for: project)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = project.name // Use the actual project name, not the filename
        
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
        guard let project = appState.selectedProject else {
            print("Could not prepare project for auto-save: no selected project")
            return
        }
        
        // Use the UUID-based URL construction for uniqueness
        let saveURL = constructProjectURL(for: project)
        
        // Set the project URL for future saves
        documentManager.projectURL = saveURL
        appState.currentProjectName = project.name // Use the actual project name, not the filename
        
        print("Prepared new project for auto-save at: \(saveURL.path)")
    }
    
    /// Loads a project from the file system based on the selected project
    private func loadProjectFromSelection(_ project: Project) {
        print("🔄 Loading project from selection: \(project.name)")
        
        // Create the expected file path based on project UUID for uniqueness
        let projectURL = constructProjectURL(for: project)
        
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
                    mediaAssets: loadedTuple.mediaAssets,
                    audioLayers: loadedTuple.audioLayers
                )
                
                print("✅ Successfully loaded project with \(loadedTuple.elements.count) elements")
                
                // CRITICAL: Store the original project URL for restoration during save operations
                // This prevents filename mismatches that cause changes not to persist between sessions
                originalProjectURL = projectURL
                
                // CRITICAL: Set DocumentManager projectURL before applying data
                // This ensures auto-save operations use the correct project file
                documentManager.projectURL = projectURL
                
                // Apply the loaded project data
                applyProjectData(projectData: projectDataInstance)
                
                // IMPORTANT: Do NOT modify appState.selectedProject?.name here!
                // The selectedProject must maintain its original structure for URL reconstruction.
                // Display names are handled separately in the TopBar using cleanProjectName().
                
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
    
    /// Constructs the expected file URL for a project using its unique ID
    private func constructProjectURL(for project: Project) -> URL {
        // Ensure the projects directory exists and get its URL
        guard let projectsFolder = ensureProjectsDirectoryExists() else {
            fatalError("Could not access or create Motion Storyline Projects directory")
        }
        
        // Use project UUID to ensure uniqueness, with human-readable name as prefix
        let sanitizedName = project.name.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
        let baseFilename = sanitizedName.isEmpty ? "Untitled Project" : sanitizedName
        
        // Create filename using both name and UUID for uniqueness
        let filename = "\(baseFilename)_\(project.id.uuidString).storyline"
        return projectsFolder.appendingPathComponent(filename)
    }
    
    /// Legacy method for backward compatibility - constructs URL based on project name only
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
        
        // Reset canvas properties using document manager
        canvasWidth = CGFloat(documentManager.canvasWidth)
        canvasHeight = CGFloat(documentManager.canvasHeight)
        zoom = 1.0
        viewportOffset = .zero
        selectedElementId = nil
        selectedElement = nil
        
        // Reset animation controller
        animationController.reset()
        animationController.setup(duration: 3.0)
        
        // Set up initial animations for default elements
        setupInitialAnimations()
        
        // Set up document manager with the correct project URL for this new project
        let projectURL = constructProjectURL(for: project)
        documentManager.projectURL = projectURL
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

// MARK: - Extracted Methods for View Modifiers

extension DesignCanvas {
    private func handleViewAppear() {
        // Perform one-time initialization
        if !hasInitializedProject {
            hasInitializedProject = true
            
            canvasWidth = CGFloat(documentManager.canvasWidth)
            canvasHeight = CGFloat(documentManager.canvasHeight)
            
            showGrid = preferencesViewModel.showGrid
            gridSize = CGFloat(preferencesViewModel.gridSize)
            snapToGridEnabled = preferencesViewModel.showGrid && preferencesViewModel.snapToGrid
            
            keyMonitorController.setupMonitor(
                onSpaceDown: {
                    isSpaceBarPressed = true
                    NSCursor.openHand.set()
                },
                onSpaceUp: {
                    isSpaceBarPressed = false
                    if selectedTool == .select {
                        NSCursor.arrow.set()
                    } else if selectedTool == .rectangle || selectedTool == .ellipse {
                        NSCursor.crosshair.set()
                    }
                }
            )
            
            keyMonitorController.setupCanvasKeyboardShortcuts(
                zoomIn: zoomIn,
                zoomOut: zoomOut,
                resetZoom: resetZoom,
                saveProject: { 
                    print("💾 Manual save triggered via keyboard shortcut")
                    self.handleSaveWorkingFile()
                },
                deleteSelectedElement: {
                    if let elementId = selectedElementId {
                        deleteElementAndCleanupTracks(elementId: elementId, actionName: "Delete Element")
                    }
                }
            )

            // Wire global Delete command to post a notification that the canvas listens for
            appState.deleteAction = {
                NotificationCenter.default.post(
                    name: NSNotification.Name("DeleteSelectedCanvasElement"),
                    object: nil
                )
            }

            // Wire clipboard and file actions
            appState.cutAction = { [self] in cutSelectedElement() }
            appState.copyAction = { [self] in copySelectedElement() }
            appState.pasteAction = { [self] in pasteElement() }
            appState.selectAllAction = { [self] in selectAllElements() }
            appState.saveAction = { [self] in handleSaveWorkingFile() }
            appState.saveAsAction = { [self] in handleExportProjectAs() }
            appState.openProjectAction = { [self] in openProject() }
            // Listen for new screen recordings and import into project
            NotificationCenter.default.addObserver(forName: Notification.Name("NewScreenRecordingAvailable"), object: nil, queue: .main) { notification in
                guard var project = self.appState.selectedProject else { return }
                if let userInfo = notification.userInfo, let url = userInfo["url"] as? URL {
                    let name = url.lastPathComponent
                    let dimensions = MediaAsset.extractDimensions(from: url, type: .video)
                    let asset = MediaAsset(
                        name: name,
                        type: .video,
                        url: url,
                        duration: AVAsset(url: url).duration.seconds,
                        thumbnail: "video_thumbnail",
                        width: dimensions?.width,
                        height: dimensions?.height
                    )
                    project.addMediaAsset(asset)
                    self.appState.selectedProject = project
                    // Mark as changed and optionally show media browser
                    self.markDocumentAsChanged(actionName: "Import Screen Recording")
                    
                    // Show success notification
                    withAnimation {
                        self.notificationMessage = "Screen recording saved and added to Media Browser"
                        self.isNotificationError = false
                        self.showSuccessNotification = true
                    }
                }
            }

            // Listen for global delete notifications and perform deletion when applicable
            NotificationCenter.default.addObserver(forName: NSNotification.Name("DeleteSelectedCanvasElement"), object: nil, queue: .main) { _ in
                if let elementId = self.selectedElementId {
                    self.deleteElementAndCleanupTracks(elementId: elementId, actionName: "Delete Element")
                }
            }
            
            appState.registerUndoRedoActions(
                undo: performUndo,
                redo: performRedo,
                canUndoPublisher: undoRedoManager.$canUndo.eraseToAnyPublisher(),
                canRedoPublisher: undoRedoManager.$canRedo.eraseToAnyPublisher(),
                hasUnsavedChangesPublisher: documentManager.$hasUnsavedChanges.eraseToAnyPublisher(),
                currentProjectURLPublisher: documentManager.$projectURL.eraseToAnyPublisher()
            )
        }
        
        // Load project data every time we appear (this was the fix for the bug)
        loadCurrentProject()
    }
    
    private func loadCurrentProject() {
        if let selectedProject = appState.selectedProject {
            print("🎯 Loading project from selection: \(selectedProject.name)")
            loadProjectFromSelection(selectedProject)
        } else {
            print("🆕 No selected project, setting up new project with default elements")
            canvasElements = createDefaultCanvasElements()
            
            animationController.setup(duration: 3.0)
            setupInitialAnimations()
            
            audioLayerManager.setAnimationController(animationController)
            
            audioLayerManager.onAudioLayerChanged = { actionName in
                Task { @MainActor in
                    self.markDocumentAsChanged(actionName: actionName)
                }
            }
            
            configureDocumentManager()
            // Note: prepareNewProjectForAutoSave() removed here because there's no selectedProject
            // The project URL will be set when a project is actually selected or created
        }
    }
    
    private func handleViewDisappear() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        keyMonitorController.teardownMonitor()
        appState.clearUndoRedoActions()
        
        if documentManager.hasUnsavedChanges && !isClosing {
            print("🔄 Auto-saving project on view disappear...")
            autoSaveProject()
        }
    }

    // MARK: - Clipboard Operations (basic single-element semantics)
    private func copySelectedElement() {
        guard let elementId = selectedElementId,
              let element = canvasElements.first(where: { $0.id == elementId }) else { return }
        do {
            let data = try JSONEncoder().encode(element)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setData(data, forType: .string)
            print("📋 Copied element \(element.displayName)")
        } catch {
            print("Failed to encode element for copy: \(error)")
        }
    }

    private func cutSelectedElement() {
        guard let elementId = selectedElementId,
              let element = canvasElements.first(where: { $0.id == elementId }) else { return }
        copySelectedElement()
        deleteElementAndCleanupTracks(elementId: elementId, actionName: "Cut Element")
        print("✂️ Cut element \(element.displayName)")
    }

    private func pasteElement() {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: .string) else { return }
        do {
            var element = try JSONDecoder().decode(CanvasElement.self, from: data)
            recordStateBeforeChange(actionName: "Paste Element")
            element.id = UUID()
            // Offset pasted element slightly for visibility
            element.position = CGPoint(x: element.position.x + 20, y: element.position.y + 20)
            element.displayName = "Copy of \(element.displayName)"
            canvasElements.append(element)
            handleElementSelection(element)
            markDocumentAsChanged(actionName: "Paste Element")
            print("📎 Pasted element \(element.displayName)")
        } catch {
            print("Failed to decode element from pasteboard: \(error)")
        }
    }

    private func selectAllElements() {
        // For now, select the first element to indicate selection. Extend to multi-select if needed.
        if let first = canvasElements.first {
            handleElementSelection(first)
        }
    }
    
    private func handleSelectedElementIdChange(oldValue: UUID?, newValue: UUID?) {
        if let elementId = newValue {
            selectedElement = canvasElements.first(where: { $0.id == elementId })
        } else {
            selectedElement = nil
        }
    }
    
    private func handleSelectedElementChange(oldValue: CanvasElement?, newValue: CanvasElement?) {
        guard !isProgrammaticChange else { return }
        
        print("🔍 Selected element changed: \(String(describing: newValue?.displayName))")
        print("🔍 Timeline height: \(timelineHeight), Preview enabled: \(showAnimationPreview)")
        
        if let updatedElement = newValue,
           let index = canvasElements.firstIndex(where: { $0.id == updatedElement.id }) {
            
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
                recordStateBeforeChange(actionName: "Update Element Properties")
                canvasElements[index] = updatedElement
                markDocumentAsChanged(actionName: "Update Element Properties")
            }
        }
    }
    
    private var exportProgressOverlay: some View {
        Group {
            if isExporting {
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
}

// MARK: - View Modifiers

struct AppStateChangeModifier: ViewModifier {
    let appState: AppStateManager
    let documentManager: DocumentManager
    let autoSaveProject: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: appState.scenePhase) { oldPhase, newPhase in
                if newPhase == .background && documentManager.hasUnsavedChanges {
                    print("🔄 App going to background, auto-saving project...")
                    autoSaveProject()
                }
            }
    }
}

struct PreferencesChangeModifier: ViewModifier {
    let preferencesViewModel: PreferencesViewModel
    let documentManager: DocumentManager
    let hasInitializedProject: Bool
    @Binding var canvasWidth: CGFloat
    @Binding var canvasHeight: CGFloat
    @Binding var showGrid: Bool
    @Binding var gridSize: CGFloat
    @Binding var snapToGridEnabled: Bool
    let markDocumentAsChanged: (String) -> Void
    
    func body(content: Content) -> some View {
        content
            .onChange(of: documentManager.canvasWidth) { oldValue, newValue in
                if oldValue != newValue && hasInitializedProject {
                    canvasWidth = CGFloat(newValue)
                    markDocumentAsChanged("Change Canvas Width")
                }
            }
            .onChange(of: documentManager.canvasHeight) { oldValue, newValue in
                if oldValue != newValue && hasInitializedProject {
                    canvasHeight = CGFloat(newValue)
                    markDocumentAsChanged("Change Canvas Height")
                }
            }
            .onChange(of: preferencesViewModel.showGrid) { oldValue, newValue in
                if oldValue != newValue && hasInitializedProject {
                    showGrid = newValue
                    if !newValue {
                        snapToGridEnabled = false
                    } else {
                        snapToGridEnabled = preferencesViewModel.snapToGrid
                    }
                    markDocumentAsChanged("Change Grid Visibility")
                }
            }
            .onChange(of: preferencesViewModel.gridSize) { oldValue, newValue in
                if oldValue != newValue && hasInitializedProject {
                    gridSize = CGFloat(newValue)
                    markDocumentAsChanged("Change Grid Size")
                }
            }
            .onChange(of: preferencesViewModel.snapToGrid) { oldValue, newValue in
                if oldValue != newValue && hasInitializedProject && showGrid {
                    snapToGridEnabled = newValue
                    markDocumentAsChanged("Change Snap to Grid")
                }
            }
    }
}

struct SheetModifier: ViewModifier {
    @Binding var showingExportModal: Bool
    @Binding var showCameraView: Bool
    @Binding var showScreenRecordingView: Bool
    @Binding var showRecordingPicker: Bool
    @Binding var showMediaBrowser: Bool
    @Binding var showAuthenticationView: Bool
    @Binding var recordingIncludeMicrophone: Bool
    @Binding var recordingCountdown: Bool
    let currentExportAsset: AVAsset?
    let canvasWidth: Int
    let canvasHeight: Int
    let appState: AppStateManager
    let animationController: AnimationController
    let canvasElements: [CanvasElement]
    let audioLayers: [AudioLayer]
    let authManager: AuthenticationManager
    let addElementToCanvas: (CanvasElement) -> Void
    let addAudioToTimeline: (AudioLayer) -> Void
    let onMediaAssetImported: () -> Void
    let currentTimelineTime: TimeInterval
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingExportModal) {
                if let asset = currentExportAsset {
                    ExportModal(
                        asset: asset,
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight,
                        project: appState.selectedProject,
                        getAnimationController: { animationController },
                        getCanvasElements: { canvasElements },
                        getAudioLayers: { audioLayers },
                        onDismiss: {
                            showingExportModal = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showCameraView) {
                CameraRecordingView(
                    isPresented: $showCameraView,
                    includeMicrophone: recordingIncludeMicrophone,
                    countdown: recordingCountdown
                )
                .frame(width: 480, height: 360)
            }
            .sheet(isPresented: $showScreenRecordingView) {
                ScreenRecordingView(
                    isPresented: $showScreenRecordingView,
                    includeMicrophone: recordingIncludeMicrophone,
                    countdown: recordingCountdown
                )
                .frame(width: 720, height: 520)
            }
            .sheet(isPresented: $showRecordingPicker) {
                RecordingPickerSheet(
                    onScreen: { includeMicrophone, countdown in
                        recordingIncludeMicrophone = includeMicrophone
                        recordingCountdown = countdown
                        showScreenRecordingView = true
                    },
                    onCamera: { includeMicrophone, countdown in
                        recordingIncludeMicrophone = includeMicrophone
                        recordingCountdown = countdown
                        showCameraView = true
                    },
                    onBoth: { includeMicrophone, countdown in
                        recordingIncludeMicrophone = includeMicrophone
                        recordingCountdown = countdown
                        // For now open screen recording; camera overlay handled later via coordinator
                        showScreenRecordingView = true
                        showCameraView = true
                    },
                    isPresented: $showRecordingPicker
                )
            }
            .sheet(isPresented: $showMediaBrowser) {
                let projectBinding = Binding<Project>(
                    get: { appState.selectedProject ?? Project(name: "Untitled", thumbnail: "placeholder", lastModified: Date()) },
                    set: { appState.selectedProject = $0 }
                )
                MediaBrowserView(
                    project: projectBinding,
                    onAddElementToCanvas: addElementToCanvas,
                    onAddAudioToTimeline: addAudioToTimeline,
                    onMediaAssetImported: onMediaAssetImported,
                    currentTimelineTime: currentTimelineTime
                )
                .frame(width: 800, height: 600)
            }
            .sheet(isPresented: $showAuthenticationView) {
                AuthenticationView()
                    .environmentObject(authManager)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

// MARK: - Drop Support
private struct MediaAssetDropDelegate: DropDelegate {
    let performAdd: (CanvasElement) -> Void
    let computeCanvasPosition: (CGPoint) -> CGPoint

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText, UTType.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        let dropLocationInView = info.location
        let canvasPoint = computeCanvasPosition(dropLocationInView)

        // Try JSON payload first (from MediaBrowserView)
        if let provider = info.itemProviders(for: [UTType.plainText]).first {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                guard let data = data else { return }
                do {
                    struct DragPayload: Codable {
                        let name: String
                        let type: String
                        let url: String
                        let duration: Double?
                        let width: Double?
                        let height: Double?
                    }
                    let payload = try JSONDecoder().decode(DragPayload.self, from: data)
                    guard let url = URL(string: payload.url) else { return }
                    let size = CGSize(
                        width: payload.width != nil ? CGFloat(payload.width!) : 300,
                        height: payload.height != nil ? CGFloat(payload.height!) : 200
                    )
                    let element: CanvasElement
                    if payload.type.lowercased() == "image" {
                        element = CanvasElement.image(at: canvasPoint, assetURL: url, displayName: payload.name, size: size)
                    } else if payload.type.lowercased() == "video" || payload.type.lowercased() == "cameraRecording" {
                        element = CanvasElement.video(at: canvasPoint, assetURL: url, displayName: payload.name, size: size, videoDuration: payload.duration)
                    } else {
                        return
                    }
                    DispatchQueue.main.async {
                        performAdd(element)
                    }
                } catch {
                    // Fallback to fileURL route below if JSON fails
                    tryFileURLProviders(info: info, canvasPoint: canvasPoint)
                }
            }
            return true
        }

        // Fallback: file URL (drop from Finder or other sources)
        return tryFileURLProviders(info: info, canvasPoint: canvasPoint)
    }

    @discardableResult
    private func tryFileURLProviders(info: DropInfo, canvasPoint: CGPoint) -> Bool {
        guard let fileProvider = info.itemProviders(for: [UTType.fileURL]).first else { return false }
        fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            guard error == nil else { return }
            var url: URL?
            if let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                url = URL(string: str)
            } else if let nsurl = item as? NSURL {
                url = nsurl as URL
            } else if let u = item as? URL {
                url = u
            }
            guard let fileURL = url else { return }
            let filename = fileURL.lastPathComponent
            let type = UTType(filenameExtension: fileURL.pathExtension)
            let isImage = type?.conforms(to: .image) ?? false
            let isVideo = type?.conforms(to: .movie) ?? false
            let size = CGSize(width: 300, height: 200)
            let element: CanvasElement?
            if isImage {
                element = CanvasElement.image(at: canvasPoint, assetURL: fileURL, displayName: filename, size: size)
            } else if isVideo {
                element = CanvasElement.video(at: canvasPoint, assetURL: fileURL, displayName: filename, size: size)
            } else {
                element = nil
            }
            if let element = element {
                DispatchQueue.main.async {
                    performAdd(element)
                }
            }
        }
        return true
    }
}