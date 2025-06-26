import SwiftUI

/// A sheet view for adding new keyframes or editing existing ones
struct AddKeyframeSheet: View {
    @ObservedObject var animationController: AnimationController
    let property: AnimatableProperty
    @Binding var isPresented: Bool
    @Binding var newKeyframeTime: Double
    @Binding var selectedElement: CanvasElement?
    var onAddKeyframe: (Double) -> Void
    
    // MARK: - New properties for editing mode
    /// If true, we're editing an existing keyframe rather than adding a new one
    var isEditingMode: Bool = false
    /// The original time of the keyframe being edited (needed to remove old keyframe)
    var originalKeyframeTime: Double?
    
    @State private var newPositionValue = CGPoint(x: 0, y: 0)
    @State private var newSizeValue: CGFloat = 50
    @State private var newRotationValue: Double = 0
    @State private var newColorValue = Color.blue
    @State private var newOpacityValue: Double = 1.0
    @State private var newFontSizeValue: CGFloat = 16.0
    @State private var newScaleValue: CGFloat = 1.0
    @State private var selectedEasing: EasingFunction = .linear
    @State private var showCurveEditor: Bool = false
    @State private var customBezierValues = BezierControlPoints(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0)
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text(isEditingMode ? "Edit Keyframe" : "Add Keyframe")
                .font(.headline)
                .padding(.top)
            
            // Time selector
            VStack(alignment: .leading) {
                Text("Time (seconds)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("Time", value: $newKeyframeTime, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Slider(value: $newKeyframeTime, in: 0...animationController.duration)
                        .frame(width: 200)
                }
            }
            .padding(.horizontal)
            
            // Value selector based on property type
            switch property.type {
            case .position:
                VStack(alignment: .leading) {
                    Text("Position")
                        .font(.headline)
                    
                    HStack(alignment: .top) {
                        // X position
                        VStack(alignment: .leading) {
                            Text("X")
                                .foregroundColor(.secondary)
                            
                            TextField("X", value: $newPositionValue.x, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        // Y position
                        VStack(alignment: .leading) {
                            Text("Y")
                                .foregroundColor(.secondary)
                            
                            TextField("Y", value: $newPositionValue.y, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.horizontal)
                
            case .size:
                VStack(alignment: .leading) {
                    Text("Size")
                        .font(.headline)
                    
                    HStack {
                        TextField("Size", value: $newSizeValue, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Slider(value: $newSizeValue, in: 0...200)
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal)
                
            case .rotation:
                VStack(alignment: .leading) {
                    Text("Rotation")
                        .font(.headline)
                    
                    HStack {
                        TextField("Degrees", value: $newRotationValue, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Slider(value: $newRotationValue, in: 0...360)
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal)
                
            case .color:
                VStack(alignment: .leading) {
                    Text("Color")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    ColorPicker("Select Color", selection: $newColorValue)
                }
                .padding(.horizontal)
                
            case .opacity:
                VStack(alignment: .leading) {
                    Text("Opacity")
                        .font(.headline)
                    
                    HStack {
                        TextField("Opacity", value: $newOpacityValue, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Slider(value: $newOpacityValue, in: 0...1, step: 0.01)
                            .frame(width: 200)
                    }
                }
                .padding(.horizontal)
                
            case .scale:
                // Handle both scale and fontSize using the same property type
                if property.name == "Font Size" {
                    VStack(alignment: .leading) {
                        Text("Font Size")
                            .font(.headline)
                        
                        HStack {
                            TextField("Font Size", value: $newFontSizeValue, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            
                            Text("pt")
                                .foregroundColor(.secondary)
                            
                            Slider(value: $newFontSizeValue, in: 8...200)
                                .frame(width: 200)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading) {
                        Text("Scale")
                            .font(.headline)
                        
                        HStack {
                            TextField("Scale", value: $newScaleValue, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            
                            Slider(value: $newScaleValue, in: 0.1...5.0)
                                .frame(width: 200)
                        }
                    }
                    .padding(.horizontal)
                }
                
            default:
                Text("Unsupported property type")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            // Easing function selector
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Easing")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(action: {
                        showCurveEditor = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path")
                            Text("Curve Editor")
                        }
                    }
                    .buttonStyle(.bordered)
                    .help("Open advanced curve editor for custom easing")
                }
                
                // Display selected easing type
                HStack {
                    Text("Selected:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(easingFunctionDisplayName(selectedEasing))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding(.bottom, 4)
                
                Picker("", selection: $selectedEasing) {
                    Text("Linear").tag(EasingFunction.linear)
                    Text("Ease In").tag(EasingFunction.easeIn)
                    Text("Ease Out").tag(EasingFunction.easeOut)
                    Text("Ease In Out").tag(EasingFunction.easeInOut)
                    if case .customCubicBezier = selectedEasing {
                        Text("Custom Curve").tag(selectedEasing)
                    }
                }
                .pickerStyle(.segmented)
                
                // Show custom bezier info if it's selected
                if case .customCubicBezier(let x1, let y1, let x2, let y2) = selectedEasing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bezier Values:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("cubic-bezier(\(String(format: "%.2f", x1)), \(String(format: "%.2f", y1)), \(String(format: "%.2f", x2)), \(String(format: "%.2f", y2)))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button(isEditingMode ? "Update Keyframe" : "Add Keyframe") {
                    if isEditingMode {
                        updateExistingKeyframe()
                    } else {
                        addNewKeyframe()
                    }
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 10)
        .onAppear {
            initializeValues()
        }
        .sheet(isPresented: $showCurveEditor) {
            CurveEditorSheet(
                property: property,
                animationController: animationController,
                selectedKeyframeTime: newKeyframeTime,
                isPresented: $showCurveEditor,
                onCurveUpdate: { newBezier in
                    // Update the easing function with the custom bezier
                    let newEasing = EasingFunction.customCubicBezier(x1: newBezier.x1, y1: newBezier.y1, x2: newBezier.x2, y2: newBezier.y2)
                    selectedEasing = newEasing
                    customBezierValues = BezierControlPoints(from: newBezier)
                }
            )
        }
    }
    
    /// Initialize the values based on the existing keyframes
    private func initializeValues() {
        // Get initial value from the selected element if available
        guard let element = selectedElement else { return }
        
        // If we're editing an existing keyframe, load its values
        if isEditingMode, let originalTime = originalKeyframeTime {
            loadExistingKeyframeValues(at: originalTime)
            return
        }
        
        switch property.type {
        case .position:
            // Try to get value from existing track or use element's current position
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>? {
                newPositionValue = track.getValue(at: animationController.currentTime) ?? element.position
            } else {
                newPositionValue = element.position
            }
            
        case .size:
            // Try to get value from existing track or use element's current width
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                newSizeValue = track.getValue(at: animationController.currentTime) ?? element.size.width
            } else {
                newSizeValue = element.size.width
            }
            
        case .rotation:
            // Try to get value from existing track or use element's current rotation
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? {
                newRotationValue = track.getValue(at: animationController.currentTime) ?? element.rotation
            } else {
                newRotationValue = element.rotation
            }
            
        case .color:
            // Try to get value from existing track or use element's current color
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Color>? {
                newColorValue = track.getValue(at: animationController.currentTime) ?? element.color
            } else {
                newColorValue = element.color
            }
            
        case .opacity:
            // Try to get value from existing track or use element's current opacity
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? {
                newOpacityValue = track.getValue(at: animationController.currentTime) ?? element.opacity
            } else {
                newOpacityValue = element.opacity
            }
            
        case .scale:
            // Handle both scale and fontSize
            if property.name == "Font Size" {
                // Try to get value from existing track or use element's current font size
                if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                    newFontSizeValue = track.getValue(at: animationController.currentTime) ?? element.fontSize
                } else {
                    newFontSizeValue = element.fontSize
                }
            } else {
                // Try to get value from existing track or use element's current scale
                if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                    newScaleValue = track.getValue(at: animationController.currentTime) ?? element.scale
                } else {
                    newScaleValue = element.scale
                }
            }
            
        default:
            break
        }
    }
    
    /// Add a new keyframe based on the current property and values
    private func addNewKeyframe() {
        switch property.type {
        case .position:
            // Get or create the track
            let track: KeyframeTrack<CGPoint>
            if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>? {
                track = existingTrack
            } else {
                track = animationController.addTrack(id: property.id) { (newPos: CGPoint) in
                    // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                }
            }
            
            // Add the keyframe
            let keyframe = Keyframe(time: newKeyframeTime, value: newPositionValue, easingFunction: selectedEasing)
            track.add(keyframe: keyframe)
            
        case .size:
            // Get or create the track
            let track: KeyframeTrack<CGFloat>
            if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                track = existingTrack
            } else {
                track = animationController.addTrack(id: property.id) { (newSize: CGFloat) in
                    // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                }
            }
            
            // Add the keyframe
            let keyframe = Keyframe(time: newKeyframeTime, value: newSizeValue, easingFunction: selectedEasing)
            track.add(keyframe: keyframe)
            
        case .rotation:
            // Get or create the track
            let track: KeyframeTrack<Double>
            if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? {
                track = existingTrack
            } else {
                track = animationController.addTrack(id: property.id) { (newRotation: Double) in
                    // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                }
            }
            
            // Add the keyframe
            let keyframe = Keyframe(time: newKeyframeTime, value: newRotationValue, easingFunction: selectedEasing)
            track.add(keyframe: keyframe)
            
        case .color:
            // Get or create the track
            let track: KeyframeTrack<Color>
            if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<Color>? {
                track = existingTrack
            } else {
                track = animationController.addTrack(id: property.id) { (newColor: Color) in
                    // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                }
            }
            
            // Add the keyframe
            let keyframe = Keyframe(time: newKeyframeTime, value: newColorValue, easingFunction: selectedEasing)
            track.add(keyframe: keyframe)
            
        case .opacity:
            // Get or create the track
            let track: KeyframeTrack<Double>
            if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? {
                track = existingTrack
            } else {
                track = animationController.addTrack(id: property.id) { (newOpacity: Double) in
                    // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                }
            }
            
            // Add the keyframe
            let keyframe = Keyframe(time: newKeyframeTime, value: newOpacityValue, easingFunction: selectedEasing)
            track.add(keyframe: keyframe)
            
        case .scale:
            // Handle both scale and fontSize
            if property.name == "Font Size" {
                // Get or create the track
                let track: KeyframeTrack<CGFloat>
                if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                    track = existingTrack
                } else {
                    track = animationController.addTrack(id: property.id) { (newFontSize: CGFloat) in
                        // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                    }
                }
                
                // Add the keyframe with constrained font size
                let constrainedFontSize = max(8, min(200, newFontSizeValue))
                let keyframe = Keyframe(time: newKeyframeTime, value: constrainedFontSize, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            } else {
                // Get or create the track
                let track: KeyframeTrack<CGFloat>
                if let existingTrack = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? {
                    track = existingTrack
                } else {
                    track = animationController.addTrack(id: property.id) { (newScale: CGFloat) in
                        // This will be handled by the setupTracksForSelectedElement function in KeyframeEditorView
                    }
                }
                
                // Add the keyframe with constrained scale
                let constrainedScale = max(0.1, min(5.0, newScaleValue))
                let keyframe = Keyframe(time: newKeyframeTime, value: constrainedScale, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        default:
            break
        }
    }
    
    /// Load values from an existing keyframe for editing
    private func loadExistingKeyframeValues(at time: Double) {
        switch property.type {
        case .position:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGPoint>,
               let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                newPositionValue = keyframe.value
                selectedEasing = keyframe.easingFunction
            }
            
        case .size:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat>,
               let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                newSizeValue = keyframe.value
                selectedEasing = keyframe.easingFunction
            }
            
        case .rotation:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Double>,
               let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                newRotationValue = keyframe.value
                selectedEasing = keyframe.easingFunction
            }
            
        case .color:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Color>,
               let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                newColorValue = keyframe.value
                selectedEasing = keyframe.easingFunction
            }
            
        case .opacity:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Double>,
               let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                newOpacityValue = keyframe.value
                selectedEasing = keyframe.easingFunction
            }
            
        case .scale:
            if property.name == "Font Size" {
                if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat>,
                   let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                    newFontSizeValue = keyframe.value
                    selectedEasing = keyframe.easingFunction
                }
            } else {
                if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat>,
                   let keyframe = track.allKeyframes.first(where: { $0.time == time }) {
                    newScaleValue = keyframe.value
                    selectedEasing = keyframe.easingFunction
                }
            }
            
        default:
            break
        }
    }
    
    /// Update an existing keyframe with new values
    private func updateExistingKeyframe() {
        guard let originalTime = originalKeyframeTime else { return }
        
        switch property.type {
        case .position:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGPoint> {
                // Remove the old keyframe
                track.removeKeyframe(at: originalTime)
                // Add the updated keyframe
                let keyframe = Keyframe(time: newKeyframeTime, value: newPositionValue, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        case .size:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat> {
                track.removeKeyframe(at: originalTime)
                let keyframe = Keyframe(time: newKeyframeTime, value: newSizeValue, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        case .rotation:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Double> {
                track.removeKeyframe(at: originalTime)
                let keyframe = Keyframe(time: newKeyframeTime, value: newRotationValue, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        case .color:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Color> {
                track.removeKeyframe(at: originalTime)
                let keyframe = Keyframe(time: newKeyframeTime, value: newColorValue, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        case .opacity:
            if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<Double> {
                track.removeKeyframe(at: originalTime)
                let keyframe = Keyframe(time: newKeyframeTime, value: newOpacityValue, easingFunction: selectedEasing)
                track.add(keyframe: keyframe)
            }
            
        case .scale:
            if property.name == "Font Size" {
                if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat> {
                    track.removeKeyframe(at: originalTime)
                    let constrainedFontSize = max(8, min(200, newFontSizeValue))
                    let keyframe = Keyframe(time: newKeyframeTime, value: constrainedFontSize, easingFunction: selectedEasing)
                    track.add(keyframe: keyframe)
                }
            } else {
                if let track = animationController.getTrack(id: property.id) as? KeyframeTrack<CGFloat> {
                    track.removeKeyframe(at: originalTime)
                    let constrainedScale = max(0.1, min(5.0, newScaleValue))
                    let keyframe = Keyframe(time: newKeyframeTime, value: constrainedScale, easingFunction: selectedEasing)
                    track.add(keyframe: keyframe)
                }
            }
            
        default:
            break
        }
    }
    
    /// Convert an EasingFunction to a user-friendly display name
    private func easingFunctionDisplayName(_ easing: EasingFunction) -> String {
        switch easing {
        case .linear:
            return "Linear"
        case .easeIn:
            return "Ease In"
        case .easeOut:
            return "Ease Out"
        case .easeInOut:
            return "Ease In Out"
        case .bounce:
            return "Bounce"
        case .elastic:
            return "Elastic"
        case .spring:
            return "Spring"
        case .sine:
            return "Sine"
        case .customCubicBezier(let x1, let y1, let x2, let y2):
            // Check if it matches common presets
            if abs(x1 - 0.42) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 1.0) < 0.01 && abs(y2 - 1.0) < 0.01 {
                return "Custom (Ease In)"
            } else if abs(x1 - 0.0) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 0.58) < 0.01 && abs(y2 - 1.0) < 0.01 {
                return "Custom (Ease Out)"
            } else if abs(x1 - 0.42) < 0.01 && abs(y1 - 0.0) < 0.01 && abs(x2 - 0.58) < 0.01 && abs(y2 - 1.0) < 0.01 {
                return "Custom (Ease In Out)"
            } else if abs(x1 - 0.68) < 0.01 && abs(y1 + 0.55) < 0.01 && abs(x2 - 0.265) < 0.01 && abs(y2 - 1.55) < 0.01 {
                return "Custom (Bounce)"
            } else {
                return "Custom Curve"
            }
        }
    }
}
