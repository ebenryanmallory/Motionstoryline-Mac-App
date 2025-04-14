import SwiftUI
import AppKit

// Custom numeric stepper component that supports dragging
struct NumericStepper: View {
    @Binding var value: CGFloat
    var label: String
    var range: ClosedRange<CGFloat>? = nil
    var step: CGFloat = 1
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    @State private var dragStartValue: CGFloat = 0
    @State private var isDragging = false
    @State private var displayValue: String
    @FocusState private var isFocused: Bool
    
    init(value: Binding<CGFloat>, label: String, range: ClosedRange<CGFloat>? = nil, step: CGFloat = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self._value = value
        self.label = label
        self.range = range
        self.step = step
        self.onEditingChanged = onEditingChanged
        self._displayValue = State(initialValue: String(format: "%.0f", value.wrappedValue))
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Label
            Text(label)
                .frame(width: 20, alignment: .leading)
            
            // TextField for direct input
            TextField("", text: $displayValue)
                .frame(width: 60)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onSubmit {
                    updateValueFromText()
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        updateValueFromText()
                    }
                }
            
            // Stepper buttons
            HStack(spacing: 0) {
                Button {
                    decrementValue()
                } label: {
                    Image(systemName: "minus")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                Button {
                    incrementValue()
                } label: {
                    Image(systemName: "plus")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Drag indicator
            Rectangle()
                .fill(Color.clear)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                dragStartValue = value
                                onEditingChanged(true)
                            }
                            
                            // Calculate change based on drag distance
                            let dragSensitivity: CGFloat = 0.5
                            let dragChange = -gesture.translation.height * dragSensitivity * step
                            var newValue = dragStartValue + dragChange
                            
                            // Apply range constraints if provided
                            if let range = range {
                                newValue = max(range.lowerBound, min(range.upperBound, newValue))
                            }
                            
                            // Update the value
                            value = newValue
                            displayValue = String(format: "%.0f", value)
                        }
                        .onEnded { _ in
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
        .onChange(of: value) { oldValue, newValue in
            if !isDragging && !isFocused {
                displayValue = String(format: "%.0f", newValue)
            }
        }
    }
    
    private func updateValueFromText() {
        let formatter = NumberFormatter()
        if let number = formatter.number(from: displayValue) {
            var newValue = CGFloat(truncating: number)
            
            // Apply range constraints if provided
            if let range = range {
                newValue = max(range.lowerBound, min(range.upperBound, newValue))
            }
            
            value = newValue
        }
        
        // Update the display value regardless to ensure correct formatting
        displayValue = String(format: "%.0f", value)
    }
    
    private func incrementValue() {
        var newValue = value + step
        if let range = range {
            newValue = min(range.upperBound, newValue)
        }
        value = newValue
        displayValue = String(format: "%.0f", value)
        onEditingChanged(true)
        onEditingChanged(false)
    }
    
    private func decrementValue() {
        var newValue = value - step
        if let range = range {
            newValue = max(range.lowerBound, newValue)
        }
        value = newValue
        displayValue = String(format: "%.0f", value)
        onEditingChanged(true)
        onEditingChanged(false)
    }
}

// Custom percentage stepper for opacity
struct PercentageStepper: View {
    @Binding var value: Double
    var label: String
    var step: Double = 0.01
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    @State private var dragStartValue: Double = 0
    @State private var isDragging = false
    @State private var displayValue: String
    @FocusState private var isFocused: Bool
    
    init(value: Binding<Double>, label: String, step: Double = 0.01, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {
        self._value = value
        self.label = label
        self.step = step
        self.onEditingChanged = onEditingChanged
        self._displayValue = State(initialValue: "\(Int(value.wrappedValue * 100))")
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Label
            Text(label)
                .frame(width: 20, alignment: .leading)
            
            // TextField for direct input
            TextField("", text: $displayValue)
                .frame(width: 50)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.trailing)
                .focused($isFocused)
                .onSubmit {
                    updateValueFromText()
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        updateValueFromText()
                    }
                }
            
            Text("%")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // Stepper buttons
            HStack(spacing: 0) {
                Button {
                    decrementValue()
                } label: {
                    Image(systemName: "minus")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 16)
                
                Button {
                    incrementValue()
                } label: {
                    Image(systemName: "plus")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Drag indicator
            Rectangle()
                .fill(Color.clear)
                .frame(width: 16, height: 16)
                .overlay(
                    Image(systemName: "arrow.up.and.down")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                dragStartValue = value
                                onEditingChanged(true)
                            }
                            
                            // Calculate change based on drag distance
                            let dragSensitivity: Double = 0.005
                            let dragChange = -gesture.translation.height * dragSensitivity
                            var newValue = dragStartValue + dragChange
                            
                            // Apply range constraints
                            newValue = max(0, min(1, newValue))
                            
                            // Update the value
                            value = newValue
                            displayValue = "\(Int(value * 100))"
                        }
                        .onEnded { _ in
                            isDragging = false
                            onEditingChanged(false)
                        }
                )
                .onHover { hovering in
                    if hovering {
                        NSCursor.resizeUpDown.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }
        }
        .onChange(of: value) { oldValue, newValue in
            if !isDragging && !isFocused {
                displayValue = "\(Int(newValue * 100))"
            }
        }
    }
    
    private func updateValueFromText() {
        if let intValue = Int(displayValue) {
            let percentValue = Double(intValue) / 100.0
            value = max(0, min(1, percentValue))
        }
        
        // Update the display value regardless to ensure correct formatting
        displayValue = "\(Int(value * 100))"
    }
    
    private func incrementValue() {
        let newValue = min(1, value + step)
        value = newValue
        displayValue = "\(Int(value * 100))"
        onEditingChanged(true)
        onEditingChanged(false)
    }
    
    private func decrementValue() {
        let newValue = max(0, value - step)
        value = newValue
        displayValue = "\(Int(value * 100))"
        onEditingChanged(true)
        onEditingChanged(false)
    }
}

struct InspectorView: View {
    @Binding var selectedElement: CanvasElement?
    var onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inspector header
            HStack {
                Text("Inspector")
                    .font(.headline)
                    .padding()
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if let element = selectedElement {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Element type and name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(element.type.rawValue)
                                .font(.headline)
                            
                            if element.type == .text {
                                Text("Text Content")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                TextEditor(text: Binding(
                                    get: { element.text },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.text = newValue
                                            updatedElement.displayName = newValue.isEmpty ? "Text" : newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ))
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                
                                // Text alignment control - only for text elements
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Text Alignment")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            if var updatedElement = selectedElement {
                                                updatedElement.textAlignment = .leading
                                                selectedElement = updatedElement
                                            }
                                        }) {
                                            Image(systemName: "text.alignleft")
                                                .padding(8)
                                                .background(element.textAlignment == .leading ? Color.blue.opacity(0.2) : Color.clear)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            if var updatedElement = selectedElement {
                                                updatedElement.textAlignment = .center
                                                selectedElement = updatedElement
                                            }
                                        }) {
                                            Image(systemName: "text.aligncenter")
                                                .padding(8)
                                                .background(element.textAlignment == .center ? Color.blue.opacity(0.2) : Color.clear)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            if var updatedElement = selectedElement {
                                                updatedElement.textAlignment = .trailing
                                                selectedElement = updatedElement
                                            }
                                        }) {
                                            Image(systemName: "text.alignright")
                                                .padding(8)
                                                .background(element.textAlignment == .trailing ? Color.blue.opacity(0.2) : Color.clear)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            } else {
                                TextField("Display Name", text: Binding(
                                    get: { element.displayName },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.displayName = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Divider()
                        
                        // Position controls - add explicit X/Y controls to position elements off-canvas
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.headline)
                            
                            HStack {
                                // X position control
                                NumericStepper(
                                    value: Binding(
                                        get: { element.position.x },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                updatedElement.position.x = newValue
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ),
                                    label: "X:",
                                    // Allow full range of positions including off-canvas
                                    range: -5000...5000
                                )
                                
                                // Y position control
                                NumericStepper(
                                    value: Binding(
                                        get: { element.position.y },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                updatedElement.position.y = newValue
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ),
                                    label: "Y:",
                                    // Allow full range of positions including off-canvas
                                    range: -5000...5000
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Size controls
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Size")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // Only show the lock for non-text elements
                                if element.type != .text {
                                    // Aspect ratio lock toggle
                                    Button(action: {
                                        if var updatedElement = selectedElement {
                                            // Toggle the isAspectRatioLocked property
                                            updatedElement.isAspectRatioLocked.toggle()
                                            selectedElement = updatedElement
                                        }
                                    }) {
                                        Image(systemName: element.isAspectRatioLocked ? "lock" : "lock.open")
                                            .foregroundColor(element.isAspectRatioLocked ? .blue : .secondary)
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .help(element.isAspectRatioLocked ? "Unlock aspect ratio" : "Lock aspect ratio")
                                }
                            }
                            
                            // Width with NumericStepper
                            NumericStepper(
                                value: Binding(
                                    get: { element.size.width },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            // Keep 10px minimum size constraint
                                            let constrainedWidth = max(10, newValue)
                                            updatedElement.size.width = constrainedWidth
                                            
                                            // If aspect ratio is locked, adjust height proportionally
                                            if updatedElement.isAspectRatioLocked && updatedElement.type != .text {
                                                let ratio = element.size.height / element.size.width
                                                updatedElement.size.height = constrainedWidth * ratio
                                            }
                                            
                                            selectedElement = updatedElement
                                        }
                                    }
                                ),
                                label: "W:",
                                // Keep -5000...5000 range for position but enforce 10px minimum in the setter
                                range: -5000...5000
                            )
                            
                            // Height with NumericStepper
                            NumericStepper(
                                value: Binding(
                                    get: { element.size.height },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            // Keep 10px minimum size constraint
                                            let constrainedHeight = max(10, newValue)
                                            updatedElement.size.height = constrainedHeight
                                            
                                            // If aspect ratio is locked, adjust width proportionally
                                            if updatedElement.isAspectRatioLocked && updatedElement.type != .text {
                                                let ratio = element.size.width / element.size.height
                                                updatedElement.size.width = constrainedHeight * ratio
                                            }
                                            
                                            selectedElement = updatedElement
                                        }
                                    }
                                ),
                                label: "H:",
                                // Keep -5000...5000 range for position but enforce 10px minimum in the setter
                                range: -5000...5000
                            )
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Rotation control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rotation")
                                .font(.headline)
                            
                            HStack {
                                // Slider for quick adjustments
                                Slider(
                                    value: Binding<Double>(
                                        get: { 
                                            // Ensure we have a valid rotation value between 0-360
                                            let rotation = Double(element.rotation)
                                            return max(0, min(360, rotation))
                                        },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                // Constrain the value to 0-360 range
                                                let constrainedValue = max(0, min(360, newValue))
                                                updatedElement.rotation = CGFloat(constrainedValue)
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ), 
                                    in: 0...360, 
                                    step: 1
                                )
                                .frame(maxWidth: .infinity)
                                
                                // Numeric stepper for precise control
                                NumericStepper(
                                    value: Binding<CGFloat>(
                                        get: { 
                                            // Ensure we have a valid rotation value between 0-360
                                            return max(0, min(360, element.rotation))
                                        },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                // Constrain the value to 0-360 range
                                                updatedElement.rotation = max(0, min(360, newValue))
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ),
                                    label: "°",
                                    range: 0...360
                                )
                                .frame(width: 100)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Opacity control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Opacity")
                                .font(.headline)
                            
                            HStack {
                                // Slider for quick adjustments
                                Slider(
                                    value: Binding<Double>(
                                        get: { 
                                            // Ensure we have a valid opacity value between 0-1
                                            return max(0, min(1, element.opacity))
                                        },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                // Constrain the value to 0-1 range
                                                updatedElement.opacity = max(0, min(1, newValue))
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ), 
                                    in: 0...1, 
                                    step: 0.01
                                )
                                .frame(maxWidth: .infinity)
                                
                                // Percentage stepper for precise control
                                PercentageStepper(
                                    value: Binding<Double>(
                                        get: { 
                                            // Ensure we have a valid opacity value between 0-1
                                            return max(0, min(1, element.opacity))
                                        },
                                        set: { newValue in
                                            if var updatedElement = selectedElement {
                                                // Constrain the value to 0-1 range
                                                updatedElement.opacity = max(0, min(1, newValue))
                                                selectedElement = updatedElement
                                            }
                                        }
                                    ),
                                    label: ""
                                )
                                .frame(width: 120)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Color picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(.headline)
                            
                            ColorPicker("", selection: Binding(
                                get: { element.color },
                                set: { newValue in
                                    if var updatedElement = selectedElement {
                                        updatedElement.color = newValue
                                        selectedElement = updatedElement
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 200)
        .compositingGroup() // Ensures the view is treated as a single unit
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    InspectorView(
        selectedElement: .constant(CanvasElement.rectangle(at: CGPoint(x: 100, y: 100))),
        onClose: {}
    )
} 
#endif
