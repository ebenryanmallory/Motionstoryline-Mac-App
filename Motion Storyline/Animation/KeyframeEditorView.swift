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
    @State private var isEditingKeyframe = false
    @State private var editingKeyframeTime: Double?
    @State private var timelineScale: Double = 1.0
    @State private var timelineOffset: Double = 0.0
    
    // Add keyboard shortcut controller
    @StateObject private var keyEventController = KeyEventMonitorController()
    
    // Add a property refresh trigger to force UI updates
    @State private var propertyRefreshTrigger = UUID()
    
    // Dynamically generate properties based on the selected element
    internal var properties: [AnimatableProperty] {
        // Reference the refresh trigger to ensure this computed property re-evaluates
        _ = propertyRefreshTrigger
        
        guard let element = selectedElement else { return [] }
        
        // Create a unique ID prefix for this element's properties
        let idPrefix = element.id.uuidString
        
        var baseProperties = [
            AnimatableProperty(id: "\(idPrefix)_position", name: "Position", type: .position, icon: "arrow.up.and.down.and.arrow.left.and.right"),
            AnimatableProperty(id: "\(idPrefix)_size", name: "Size", type: .size, icon: "arrow.up.left.and.arrow.down.right"),
            AnimatableProperty(id: "\(idPrefix)_rotation", name: "Rotation", type: .rotation, icon: "arrow.clockwise"),
            AnimatableProperty(id: "\(idPrefix)_color", name: "Color", type: .color, icon: "paintpalette"),
            AnimatableProperty(id: "\(idPrefix)_opacity", name: "Opacity", type: .opacity, icon: "slider.horizontal.below.rectangle")
        ]
        
        // Add fontSize property for text elements
        if element.type == .text {
            baseProperties.append(AnimatableProperty(id: "\(idPrefix)_fontSize", name: "Font Size", type: .scale, icon: "textformat.size"))
        }
        
        return baseProperties
    }
    

    
    private var propertyListView: some View {
        VStack(spacing: 0) {
            if selectedElement != nil {
                let _ = print("KeyframeEditorView DEBUG: About to show List with \(properties.count) properties")
                List {
                    ForEach(properties) { property in
                        propertyRowView(property: property)
                    }
                }
                .id(propertyRefreshTrigger) // Force List to refresh when trigger changes
            } else {
                let _ = print("KeyframeEditorView DEBUG: No element selected, showing empty state")
                Spacer()
                Text("No element selected")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 150)
    }
    
    private func propertyRowView(property: AnimatableProperty) -> some View {
        let _ = print("KeyframeEditorView DEBUG: Rendering property \(property.name) with ID \(property.id)")
        let keyframeCount = getKeyframeCount(for: property.id)
        let _ = print("KeyframeEditorView DEBUG: Property \(property.name) has \(keyframeCount ?? -1) keyframes")
        
        return HStack {
            Image(systemName: property.icon)
                .frame(width: 16)
                .foregroundColor(.secondary)
            
            Text(property.name)
                .font(.caption)
            
            Spacer()
            
            // Show active keyframe count
            if let count = keyframeCount {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(selectedProperty?.id == property.id ? Color.gray.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            print("KeyframeEditorView DEBUG: Property \(property.name) tapped")
            selectedProperty = property
        }
    }
    
    private var keyframeEditorView: some View {
        VStack(spacing: 0) {
            toolbarView
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
                        },
                        onEditKeyframe: { time in
                            editingKeyframeTime = time
                            newKeyframeTime = time
                            isEditingKeyframe = true
                        }
                    )
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                    .padding(8)
                    
                    Divider()
                    
                    // Property inspector (using the new component)
                    PropertyInspectorView(
                        animationController: animationController,
                        property: property,
                        selectedKeyframeTime: $selectedKeyframeTime
                    )
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
                    .padding(8)
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
    
    private var toolbarView: some View {
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }

    var body: some View {
        // Debug logging to track state
        let _ = print("KeyframeEditorView DEBUG: selectedElement = \(selectedElement?.displayName ?? "nil")")
        let _ = print("KeyframeEditorView DEBUG: selectedElement ID = \(selectedElement?.id.uuidString ?? "nil")")
        let _ = print("KeyframeEditorView DEBUG: properties count = \(properties.count)")
        let _ = print("KeyframeEditorView DEBUG: selectedProperty = \(selectedProperty?.name ?? "nil")")
        let _ = print("KeyframeEditorView DEBUG: animation controller tracks = \(animationController.getAllTracks())")
        let _ = print("KeyframeEditorView DEBUG: propertyRefreshTrigger = \(propertyRefreshTrigger)")
        
        return HSplitView {
            propertyListView
            keyframeEditorView
        }
        .id(selectedElement?.id.uuidString ?? "no-element") // Force view refresh when selected element changes
        .onChange(of: selectedElement) { oldValue, newValue in
            handleSelectedElementChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: selectedProperty) { oldValue, newValue in
            // Reset keyframe selection when property changes
            print("KeyframeEditorView DEBUG: selectedProperty changed from \(oldValue?.name ?? "nil") to \(newValue?.name ?? "nil")")
            selectedKeyframeTime = nil
        }
        .onAppear {
            handleOnAppear()
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
        .sheet(isPresented: $isEditingKeyframe) {
            if let property = selectedProperty, let _ = selectedElement, let editTime = editingKeyframeTime {
                AddKeyframeSheet(
                    animationController: animationController,
                    property: property,
                    isPresented: $isEditingKeyframe,
                    newKeyframeTime: $newKeyframeTime,
                    selectedElement: $selectedElement,
                    onAddKeyframe: { time in
                        selectedKeyframeTime = time
                    },
                    isEditingMode: true,
                    originalKeyframeTime: editTime
                )
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // Extract the complex onChange logic into a separate method
    private func handleSelectedElementChange(oldValue: CanvasElement?, newValue: CanvasElement?) {
        print("KeyframeEditorView DEBUG: selectedElement onChange triggered")
        print("KeyframeEditorView DEBUG: oldValue = \(oldValue?.displayName ?? "nil") (ID: \(oldValue?.id.uuidString ?? "nil"))")
        print("KeyframeEditorView DEBUG: newValue = \(newValue?.displayName ?? "nil") (ID: \(newValue?.id.uuidString ?? "nil"))")
        
        // CRITICAL FIX: Clear selectedProperty immediately to prevent stale UI state
        selectedProperty = nil
        selectedKeyframeTime = nil
        
        // Force properties array to refresh by changing the trigger
        propertyRefreshTrigger = UUID()
        
        if let newElement = newValue {
            // Element was selected or changed
            print("KeyframeEditorView: Element changed to \(newElement.displayName)")
            
            if oldValue?.id != newElement.id {
                // Different element selected
                print("KeyframeEditorView: New element selected, setting up tracks")
                
                // Setup keyframe tracks for the new element
                setupTracksForSelectedElement(newElement)
                
                // Force refresh all properties with current element values
                animationController.updateAnimatedProperties()
                
                // Use DispatchQueue to ensure the properties array has been refreshed before selecting
                DispatchQueue.main.async {
                    // Select the first property by default after properties are refreshed
                    if let firstProperty = self.properties.first {
                        print("KeyframeEditorView DEBUG: Auto-selecting first property: \(firstProperty.name)")
                        self.selectedProperty = firstProperty
                    } else {
                        print("KeyframeEditorView DEBUG: No properties available to auto-select")
                    }
                }
            } 
            // Even if it's the same element, update tracks if properties changed
            else if let oldElement = oldValue {
                if newElement.position != oldElement.position ||
                   newElement.size != oldElement.size ||
                   newElement.rotation != oldElement.rotation ||
                   newElement.color != oldElement.color ||
                   newElement.opacity != oldElement.opacity ||
                   newElement.fontSize != oldElement.fontSize {
                    print("KeyframeEditorView: Element properties changed, updating tracks")
                    setupTracksForSelectedElement(newElement)
                } else {
                    print("KeyframeEditorView DEBUG: Same element, no property changes detected")
                }
            }
        } else {
            // Element was deselected - clear UI state but keep tracks for potential re-selection
            print("KeyframeEditorView: Element deselected")
            // selectedProperty and selectedKeyframeTime already cleared above
        }
    }
    
    private func handleOnAppear() {
        print("KeyframeEditorView DEBUG: onAppear called")
        // Setup tracks for the initially selected element, if any
        if let element = selectedElement {
            print("KeyframeEditorView onAppear with element: \(element.displayName)")
            setupTracksForSelectedElement(element)
            
            // Force the animation controller to update with initial values
            animationController.seekToTime(0)
            animationController.updateAnimatedProperties()
            
            // Force properties to refresh on initial appear
            propertyRefreshTrigger = UUID()
            
            // Use DispatchQueue to ensure the properties array has been refreshed before selecting
            DispatchQueue.main.async {
                // Select the first property by default if none is selected
                if self.selectedProperty == nil, let firstProperty = self.properties.first {
                    print("KeyframeEditorView DEBUG: onAppear - Auto-selecting first property: \(firstProperty.name)")
                    self.selectedProperty = firstProperty
                }
            }
        } else {
            print("KeyframeEditorView onAppear with no element selected")
        }
        
        // Setup keyboard shortcuts for timeline navigation
        setupKeyboardShortcuts()
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
        print("KeyframeEditorView DEBUG: Setting up tracks for element '\(element.displayName)' with ID prefix '\(idPrefix)'")
        
        // Position track
        let positionTrackId = "\(idPrefix)_position"
        print("KeyframeEditorView DEBUG: Looking for position track with ID: '\(positionTrackId)'")
        if animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> == nil {
            print("KeyframeEditorView DEBUG: Creating new position track")
            let track = animationController.addTrack(id: positionTrackId) { (newPosition: CGPoint) in
                // Update the element's position when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.position = newPosition
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0 with current element position
            let success = track.add(keyframe: Keyframe(time: 0.0, value: element.position))
            print("KeyframeEditorView DEBUG: Added initial position keyframe: \(success), value: \(element.position)")
        } else if let track = animationController.getTrack(id: positionTrackId) as? KeyframeTrack<CGPoint> {
            print("KeyframeEditorView DEBUG: Position track already exists with \(track.allKeyframes.count) keyframes")
            // Update the initial keyframe with current element position if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                print("KeyframeEditorView DEBUG: Updating existing position keyframe at time 0")
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.position, easingFunction: existingKeyframe.easingFunction))
            } else {
                print("KeyframeEditorView DEBUG: Adding new position keyframe at time 0")
                track.add(keyframe: Keyframe(time: 0.0, value: element.position))
            }
        }
        
        // Size track (using CGSize to match the rest of the system)
        let sizeTrackId = "\(idPrefix)_size"
        print("KeyframeEditorView DEBUG: Looking for size track with ID: '\(sizeTrackId)'")
        if animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> == nil {
            print("KeyframeEditorView DEBUG: Creating new size track")
            let track = animationController.addTrack(id: sizeTrackId) { (newSize: CGSize) in
                // Update the element's size when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                // If aspect ratio is locked, maintain it
                if updatedElement.isAspectRatioLocked {
                    let ratio = updatedElement.size.height / updatedElement.size.width
                    updatedElement.size = CGSize(width: newSize.width, height: newSize.width * ratio)
                } else {
                    updatedElement.size = newSize
                }
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0 with current element size
            let success = track.add(keyframe: Keyframe(time: 0.0, value: element.size))
            print("KeyframeEditorView DEBUG: Added initial size keyframe: \(success), value: \(element.size)")
        } else if let track = animationController.getTrack(id: sizeTrackId) as? KeyframeTrack<CGSize> {
            print("KeyframeEditorView DEBUG: Size track already exists with \(track.allKeyframes.count) keyframes")
            // Update the initial keyframe with current element size if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                print("KeyframeEditorView DEBUG: Updating existing size keyframe at time 0")
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.size, easingFunction: existingKeyframe.easingFunction))
            } else {
                print("KeyframeEditorView DEBUG: Adding new size keyframe at time 0")
                track.add(keyframe: Keyframe(time: 0.0, value: element.size))
            }
        }
        
        // Rotation track
        let rotationTrackId = "\(idPrefix)_rotation"
        print("KeyframeEditorView DEBUG: Looking for rotation track with ID: '\(rotationTrackId)'")
        if animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> == nil {
            print("KeyframeEditorView DEBUG: Creating new rotation track")
            let track = animationController.addTrack(id: rotationTrackId) { (newRotation: Double) in
                // Update the element's rotation when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.rotation = newRotation
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0 with current element rotation
            let success = track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
            print("KeyframeEditorView DEBUG: Added initial rotation keyframe: \(success), value: \(element.rotation)")
        } else if let track = animationController.getTrack(id: rotationTrackId) as? KeyframeTrack<Double> {
            print("KeyframeEditorView DEBUG: Rotation track already exists with \(track.allKeyframes.count) keyframes")
            // Update the initial keyframe with current element rotation if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                print("KeyframeEditorView DEBUG: Updating existing rotation keyframe at time 0")
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation, easingFunction: existingKeyframe.easingFunction))
            } else {
                print("KeyframeEditorView DEBUG: Adding new rotation keyframe at time 0")
                track.add(keyframe: Keyframe(time: 0.0, value: element.rotation))
            }
        }
        
        // Color track
        let colorTrackId = "\(idPrefix)_color"
        print("KeyframeEditorView DEBUG: Looking for color track with ID: '\(colorTrackId)'")
        if animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> == nil {
            print("KeyframeEditorView DEBUG: Creating new color track")
            let track = animationController.addTrack(id: colorTrackId) { (newColor: Color) in
                // Update the element's color when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.color = newColor
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0 with current element color
            let success = track.add(keyframe: Keyframe(time: 0.0, value: element.color))
            print("KeyframeEditorView DEBUG: Added initial color keyframe: \(success), value: \(element.color)")
        } else if let track = animationController.getTrack(id: colorTrackId) as? KeyframeTrack<Color> {
            print("KeyframeEditorView DEBUG: Color track already exists with \(track.allKeyframes.count) keyframes")
            // Update the initial keyframe with current element color if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                print("KeyframeEditorView DEBUG: Updating existing color keyframe at time 0")
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.color, easingFunction: existingKeyframe.easingFunction))
            } else {
                print("KeyframeEditorView DEBUG: Adding new color keyframe at time 0")
                track.add(keyframe: Keyframe(time: 0.0, value: element.color))
            }
        }
        
        // Opacity track
        let opacityTrackId = "\(idPrefix)_opacity"
        print("KeyframeEditorView DEBUG: Looking for opacity track with ID: '\(opacityTrackId)'")
        if animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> == nil {
            print("KeyframeEditorView DEBUG: Creating new opacity track")
            let track = animationController.addTrack(id: opacityTrackId) { (newOpacity: Double) in
                // Update the element's opacity when the animation plays
                guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                updatedElement.opacity = newOpacity
                self.selectedElement = updatedElement
            }
            // Add initial keyframe at time 0 with current element opacity
            let success = track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
            print("KeyframeEditorView DEBUG: Added initial opacity keyframe: \(success), value: \(element.opacity)")
        } else if let track = animationController.getTrack(id: opacityTrackId) as? KeyframeTrack<Double> {
            print("KeyframeEditorView DEBUG: Opacity track already exists with \(track.allKeyframes.count) keyframes")
            // Update the initial keyframe with current element opacity if it exists
            if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                print("KeyframeEditorView DEBUG: Updating existing opacity keyframe at time 0")
                track.removeKeyframe(at: 0.0)
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity, easingFunction: existingKeyframe.easingFunction))
            } else {
                print("KeyframeEditorView DEBUG: Adding new opacity keyframe at time 0")
                track.add(keyframe: Keyframe(time: 0.0, value: element.opacity))
            }
        }
        
        // Font size track (only for text elements)
        if element.type == .text {
            let fontSizeTrackId = "\(idPrefix)_fontSize"
            if animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> == nil {
                let track = animationController.addTrack(id: fontSizeTrackId) { (newFontSize: CGFloat) in
                    // Update the element's font size when the animation plays
                    guard var updatedElement = self.selectedElement, updatedElement.id == element.id else { return }
                    updatedElement.fontSize = max(8, min(200, newFontSize)) // Constrain between 8pt and 200pt
                    self.selectedElement = updatedElement
                }
                // Add initial keyframe at time 0 with current element font size
                let success = track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
                print("KeyframeEditorView DEBUG: Added initial font size keyframe: \(success), value: \(element.fontSize)")
            } else if let track = animationController.getTrack(id: fontSizeTrackId) as? KeyframeTrack<CGFloat> {
                // Update the initial keyframe with current element font size if it exists
                if let existingKeyframe = track.allKeyframes.first(where: { $0.time == 0.0 }) {
                    print("KeyframeEditorView DEBUG: Updating existing font size keyframe at time 0")
                    track.removeKeyframe(at: 0.0)
                    track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize, easingFunction: existingKeyframe.easingFunction))
                } else {
                    print("KeyframeEditorView DEBUG: Adding new font size keyframe at time 0")
                    track.add(keyframe: Keyframe(time: 0.0, value: element.fontSize))
                }
            }
        }
    }
    
    /// Get the number of keyframes for a property (only for current element)
    private func getKeyframeCount(for propertyId: String) -> Int? {
        // Ensure the property ID belongs to the currently selected element
        guard let element = selectedElement,
              propertyId.hasPrefix(element.id.uuidString) else {
            print("KeyframeEditorView DEBUG: Property ID '\(propertyId)' does not belong to current element")
            return nil
        }
        
        print("KeyframeEditorView DEBUG: getKeyframeCount called for propertyId: '\(propertyId)'")
        
        if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGPoint> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found CGPoint track with \(count) keyframes")
            return count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGFloat> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found CGFloat track with \(count) keyframes")
            return count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<CGSize> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found CGSize track with \(count) keyframes")
            return count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Double> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found Double track with \(count) keyframes")
            return count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<Color> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found Color track with \(count) keyframes")
            return count
        } else if let track = animationController.getTrack(id: propertyId) as? KeyframeTrack<[CGPoint]> {
            let count = track.allKeyframes.count
            print("KeyframeEditorView DEBUG: Found [CGPoint] track with \(count) keyframes")
            return count
        } else {
            print("KeyframeEditorView DEBUG: No track found for propertyId: '\(propertyId)'")
            return nil
        }
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
