import SwiftUI

/// A view that allows users to select and apply animation presets
struct AnimationPresetSelector: View {
    @ObservedObject var animationController: AnimationController
    let elementId: String
    @State private var selectedPresetType: AnimationPresetType = .fade
    @State private var selectedDirection: AnimationDirection = .right
    @State private var startTime: Double = 0.0
    @State private var duration: Double = 1.0
    @State private var initialPosition: CGPoint = .zero
    @State private var initialScale: CGFloat = 1.0
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Animation Presets")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Preset type selector
            VStack(alignment: .leading, spacing: 6) {
                Text("Preset Type:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnimationPresetType.allCases) { presetType in
                            presetButton(for: presetType)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 40)
            }
            
            // Direction selector (shown only for applicable presets)
            if showsDirectionSelector(for: selectedPresetType) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Direction:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    directionSelector
                }
                .padding(.top, 8)
            }
            
            // Time controls
            VStack(alignment: .leading, spacing: 6) {
                Text("Timing:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start Time:")
                            .font(.caption)
                        
                        HStack {
                            Slider(value: $startTime, in: 0...animationController.duration)
                                .frame(width: 120)
                            
                            Text(String(format: "%.2fs", startTime))
                                .monospacedDigit()
                                .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Duration:")
                            .font(.caption)
                        
                        HStack {
                            Slider(value: $duration, in: 0.1...3.0)
                                .frame(width: 120)
                            
                            Text(String(format: "%.2fs", duration))
                                .monospacedDigit()
                                .font(.caption)
                        }
                    }
                }
            }
            .padding(.top, 8)
            
            // Apply button
            Button(action: applySelectedPreset) {
                Text("Apply Preset")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 16)
        }
        .padding()
        .frame(width: 350)
    }
    
    // Create a button for each preset type
    private func presetButton(for presetType: AnimationPresetType) -> some View {
        Button(action: {
            selectedPresetType = presetType
        }) {
            VStack {
                Image(systemName: presetType.systemIcon)
                    .font(.system(size: 16))
                
                Text(presetType.displayName)
                    .font(.caption)
            }
            .frame(width: 60, height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(selectedPresetType == presetType ? .accentColor : Color(.controlBackgroundColor))
        .foregroundStyle(selectedPresetType == presetType ? .white : .primary)
    }
    
    // Direction selector for applicable presets
    private var directionSelector: some View {
        Picker("Direction", selection: $selectedDirection) {
            ForEach(directionOptions(for: selectedPresetType)) { direction in
                Text(direction.displayName).tag(direction)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // Determine if we should show direction selector for this preset type
    private func showsDirectionSelector(for presetType: AnimationPresetType) -> Bool {
        switch presetType {
        case .fade, .custom:
            return false
        case .slide, .scale, .rotate, .bounce:
            return true
        }
    }
    
    // Get the relevant direction options for the selected preset type
    private func directionOptions(for presetType: AnimationPresetType) -> [AnimationDirection] {
        switch presetType {
        case .slide, .bounce:
            return [.left, .right, .up, .down]
        case .scale:
            return [.inward, .outward]
        case .rotate:
            return [.left, .right]
        default:
            return []
        }
    }
    
    // Apply the selected preset to the element
    private func applySelectedPreset() {
        AnimationPreset.applyPreset(
            animationController: animationController,
            elementId: elementId,
            startTime: startTime,
            duration: duration,
            presetType: selectedPresetType,
            direction: selectedDirection,
            initialPosition: initialPosition,
            initialScale: initialScale
        )
    }
}

#if !DISABLE_PREVIEWS
struct AnimationPresetSelector_Previews: PreviewProvider {
    static var previews: some View {
        let animationController = AnimationController()
        animationController.setup(duration: 5.0)
        
        return AnimationPresetSelector(
            animationController: animationController,
            elementId: "previewElement"
        )
        .frame(width: 350, height: 400)
        .fixedSize()
    }
}
#endif 