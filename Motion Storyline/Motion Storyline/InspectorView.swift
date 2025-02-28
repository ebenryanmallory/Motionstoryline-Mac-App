import SwiftUI
import AppKit

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
                        .padding(.horizontal)
                        .padding(.top)
                        
                        Divider()
                        
                        // Position controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Position")
                                .font(.headline)
                            
                            HStack {
                                Text("X:")
                                    .frame(width: 20, alignment: .leading)
                                
                                TextField("X", value: Binding(
                                    get: { element.position.x },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.position.x = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            HStack {
                                Text("Y:")
                                    .frame(width: 20, alignment: .leading)
                                
                                TextField("Y", value: Binding(
                                    get: { element.position.y },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.position.y = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Size controls
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Size")
                                .font(.headline)
                            
                            HStack {
                                Text("W:")
                                    .frame(width: 20, alignment: .leading)
                                
                                TextField("Width", value: Binding(
                                    get: { element.size.width },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.size.width = max(10, newValue)
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            HStack {
                                Text("H:")
                                    .frame(width: 20, alignment: .leading)
                                
                                TextField("Height", value: Binding(
                                    get: { element.size.height },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.size.height = max(10, newValue)
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Rotation control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rotation")
                                .font(.headline)
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { element.rotation },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.rotation = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), in: 0...360, step: 1)
                                
                                Text("\(Int(element.rotation))°")
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Opacity control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Opacity")
                                .font(.headline)
                            
                            HStack {
                                Slider(value: Binding(
                                    get: { element.opacity },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.opacity = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ), in: 0...1, step: 0.01)
                                
                                Text("\(Int(element.opacity * 100))%")
                                    .frame(width: 40, alignment: .trailing)
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
                        
                        // Text content (only for text elements)
                        if element.type == .text {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Text Content")
                                    .font(.headline)
                                
                                TextEditor(text: Binding(
                                    get: { element.text },
                                    set: { newValue in
                                        if var updatedElement = selectedElement {
                                            updatedElement.text = newValue
                                            selectedElement = updatedElement
                                        }
                                    }
                                ))
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
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

#Preview {
    InspectorView(
        selectedElement: .constant(CanvasElement.rectangle(at: CGPoint(x: 100, y: 100))),
        onClose: {}
    )
} 