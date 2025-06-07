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
    
    // Optional media assets for audio visualization
    var mediaAssets: [MediaAsset] = []
    var audioURL: URL? = nil
    var showAudioWaveform: Bool = false
    
    // State for keyframe editing
    @State private var selectedKeyframeTime: Double? = nil
    @State private var newKeyframeTime: Double = 0.0
    @State private var isAddingKeyframe: Bool = false
    @State private var propertyId: String = ""
    @State private var propertyType: AnimatableProperty.PropertyType = .position
    
    // Default height constraints
    let minHeight: CGFloat = 70
    let maxHeight: CGFloat = 600
    
    // Dynamic constraints based on available space
    @State private var availableHeight: CGFloat = 0
    @State private var dynamicMaxHeight: CGFloat = 600
    
    // Resize handle height for calculations
    private let resizeHandleHeight: CGFloat = 14 // 12 + 2 for padding
    private let toolbarHeight: CGFloat = 50 // Approximate height of controls toolbar
    private let safetyMargin: CGFloat = 100 // Minimum space to keep above timeline
    
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
            
            // Invisible hit area for the gesture
            Color.clear
                .contentShape(Rectangle())
                .frame(height: 12) // Larger hit area for better UX
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Calculate new height based on drag
                            let proposedHeight = timelineHeight - value.translation.height
                            
                            // Use dynamic max height that considers available space
                            let effectiveMaxHeight = min(maxHeight, dynamicMaxHeight)
                            
                            // Enforce constraints with dynamic maximum
                            timelineHeight = min(effectiveMaxHeight, max(minHeight, proposedHeight))
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
    
    /// Color for the resize handle that indicates constraint status
    private var handleColor: Color {
        let effectiveMaxHeight = min(maxHeight, dynamicMaxHeight)
        
        // If we're at or near the maximum height, use a warning color
        if timelineHeight >= effectiveMaxHeight - 5 {
            return Color.orange
        }
        // If we're at the minimum height, use a different indicator
        else if timelineHeight <= minHeight + 5 {
            return Color.blue
        }
        // Normal state
        else {
            return Color(NSColor.separatorColor)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Resize handle at the top
                timelineResizeHandle
                
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
            .frame(height: timelineHeight)
            .onAppear {
                // Set up synchronization with the animation controller's playback state
                isPlaying = animationController.isPlaying
                
                // Calculate initial available space and dynamic constraints
                updateDynamicConstraints(availableHeight: geometry.size.height)
            }
            .onChange(of: animationController.isPlaying) { oldValue, newIsPlaying in
                // Keep our local isPlaying in sync with the controller
                if isPlaying != newIsPlaying {
                    isPlaying = newIsPlaying
                }
            }
            .onChange(of: geometry.size.height) { oldValue, newHeight in
                // Update dynamic constraints when available space changes
                updateDynamicConstraints(availableHeight: newHeight)
            }
        }
    }
    
    /// Updates the dynamic height constraints based on available space
    private func updateDynamicConstraints(availableHeight: CGFloat) {
        self.availableHeight = availableHeight
        
        // Calculate the maximum height that still leaves space for resize handles to be accessible
        // We need to account for: resize handle + toolbar + safety margin
        let reservedSpace = resizeHandleHeight + toolbarHeight + safetyMargin
        let calculatedMaxHeight = max(minHeight, availableHeight - reservedSpace)
        
        // Use the smaller of our absolute max and the calculated max
        dynamicMaxHeight = min(maxHeight, calculatedMaxHeight)
        
        // If current timeline height exceeds the new dynamic max, adjust it
        if timelineHeight > dynamicMaxHeight {
            timelineHeight = dynamicMaxHeight
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
        let positionTrack = animationController.addTrack(id: "element1_position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 300)))
        
        return TimelineViewPanel(
            animationController: animationController,
            isPlaying: .constant(false),
            timelineHeight: .constant(300),
            timelineOffset: .constant(0.0),
            selectedElement: .constant(nil),
            timelineScale: .constant(1.0)
        )
        .frame(width: 800, height: 300)
        .padding()
    }
}
#endif 