import SwiftUI

/// A sheet view for adding new keyframes
struct AddKeyframeSheet: View {
    @ObservedObject var animationController: AnimationController
    let property: AnimatableProperty
    @Binding var isPresented: Bool
    @Binding var newKeyframeTime: Double
    @Binding var selectedElement: CanvasElement?
    var onAddKeyframe: (Double) -> Void
    
    @State private var newPositionValue = CGPoint(x: 0, y: 0)
    @State private var newSizeValue: CGFloat = 50
    @State private var newRotationValue: Double = 0
    @State private var newColorValue = Color.blue
    @State private var newOpacityValue: Double = 1.0
    @State private var selectedEasing: EasingFunction = .linear
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Add Keyframe")
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
                
            default:
                Text("Unsupported property type")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            // Easing function selector
            VStack(alignment: .leading) {
                Text("Easing")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Picker("", selection: $selectedEasing) {
                    Text("Linear").tag(EasingFunction.linear)
                    Text("Ease In").tag(EasingFunction.easeIn)
                    Text("Ease Out").tag(EasingFunction.easeOut)
                    Text("Ease In Out").tag(EasingFunction.easeInOut)
                }
                .pickerStyle(.segmented)
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
                
                Button("Add Keyframe") {
                    addNewKeyframe()
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
    }
    
    /// Initialize the values based on the existing keyframes
    private func initializeValues() {
        // Get initial value from the selected element if available
        guard let element = selectedElement else { return }
        
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
            
        default:
            break
        }
}
}
