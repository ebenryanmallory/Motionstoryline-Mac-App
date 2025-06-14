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
    internal var properties: [AnimatableProperty] {
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
                
                if selectedElement != nil {
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
                } else {
                    Spacer()
                    Text("No element selected")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .frame(minWidth: 200)
            
            // Keyframe Editor Area
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    if let element = selectedElement {
                        Text(element.displayName)
                            .font(.headline)
                    } else {
                        Text("No Element Selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
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
                        AnimationTimelineView(
                            animationController: animationController,
                            propertyId: property.id,
                            propertyType: property.type,
                            selectedKeyframeTime: $selectedKeyframeTime,
                            newKeyframeTime: $newKeyframeTime,
                            isAddingKeyframe: $isAddingKeyframe,
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
        .id(selectedElement?.id.uuidString ?? "no-element") // Force view refresh when selected element changes
        .onChange(of: selectedElement) { oldValue, newValue in
            if let newElement = newValue {
                // Element was selected or changed
                print("KeyframeEditorView: Element changed to \(newElement.displayName)")
                
                if oldValue?.id != newElement.id {
                    // Different element selected
                    print("KeyframeEditorView: New element selected, setting up tracks")
                    selectedProperty = nil
                    selectedKeyframeTime = nil
                    
                    // Setup keyframe tracks for the new element
                    setupTracksForSelectedElement(newElement)
                    
                    // Force refresh all properties with current element values
                    animationController.updateAnimatedProperties()
                    
                    // Select the first property by default
                    if let firstProperty = properties.first {
                        selectedProperty = firstProperty
                    }
                } 
                // Even if it's the same element, update tracks if properties changed
                else if let oldElement = oldValue {
                    if newElement.position != oldElement.position ||
                       newElement.size != oldElement.size ||
                       newElement.rotation != oldElement.rotation ||
                       newElement.color != oldElement.color ||
                       newElement.opacity != oldElement.opacity ||
                       false {
                        print("KeyframeEditorView: Element properties changed, updating tracks")
                        setupTracksForSelectedElement(newElement)
                    }
                }
            } else {
                // Element was deselected
                print("KeyframeEditorView: Element deselected")
                selectedProperty = nil
                selectedKeyframeTime = nil
            }
        }
        .onChange(of: selectedProperty) { oldValue, newValue in
            // Reset keyframe selection when property changes
            selectedKeyframeTime = nil
        }
        .onAppear {
            // Setup tracks for the initially selected element, if any
            if let element = selectedElement {
                print("KeyframeEditorView onAppear with element: \(element.displayName)")
                setupTracksForSelectedElement(element)
                
                // Force the animation controller to update with initial values
                animationController.seekToTime(0)
                animationController.updateAnimatedProperties()
            } else {
                print("KeyframeEditorView onAppear with no element selected")
            }
            
            // Setup keyboard shortcuts for timeline navigation
            setupKeyboardShortcuts()
        }
        .onDisappear {
            // Clean up keyboard shortcuts when view disappears
            keyEventController.teardownMonitor()
        }
        .sheet(isPresented: $isAddingKeyframe) {
            if let property = selectedProperty, let _ = selectedElement {
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
                self.newKeyframeTime = time
                self.isAddingKeyframe = true
            },
            onDeleteKeyframe: { time in
                guard let property = self.selectedProperty else { return }
                // Delete the selected keyframe
                self.animationController.removeKeyframe(trackId: property.id, time: time)
            }
        )
    }
    
    /// Setup keyframe tracks for the selected element
    internal func setupTracksForSelectedElement(_ element: CanvasElement) {
        let idPrefix = element.id.uuidString
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            let track = animationController.addTrack(id: positionTrackId) { (newPosition: CGPoint) in
                // Update the element's position when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.position = newPosition
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.position))
        } else if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> {
            // Ensure the initial keyframe exists and is correct
            if !track.allKeyframes.contains(where: { $0.time == 0.0 }) {
                track.add(keyframe: Keyframe(time: 0.0, value: element.position))
            }
        }
        
        // Size track (using width as the animatable property for simplicity)
        let sizeTrackId = "\(idPrefix)_size"
        if animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat> == nil {
            let track = animationController.addTrack(id: sizeTrackId) { (newSize: CGFloat) in
                // Update the element's size when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                // If aspect ratio is locked, maintain it
                if updatedElement.isAspectRatioLocked {
                    let ratio = updatedElement.size.height / updatedElement.size.width
                    updatedElement.size = CGSize(width: newSize, height: newSize * ratio)
                } else {
                    updatedElement.size.width = newSize
                }
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.size.width))
        } else if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGFloat> {
            // Ensure the initial keyframe exists and is correct
            if !track.allKeyframes.contains(where: { $0.time == 0.0 }) {
                track.add(keyframe: Keyframe(time: 0.0, value: element.size.width))
            }
        }
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        if animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: rotationTrackId) { (newRotation: Double) in
                // Update the element's rotation when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.rotation = newRotation
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
        } else if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> {
            // Ensure the initial keyframe exists and is correct
            if !track.allKeyframes.contains(where: { $0.time == 0.0 }) {
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
            }
        }
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        if animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            let track = animationController.addTrack(id: colorTrackId) { (newColor: Color) in
                // Update the element's color when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.color = newColor
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.color))
        } else if let track = animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> {
            // Ensure the initial keyframe exists and is correct
            if !track.allKeyframes.contains(where: { $0.time == 0.0 }) {
                track.add(keyframe: Keyframe(time: 0.0, value: element.color))
            }
        }
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        if animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            let track = animationController.addTrack(id: opacityTrackId) { (newOpacity: Double) in
                // Update the element's opacity when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.opacity = newOpacity
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0
            track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
        } else if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> {
            // Ensure the initial keyframe exists and is correct
            if !track.allKeyframes.contains(where: { $0.time == 0.0 }) {
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
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
