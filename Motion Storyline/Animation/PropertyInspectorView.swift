import SwiftUI
import AppKit

/// A view for inspecting and editing keyframe properties
struct PropertyInspectorView: View {
    @ObservedObject var animationController: AnimationController
    let property: AnimatableProperty
    @Binding var selectedKeyframeTime: Double?
    @State private var selectedEasing: EasingFunction = .linear
    @State private var showCurveEditor: Bool = false
    @State private var customBezierValues = BezierControlPoints(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let keyframeTime = selectedKeyframeTime {
                HStack {
                    Text("Selected Keyframe:")
                        .font(.headline)
                    
                    Text("Time: \(String(format: "%.2f", keyframeTime))s")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                }
                
                // Show property-specific value editor
                switch property.type {
                case .position:
                    positionEditor(property: property, time: keyframeTime)
                case .size:
                    sizeEditor(property: property, time: keyframeTime)
                case .rotation:
                    rotationEditor(property: property, time: keyframeTime)
                case .opacity:
                    opacityEditor(property: property, time: keyframeTime)
                case .color:
                    colorEditor(property: property, time: keyframeTime)
                case .scale:
                    // Handle both scale and fontSize using the same editor since they're both CGFloat
                    if property.name == "Font Size" {
                        fontSizeEditor(property: property, time: keyframeTime)
                    } else {
                        scaleEditor(property: property, time: keyframeTime)
                    }
                default:
                    Text("Unsupported property type")
                }
                
                // Easing function selector
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Easing Function")
                            .font(.headline)
                        
                        // Display current easing type inline
                        Text("(\(easingFunctionDisplayName(selectedEasing)))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                        
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
                    .onChange(of: selectedEasing) { oldValue, newValue in
                        if let time = selectedKeyframeTime {
                            updateEasingFunction(for: property, at: time, to: newValue)
                        }
                    }
                    
                    // Show custom bezier info if it's selected
                    if case .customCubicBezier(let x1, let y1, let x2, let y2) = selectedEasing {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bezier Values:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("cubic-bezier(\(String(format: "%.2f", x1)), \(String(format: "%.2f", y1)), \(String(format: "%.2f", x2)), \(String(format: "%.2f", y2)))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.top, 8)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack {
                    Spacer()
                    Text("Select a keyframe or add a new one")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .onAppear {
            loadEasingFunction(for: property)
        }
        .onChange(of: selectedKeyframeTime) { oldValue, newValue in
            loadEasingFunction(for: property)
        }
        .id("\(property.id)_\(selectedKeyframeTime?.description ?? "none")")  // Force refresh when property or keyframe changes
        .sheet(isPresented: $showCurveEditor) {
            if let keyframeTime = selectedKeyframeTime {
                CurveEditorSheet(
                    property: property,
                    animationController: animationController,
                    selectedKeyframeTime: keyframeTime,
                    isPresented: $showCurveEditor,
                    onCurveUpdate: { newBezier in
                        // Update the easing function with the custom bezier
                        let newEasing = EasingFunction.customCubicBezier(x1: newBezier.x1, y1: newBezier.y1, x2: newBezier.x2, y2: newBezier.y2)
                        selectedEasing = newEasing
                        updateEasingFunction(for: property, at: keyframeTime, to: newEasing)
                        customBezierValues = BezierControlPoints(from: newBezier)
                    }
                )
            }
        }
    }
    
    // MARK: - Property Specific Editors
    
    // Editor for position property
    private func positionEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Position")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>?,
               let value = track.getValue(at: time) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("X")
                            .foregroundColor(.secondary)
                        
                        TextField("X", value: Binding(
                            get: { value.x },
                            set: { newValue in
                                updatePositionValue(for: property, at: time, to: CGPoint(x: newValue, y: value.y))
                            }
                        ), formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Y")
                            .foregroundColor(.secondary)
                        
                        TextField("Y", value: Binding(
                            get: { value.y },
                            set: { newValue in
                                updatePositionValue(for: property, at: time, to: CGPoint(x: value.x, y: newValue))
                            }
                        ), formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }
    
    // Editor for size property
    private func sizeEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Size")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGSize>?,
               let value = track.getValue(at: time) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Width")
                            .foregroundColor(.secondary)
                        
                        TextField("Width", value: Binding(
                            get: { value.width },
                            set: { updateSizeValue(for: property, at: time, to: CGSize(width: $0, height: value.height)) }
                        ), formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        
                        Slider(value: Binding(
                            get: { value.width },
                            set: { updateSizeValue(for: property, at: time, to: CGSize(width: $0, height: value.height)) }
                        ), in: 10...500)
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Height")
                            .foregroundColor(.secondary)
                        
                        TextField("Height", value: Binding(
                            get: { value.height },
                            set: { updateSizeValue(for: property, at: time, to: CGSize(width: value.width, height: $0)) }
                        ), formatter: NumberFormatter())
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        
                        Slider(value: Binding(
                            get: { value.height },
                            set: { updateSizeValue(for: property, at: time, to: CGSize(width: value.width, height: $0)) }
                        ), in: 10...500)
                        .frame(width: 120)
                    }
                }
            }
        }
    }
    
    // Editor for rotation property
    private func rotationEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Rotation")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let value = track.getValue(at: time) {
                HStack {
                    Text("Degrees")
                        .foregroundColor(.secondary)
                    
                    TextField("Rotation", value: Binding(
                        get: { value },
                        set: { updateRotationValue(for: property, at: time, to: $0) }
                    ), formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    
                    Slider(value: Binding(
                        get: { value.truncatingRemainder(dividingBy: 360) },
                        set: { updateRotationValue(for: property, at: time, to: $0) }
                    ), in: 0...360)
                    .frame(width: 150)
                }
            }
        }
    }
    
    // Editor for opacity property
    private func opacityEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Opacity")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let value = track.getValue(at: time) {
                HStack {
                    Text("Value")
                        .foregroundColor(.secondary)
                    
                    TextField("Opacity", value: Binding(
                        get: { value * 100 }, // Convert to percentage
                        set: { updateOpacityValue(for: property, at: time, to: $0 / 100.0) } // Convert back to 0-1
                    ), formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    
                    Text("%")
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { value },
                        set: { updateOpacityValue(for: property, at: time, to: $0) }
                    ), in: 0...1)
                    .frame(width: 150)
                }
            }
        }
    }
    
    // Editor for color property
    private func colorEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Color")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Color>?,
               let value = track.getValue(at: time) {
                ColorPicker("Color Value", selection: Binding(
                    get: { value },
                    set: { updateColorValue(for: property, at: time, to: $0) }
                ))
            }
        }
    }
    
    // Editor for font size property
    private func fontSizeEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Font Size")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>?,
               let value = track.getValue(at: time) {
                HStack {
                    Text("Size")
                        .foregroundColor(.secondary)
                    
                    TextField("Font Size", value: Binding(
                        get: { value },
                        set: { updateFontSizeValue(for: property, at: time, to: $0) }
                    ), formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    
                    Text("pt")
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { value },
                        set: { updateFontSizeValue(for: property, at: time, to: $0) }
                    ), in: 8...200)
                    .frame(width: 150)
                }
            }
        }
    }
    
    // Editor for scale property
    private func scaleEditor(property: AnimatableProperty, time: Double) -> some View {
        VStack(alignment: .leading) {
            Text("Scale")
                .font(.headline)
            
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>?,
               let value = track.getValue(at: time) {
                HStack {
                    Text("Value")
                        .foregroundColor(.secondary)
                    
                    TextField("Scale", value: Binding(
                        get: { value },
                        set: { updateScaleValue(for: property, at: time, to: $0) }
                    ), formatter: NumberFormatter())
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    
                    Slider(value: Binding(
                        get: { value },
                        set: { updateScaleValue(for: property, at: time, to: $0) }
                    ), in: 0.1...5.0)
                    .frame(width: 150)
                }
            }
        }
    }
    
    // MARK: - Value Update Methods
    
    /// Update the position value for a keyframe
    private func updatePositionValue(for property: AnimatableProperty, at time: Double, to newValue: CGPoint) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>? else { return }
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: newValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the size value for a keyframe
    private func updateSizeValue(for property: AnimatableProperty, at time: Double, to newValue: CGSize) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGSize>? else { return }
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: newValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the rotation value for a keyframe
    private func updateRotationValue(for property: AnimatableProperty, at time: Double, to newValue: Double) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? else { return }
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: newValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the opacity value for a keyframe
    private func updateOpacityValue(for property: AnimatableProperty, at time: Double, to newValue: Double) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>? else { return }
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value - constrain between 0 and 1
            let constrainedValue = max(0, min(1, newValue))
            let newKeyframe = Keyframe(time: time, value: constrainedValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the color value for a keyframe
    private func updateColorValue(for property: AnimatableProperty, at time: Double, to newValue: Color) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<Color>? else { return }
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: newValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the font size value for a keyframe
    private func updateFontSizeValue(for property: AnimatableProperty, at time: Double, to newValue: CGFloat) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? else { return }
        
        // Constrain the font size between 8pt and 200pt
        let constrainedValue = max(8, min(200, newValue))
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: constrainedValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the scale value for a keyframe
    private func updateScaleValue(for property: AnimatableProperty, at time: Double, to newValue: CGFloat) {
        guard let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGFloat>? else { return }
        
        // Constrain the scale between 0.1 and 5.0
        let constrainedValue = max(0.1, min(5.0, newValue))
        
        // Get the existing keyframe to preserve its easing function
        if let existingKeyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
            // Remove the old keyframe
            track.removeKeyframe(at: time)
            
            // Add a new keyframe with the updated value
            let newKeyframe = Keyframe(time: time, value: constrainedValue, easingFunction: existingKeyframe.easingFunction)
            track.add(keyframe: newKeyframe)
            
            // Force the AnimationController to update
            animationController.updateAnimatedProperties()
        }
    }
    
    /// Update the easing function for a keyframe
    private func updateEasingFunction(for property: AnimatableProperty, at time: Double, to newEasing: EasingFunction) {
        switch property.type {
        case .position:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
                // Remove the old keyframe
                track.removeKeyframe(at: time)
                
                // Add a new keyframe with the updated easing function
                let newKeyframe = Keyframe(time: time, value: keyframe.value, easingFunction: newEasing)
                track.add(keyframe: newKeyframe)
            }
        case .size:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGSize>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
                // Remove the old keyframe
                track.removeKeyframe(at: time)
                
                // Add a new keyframe with the updated easing function
                let newKeyframe = Keyframe(time: time, value: keyframe.value, easingFunction: newEasing)
                track.add(keyframe: newKeyframe)
            }
        case .rotation:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
                // Remove the old keyframe
                track.removeKeyframe(at: time)
                
                // Add a new keyframe with the updated easing function
                let newKeyframe = Keyframe(time: time, value: keyframe.value, easingFunction: newEasing)
                track.add(keyframe: newKeyframe)
            }
        case .opacity:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
                // Remove the old keyframe
                track.removeKeyframe(at: time)
                
                // Add a new keyframe with the updated easing function
                let newKeyframe = Keyframe(time: time, value: keyframe.value, easingFunction: newEasing)
                track.add(keyframe: newKeyframe)
            }
        case .color:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Color>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - time) < 0.001 }) {
                // Remove the old keyframe
                track.removeKeyframe(at: time)
                
                // Add a new keyframe with the updated easing function
                let newKeyframe = Keyframe(time: time, value: keyframe.value, easingFunction: newEasing)
                track.add(keyframe: newKeyframe)
            }
        default:
            break
        }
    }
    
    /// Load the easing function from the selected keyframe
    private func loadEasingFunction(for property: AnimatableProperty) {
        guard let keyframeTime = selectedKeyframeTime else { return }
        
        switch property.type {
        case .position:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGPoint>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - keyframeTime) < 0.001 }) {
                selectedEasing = keyframe.easingFunction
            }
        case .size:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<CGSize>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - keyframeTime) < 0.001 }) {
                selectedEasing = keyframe.easingFunction
            }
        case .rotation:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - keyframeTime) < 0.001 }) {
                selectedEasing = keyframe.easingFunction
            }
        case .opacity:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Double>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - keyframeTime) < 0.001 }) {
                selectedEasing = keyframe.easingFunction
            }
        case .color:
            if let track = animationController.getTrack(id: property.id) as KeyframeTrack<Color>?,
               let keyframe = track.allKeyframes.first(where: { abs($0.time - keyframeTime) < 0.001 }) {
                selectedEasing = keyframe.easingFunction
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

#if !DISABLE_PREVIEWS
struct PropertyInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample property and animation controller for the preview
        let animationController = AnimationController()
        let property = AnimatableProperty(id: "position", name: "Position", type: .position, icon: "arrow.up.and.down.and.arrow.left.and.right")
        
        return PropertyInspectorView(
            animationController: animationController,
            property: property,
            selectedKeyframeTime: .constant(1.0)
        )
        .frame(width: 300, height: 400)
        .padding()
    }
}
#endif
