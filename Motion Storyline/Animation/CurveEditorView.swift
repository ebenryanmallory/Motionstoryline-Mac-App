import SwiftUI

struct CurveEditorView: View {
    let property: String
    @Binding var currentTime: Double
    let keyframes: [(String, Double, Double)]
    var onKeyframeSelected: ((String, Double, Double)) -> Void
    
    // Find the min and max values for the property
    private var minValue: Double {
        keyframes.map { $0.2 }.min() ?? 0
    }
    
    private var maxValue: Double {
        keyframes.map { $0.2 }.max() ?? 100
    }
    
    // Find the min and max times
    private var minTime: Double {
        keyframes.map { $0.1 }.min() ?? 0
    }
    
    private var maxTime: Double {
        keyframes.map { $0.1 }.max() ?? 30
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(property)
                .font(.headline)
            
            GeometryReader { geometry in
                ZStack {
                    // Background grid
                    curveEditorGrid(size: geometry.size)
                    
                    // Animation curve
                    animationCurve(size: geometry.size)
                    
                    // Keyframe points
                    keyframePoints(size: geometry.size)
                    
                    // Current time indicator
                    currentTimeIndicator(size: geometry.size)
                }
                .background(Color.black.opacity(0.05))
                .cornerRadius(4)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCurrentTime(at: value.location.x, width: geometry.size.width)
                        }
                )
            }
        }
    }
    
    private func curveEditorGrid(size: CGSize) -> some View {
        Canvas { context, size in
            // Draw horizontal grid lines
            let valueRange = maxValue - minValue
            let valueStep = valueRange > 0 ? valueRange / 4 : 25
            
            for value in stride(from: minValue, through: maxValue + valueStep, by: valueStep) {
                let y = size.height - (value - minValue) / (maxValue - minValue) * size.height
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
            
            // Draw vertical grid lines
            let timeRange = maxTime - minTime
            let timeStep = timeRange > 0 ? timeRange / 8 : 5
            
            for time in stride(from: minTime, through: maxTime + timeStep, by: timeStep) {
                let x = (time - minTime) / (maxTime - minTime) * size.width
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    },
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )
            }
        }
    }
    
    private func animationCurve(size: CGSize) -> some View {
        let sortedKeyframes = keyframes.sorted { $0.1 < $1.1 }
        
        return Canvas { context, size in
            guard sortedKeyframes.count >= 2 else { return }
            
            var path = Path()
            
            // Start at the first keyframe
            let firstKeyframe = sortedKeyframes.first!
            let startX = (firstKeyframe.1 - minTime) / (maxTime - minTime) * size.width
            let startY = size.height - (firstKeyframe.2 - minValue) / (maxValue - minValue) * size.height
            path.move(to: CGPoint(x: startX, y: startY))
            
            // Draw lines between keyframes
            for i in 1..<sortedKeyframes.count {
                let keyframe = sortedKeyframes[i]
                let x = (keyframe.1 - minTime) / (maxTime - minTime) * size.width
                let y = size.height - (keyframe.2 - minValue) / (maxValue - minValue) * size.height
                
                // For a more realistic curve, we could use bezier curves here
                // For now, just use straight lines
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            context.stroke(
                path,
                with: .color(.blue),
                lineWidth: 2
            )
        }
    }
    
    private func keyframePoints(size: CGSize) -> some View {
        ForEach(keyframes.indices, id: \.self) { index in
            let keyframe = keyframes[index]
            let x = (keyframe.1 - minTime) / (maxTime - minTime) * size.width
            let y = size.height - (keyframe.2 - minValue) / (maxValue - minValue) * size.height
            
            Circle()
                .fill(Color.yellow)
                .frame(width: 8, height: 8)
                .position(x: x, y: y)
                .onTapGesture {
                    onKeyframeSelected(keyframe)
                }
        }
    }
    
    private func currentTimeIndicator(size: CGSize) -> some View {
        let x = (currentTime - minTime) / (maxTime - minTime) * size.width
        
        return Rectangle()
            .fill(Color.red)
            .frame(width: 1)
            .frame(height: size.height)
            .position(x: x, y: size.height / 2)
    }
    
    private func updateCurrentTime(at xPosition: CGFloat, width: CGFloat) {
        let newTime = minTime + Double(xPosition) / Double(width) * (maxTime - minTime)
        currentTime = max(minTime, min(maxTime, newTime))
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    CurveEditorView(
        property: "Opacity",
        currentTime: .constant(2.5),
        keyframes: [
            ("opacity", 0.0, 0.0),
            ("opacity", 1.0, 0.5),
            ("opacity", 0.0, 1.0)
        ],
        onKeyframeSelected: { _, _, _ in }
    )
    .frame(height: 200)
    .padding()
} 
#endif 