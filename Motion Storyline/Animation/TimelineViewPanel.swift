import SwiftUI
import AppKit
import Combine
import Foundation

/// A resizable timeline panel for the bottom of the canvas
struct TimelineViewPanel: View {
    @ObservedObject var animationController: AnimationController
    @Binding var isPlaying: Bool
    @Binding var timelineHeight: CGFloat
    @Binding var timelineOffset: Double
    @Binding var selectedElement: CanvasElement?
    @Binding var timelineScale: Double
    
    // Audio layers for timeline display
    var audioLayers: [AudioLayer] = []
    var audioLayerManager: AudioLayerManager?
    var onRemoveAudioLayer: ((AudioLayer) -> Void)?
    
    // Available height from parent container for proper constraint calculation
    var availableParentHeight: CGFloat = 0
    
    // State for keyframe editing
    @State private var selectedKeyframeTime: Double? = nil
    @State private var newKeyframeTime: Double = 0.0
    @State private var isAddingKeyframe: Bool = false
    @State private var propertyId: String = ""
    @State private var propertyType: AnimatableProperty.PropertyType = .position
    
    // Updated height constraints for flexible resizing
    let minHeight: CGFloat = 60   // Small minimum height for collapsed state
    let maxHeight: CGFloat = 3000 // High absolute maximum to allow full screen usage
    
    // Dynamic constraints based on available space
    @State private var availableHeight: CGFloat = 0
    @State private var dynamicMaxHeight: CGFloat = 1200
    @State private var screenHeight: CGFloat = 0
    
    // Resize handle height for calculations
    private let resizeHandleHeight: CGFloat = 14 // 12 + 2 for padding
    private let toolbarHeight: CGFloat = 50 // Approximate height of controls toolbar
    private let safetyMargin: CGFloat = 10 // Minimal margin to maximize usable timeline space
    
    // Track drag state to prevent conflicts with dynamic constraint updates
    @State private var isDragging: Bool = false
    @State private var dragStartHeight: CGFloat = 0
    @State private var dragConstraints: (min: CGFloat, max: CGFloat) = (0, 0)
    
    var onAddKeyframe: (Double) -> Void = { _ in }
    
    /// A resize handle for the timeline area
    private var timelineResizeHandle: some View {
        ZStack {
            // Background line/divider
            Divider()
            
            // Visual handle indicator with dynamic styling based on constraints
            HStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(handleColor)
                        .frame(width: 20, height: 3)
                }
            }
        }
        .frame(height: 12) // Height of the resize handle area
        .padding(.vertical, 1)
        .contentShape(Rectangle()) // Make the entire area draggable
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    // Set dragging state and capture constraints at the start of drag
                    if !isDragging {
                        isDragging = true
                        dragStartHeight = timelineHeight
                        
                        // Capture the constraints at the start of the drag to prevent snapping
                        let effectiveMaxHeight = min(maxHeight, dynamicMaxHeight)
                        let effectiveMinHeight = minHeight
                        dragConstraints = (min: effectiveMinHeight, max: effectiveMaxHeight)
                                            }
                    
                    // Calculate new height based on mouse movement
                    // For a top resize handle on a bottom panel, dragging up should increase height
                    // and dragging down should decrease height, so we subtract the translation
                    // Using global coordinate space ensures accurate tracking regardless of view transformations
                    let mouseMovement = -value.translation.height // Negative because dragging up should increase height
                    let proposedHeight = dragStartHeight + mouseMovement
                    
                    // Use the captured constraints from the start of the drag
                    let newHeight = min(dragConstraints.max, max(dragConstraints.min, proposedHeight))
                    
                    // Update height immediately for responsive feedback
                    timelineHeight = newHeight
                    
                }
                .onEnded { value in
                    // Calculate final height and apply constraints one more time
                    let mouseMovement = -value.translation.height
                    let finalHeight = dragStartHeight + mouseMovement
                    let constrainedHeight = min(dragConstraints.max, max(dragConstraints.min, finalHeight))
                    timelineHeight = constrainedHeight
                                        
                    // Clear dragging state
                    isDragging = false
                    dragStartHeight = 0
                    dragConstraints = (0, 0)
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
    
    /// Accessibility hint for the timeline panel
    private var timelineAccessibilityHint: String {
        if selectedElement == nil {
            return "Timeline panel for animation control. Select an element on the canvas to begin editing animations. Current height: \(Int(timelineHeight)) pixels"
        } else {
            let elementName = selectedElement?.displayName ?? "selected element"
            return "Timeline panel showing animation controls and keyframe editor for \(elementName). Drag the resize handle to adjust height. Current height: \(Int(timelineHeight)) pixels"
        }
    }
    
    /// Color for the resize handle that indicates constraint status
    private var handleColor: Color {
        let effectiveMaxHeight = min(maxHeight, dynamicMaxHeight)
        let effectiveMinHeight = minHeight
        
        // Use larger thresholds to reduce flickering and make transitions smoother
        let threshold: CGFloat = 10
        
        // If we're at or near the maximum height, use a warning color
        if timelineHeight >= effectiveMaxHeight - threshold {
            return Color.orange
        }
        // If we're at the minimum height, use a different indicator
        else if timelineHeight <= effectiveMinHeight + threshold {
            return Color.blue
        }
        // If timeline is collapsed and no element is selected, use a subtle hint
        else if selectedElement == nil && timelineHeight <= minHeight + 20 {
            return Color.gray.opacity(0.6)
        }
        // Normal state - use an accent color to indicate it's interactive
        else {
            return Color.accentColor.opacity(0.8)
        }
    }
    
    private var resizeHandleView: some View {
        timelineResizeHandle
            .accessibilityIdentifier("timeline-resize-handle")
            .accessibilityLabel("Timeline Resize Handle")
            .accessibilityHint("Drag to adjust timeline height")
    }
    
    private var controlsToolbar: some View {
        HStack {
            playPauseButton
            resetButton
            Spacer()
            timeDisplay
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-controls")
        .accessibilityLabel("Animation Controls")
        .accessibilityHint("Control animation playback and view timing information")
    }
    
    private var playPauseButton: some View {
        Button(action: {
            if animationController.isPlaying {
                animationController.pause()
                audioLayerManager?.pause()
                isPlaying = false
            } else {
                animationController.play()
                audioLayerManager?.play()
                isPlaying = true
            }
        }) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .accessibilityIdentifier(isPlaying ? "pause-button" : "play-button")
        .accessibilityLabel(isPlaying ? "Pause Animation" : "Play Animation")
        .accessibilityHint("Toggle animation playback")
    }
    
    private var resetButton: some View {
        Button(action: {
            animationController.reset()
            audioLayerManager?.seekToTime(0.0)
            isPlaying = false
        }) {
            Image(systemName: "backward.end.fill")
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .accessibilityIdentifier("reset-button")
        .accessibilityLabel("Reset Animation")
        .accessibilityHint("Reset animation to beginning")
    }
    
    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1fs", animationController.currentTime))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.gray)
            
            Text("/")
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField("", text: Binding(
                get: { String(format: "%.1f", animationController.duration) },
                set: { newValue in
                    if let newDuration = Double(newValue), newDuration > 0 {
                        animationController.duration = newDuration
                    }
                }
            ))
            .textFieldStyle(.plain)
            .font(.caption)
            .monospacedDigit()
            .foregroundColor(.primary)
            .frame(width: 40)
            .multilineTextAlignment(.trailing)
            
            Text("s")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .accessibilityIdentifier("time-display")
        .accessibilityLabel("Current time: \(String(format: "%.1f", animationController.currentTime)) seconds of \(String(format: "%.1f", animationController.duration)) seconds. Duration is editable.")
    }
    
    private var timelineEditorArea: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 4) {
                audioTimelineSection
                mainEditorContent
            }
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-editor-area")
        .accessibilityLabel("Timeline Editor")
        .accessibilityHint("Contains timeline ruler and keyframe editing tools. Scroll to view more content if needed.")
    }
    
    private var audioTimelineSection: some View {
        Group {
            if !audioLayers.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("Audio Tracks")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(audioLayers.count) track\(audioLayers.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    if let audioLayerManager = audioLayerManager {
                        AudioLayerTimelineView(
                            audioLayerManager: audioLayerManager,
                            currentTime: $animationController.currentTime,
                            isPlaying: $isPlaying,
                            scale: timelineScale,
                            offset: $timelineOffset,
                            timelineDuration: animationController.duration
                        )
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier("audio-layers-timeline")
                        .accessibilityLabel("Audio layers timeline")
                    }
                }
                .padding(.bottom, 12)
                
                Divider()
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private var mainEditorContent: some View {
        Group {
            if selectedElement == nil {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("Select an element on the canvas to edit its animation properties")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Timeline will expand automatically when an element is selected")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    if audioLayers.isEmpty {
                        Text("Import audio from the Media Browser to see audio tracks here")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            } else {
                KeyframeEditorView(animationController: animationController, selectedElement: $selectedElement)
                    .layoutPriority(1)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("keyframe-editor")
                    .accessibilityLabel("Keyframe Editor")
                    .accessibilityHint("Edit animation keyframes for the selected element")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            resizeHandleView
            controlsToolbar
            Divider()
            timelineEditorArea
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(height: timelineHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeline-panel")
        .accessibilityLabel("Animation Timeline Panel")
        .accessibilityHint(timelineAccessibilityHint)
                .onAppear {
                    // Set up synchronization with the animation controller's playback state
                    isPlaying = animationController.isPlaying
                    
                    // Get screen height for dynamic constraints
                    if let screen = NSScreen.main {
                        screenHeight = screen.frame.height
                    }
                    
                    // Ensure timeline starts with a visible height
                    if timelineHeight < minHeight {
                        timelineHeight = minHeight
                    }
                    
                    // Calculate initial available space and dynamic constraints using parent height
                    // updateDynamicConstraints functionality removed due to scope issues
                }
                .onChange(of: animationController.isPlaying) { oldValue, newIsPlaying in
                    // Keep our local isPlaying in sync with the controller
                    if isPlaying != newIsPlaying {
                        isPlaying = newIsPlaying
                    }
                }
                .onChange(of: availableParentHeight) { oldValue, newHeight in
                    // Update dynamic constraints when parent available space changes
                    // updateDynamicConstraints functionality removed due to scope issues
                }
            .onChange(of: selectedElement) { oldValue, newValue in
                // Keep current timeline height when element selection changes
                // Only enforce constraints if height is outside acceptable bounds
                let effectiveMaxHeight = min(maxHeight, dynamicMaxHeight)
                let effectiveMinHeight = minHeight
                
                // Ensure current height is within acceptable bounds
                if timelineHeight > effectiveMaxHeight {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        timelineHeight = effectiveMaxHeight
                    }
                } else if timelineHeight < effectiveMinHeight {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        timelineHeight = effectiveMinHeight
                    }
                }
            }
        }
    }

#if !DISABLE_PREVIEWS
struct TimelineViewPanel_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample animation controller for the preview
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Add some sample keyframes
        let positionTrack: KeyframeTrack<CGPoint> = animationController.addTrack(id: "element1_position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 300)))
        
        return TimelineViewPanel(
            animationController: animationController,
            isPlaying: .constant(false),
            timelineHeight: .constant(300),
            timelineOffset: .constant(0.0),
            selectedElement: .constant(nil),
            timelineScale: .constant(1.0),
            audioLayers: [],
            audioLayerManager: nil,
            onRemoveAudioLayer: nil,
            availableParentHeight: 600
        )
        .frame(width: 800, height: 300)
        .padding()
    }
}
#endif 