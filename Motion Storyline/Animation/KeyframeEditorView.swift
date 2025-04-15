import SwiftUI
import AppKit

/// A view for editing keyframes for all animated properties
struct KeyframeEditorView: View {
    @ObservedObject var animationController: AnimationController
    @Binding var selectedElement: CanvasElement?
    @State private var selectedProperty: AnimatableProperty?
    @State private var selectedKeyframeTime: Double?
    @State private var isAddingKeyframe = false
    @State private var newKeyframeTime: Double = 0
    @State private var timelineScale: Double = 1.0
    @State private var timelineOffset: Double = 0.0
    
    // Add keyboard shortcut controller
    @StateObject private var keyEventController = KeyEventMonitorController()
    
    // Dynamically generate properties based on the selected element
    private var properties: [AnimatableProperty] {
        guard let element = selectedElement else { return [] }
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        return [
            AnimatableProperty(id: "\(idPrefix)_position", name: "Position", type: .position, icon: "arrow.up.and.down.and.arrow.left.and.right"),
            AnimatableProperty(id: "\(idPrefix)_size", name: "Size", type: .size, icon: "arrow.up.left.and.arrow.down.right"),
            AnimatableProperty(id: "\(idPrefix)_rotation", name: "Rotation", type: .rotation, icon: "arrow.clockwise"),
            AnimatableProperty(id: "\(idPrefix)_color", name: "Color", type: .color, icon: "paintpalette"),
            AnimatableProperty(id: "\(idPrefix)_opacity", name: "Opacity", type: .opacity, icon: "slider.horizontal.below.rectangle")
        ]
    }
    
    var body: some View {
        HSplitView {
            // Property List
            VStack(spacing: 0) {
                Text("Properties")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                List {
                    ForEach(properties) { property in
                        HStack {
                            Image(systemName: property.icon)
                                .frame(width: 24)
                            
                            Text(property.name)
                            
                            Spacer()
                            
                            // Show active keyframe count
                            if let count = getKeyframeCount(for: property.id) {
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .background(selectedProperty?.id == property.id ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
                        .onTapGesture {
                            selectedProperty = property
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200)
            
            // Keyframe Editor Area
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(selectedElement?.displayName ?? "No Element Selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        isAddingKeyframe = true
                        newKeyframeTime = animationController.currentTime
                    }) {
                        Label("Add Keyframe", systemImage: "plus")
                    }
                    .disabled(selectedProperty == nil || selectedElement == nil)
                    .help("Add Keyframe at Current Time")
                    
                    Button(action: {
                        if let property = selectedProperty, let time = selectedKeyframeTime {
                            animationController.removeKeyframe(trackId: property.id, time: time)
                            selectedKeyframeTime = nil
                        }
                    }) {
                        Label("Delete Keyframe", systemImage: "minus")
                    }
                    .disabled(selectedKeyframeTime == nil)
                    .help("Delete Selected Keyframe")
                    
                    Divider()
                        .frame(height: 16)
                        .padding(.horizontal)
                    
                    // Zoom controls
                    Button(action: {
                        timelineScale = max(0.5, timelineScale - 0.25)
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom Out")
                    
                    Button(action: {
                        timelineScale = min(4, timelineScale + 0.25)
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom In")
                    
                    Button(action: {
                        timelineScale = 1.0
                        timelineOffset = 0.0
                    }) {
                        Image(systemName: "1.magnifyingglass")
                    }
                    .help("Reset Zoom")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Timeline and Properties Area
                if let property = selectedProperty {
                    VStack(spacing: 0) {
                        // Timeline view (using the new component)
                        TimelineView(
                            animationController: animationController,
                            propertyId: property.id,
                            propertyType: property.type,
                            selectedKeyframeTime: $selectedKeyframeTime,
                            newKeyframeTime: $newKeyframeTime,
                            isAddingKeyframe: $isAddingKeyframe,
                            timelineScale: timelineScale,
                            timelineOffset: $timelineOffset,
                            onAddKeyframe: { time in
                                newKeyframeTime = time
                                isAddingKeyframe = true
                            }
                        )
                        .frame(height: 120)
                        .padding()
                        
                        Divider()
                        
                        // Property inspector (using the new component)
                        PropertyInspectorView(
                            animationController: animationController,
                            property: property,
                            selectedKeyframeTime: $selectedKeyframeTime
                        )
                        .padding()
                        .frame(height: 200)
                        .id(property.id) // Force view refresh when property changes
                    }
                } else {
                    // Empty state
                    VStack {
                        Spacer()
                        if selectedElement == nil {
                            Text("Select an element on the canvas")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Select a property to edit keyframes")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .onChange(of: selectedElement) { [selectedElement] newValue in
            // When the selected element changes
            if newValue?.id != selectedElement?.id {
                // Reset selected property when element changes
                selectedProperty = nil
                selectedKeyframeTime = nil
                
                // Setup keyframe tracks for the new element
                if let element = newValue {
                    setupTracksForSelectedElement(element)
                }
            }
        }
        .onChange(of: selectedProperty) { newValue in
            // Reset keyframe selection when property changes
            selectedKeyframeTime = nil
        }
        .onAppear {
            // Setup tracks for the initially selected element, if any
            if let element = selectedElement {
                setupTracksForSelectedElement(element)
            }
            
            // Setup keyboard shortcuts for timeline navigation
            setupKeyboardShortcuts()
        }
        .onDisappear {
            // Clean up keyboard shortcuts when view disappears
            keyEventController.teardownMonitor()
        }
        .sheet(isPresented: $isAddingKeyframe) {
            if let property = selectedProperty {
                AddKeyframeSheet(
                    animationController: animationController,
                    property: property,
                    isPresented: $isAddingKeyframe,
                    newKeyframeTime: $newKeyframeTime,
                    selectedElement: $selectedElement,
                    onAddKeyframe: { time in
                        selectedKeyframeTime = time
                    }
                )
            }
        }
    }
    
    /// Setup keyboard shortcuts for timeline navigation
    private func setupKeyboardShortcuts() {
        keyEventController.setupTimelineKeyboardShortcuts(
            animationController: animationController,
            selectedElement: selectedElement,
            selectedKeyframeTime: $selectedKeyframeTime,
            onAddKeyframe: { time in
                // Add keyframe at the current time
                newKeyframeTime = time
                isAddingKeyframe = true
            },
            onDeleteKeyframe: { time in
                // Delete the selected keyframe
                if let property = selectedProperty {
                    animationController.removeKeyframe(trackId: property.id, time: time)
                }
            }
        )
    }
    
    /// Setup keyframe tracks for the selected element
    private func setupTracksForSelectedElement(_ element: CanvasElement) {
        let idPrefix = element.id.uuidString
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = animationController.addTrack(id: positionTrackId) { (newPosition: CGPoint) in
                // Update the element's position when the animation plays
                if var updatedElement = selectedElement, updatedElement.id == element.id {
                    updatedElement.position = newPosition
                    selectedElement = updatedElement
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
                if var updatedElement = selectedElement, updatedElement.id == element.id {
                    // If aspect ratio is locked, maintain it
                    if updatedElement.isAspectRatioLocked {
                        let ratio = updatedElement.size.height / updatedElement.size.width
                        updatedElement.size = CGSize(width: newSize, height: newSize * ratio)
                    } else {
                        updatedElement.size.width = newSize
                    }
                    selectedElement = updatedElement
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
                if var updatedElement = selectedElement, updatedElement.id == element.id {
                    updatedElement.rotation = newRotation
                    selectedElement = updatedElement
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
                if var updatedElement = selectedElement, updatedElement.id == element.id {
                    updatedElement.color = newColor
                    selectedElement = updatedElement
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
                if var updatedElement = selectedElement, updatedElement.id == element.id {
                    updatedElement.opacity = newOpacity
                    selectedElement = updatedElement
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
                    if var updatedElement = selectedElement, updatedElement.id == element.id {
                        updatedElement.path = newPath
                        selectedElement = updatedElement
                    }
                }
                // Add initial keyframe at time 0
                track.add(keyframe: Keyframe(time: 0.0, value: element.path))
            }
        }
    }
    
    /// Get the number of keyframes for a property
    private func getKeyframeCount(for propertyId: String) -> Int? {
        if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGPoint> {
            return track.allKeyframes.count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGFloat> {
            return track.allKeyframes.count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
            return track.allKeyframes.count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Color> {
            return track.allKeyframes.count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<[CGPoint]> {
            return track.allKeyframes.count
        }
        return nil
    }
}

// MARK: - SwiftUI Preview

#if !DISABLE_PREVIEWS
struct KeyframeEditorView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample animation controller for the preview
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        // Add some sample keyframes
        let positionTrack = animationController.addTrack(id: "position") { (newPosition: CGPoint) in }
        positionTrack.add(keyframe: Keyframe(time: 0.0, value: CGPoint(x: 100, y: 100)))
        positionTrack.add(keyframe: Keyframe(time: 2.5, value: CGPoint(x: 300, y: 200)))
        positionTrack.add(keyframe: Keyframe(time: 5.0, value: CGPoint(x: 100, y: 300)))
        
        let sizeTrack = animationController.addTrack(id: "size") { (newSize: CGFloat) in }
        sizeTrack.add(keyframe: Keyframe(time: 0.0, value: 50.0))
        sizeTrack.add(keyframe: Keyframe(time: 2.5, value: 100.0))
        sizeTrack.add(keyframe: Keyframe(time: 5.0, value: 30.0))
        
        // Create a sample element for the preview
        let sampleElement = CanvasElement.rectangle(at: CGPoint(x: 200, y: 200))
        
        return KeyframeEditorView(
            animationController: animationController,
            selectedElement: .constant(sampleElement)
        )
        .frame(width: 900, height: 600)
    }
}
#endif
