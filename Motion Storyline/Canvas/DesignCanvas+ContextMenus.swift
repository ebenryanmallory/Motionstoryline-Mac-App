import SwiftUI
import Combine
import AppKit

// MARK: - DesignCanvas Context Menu Extensions
extension DesignCanvas {
    // Canvas context menu content
    var canvasContextMenu: some View {
        Group {
            // Context menu for empty canvas area
            Button(action: {
                // Create rectangle at cursor position
                if let position = currentMousePosition {
                    // Removed constraint to canvas bounds
                    let newRectangle = CanvasElement.rectangle(
                        at: position,
                        size: CGSize(width: 150, height: 100)
                    )
                    canvasElements.append(newRectangle)
                    selectedElementId = newRectangle.id
                }
            }) {
                Label("Add Rectangle", systemImage: "rectangle")
            }
            
            Button(action: {
                // Create ellipse at cursor position
                if let position = currentMousePosition {
                    // Removed constraint to canvas bounds
                    let newEllipse = CanvasElement.ellipse(
                        at: position,
                        size: CGSize(width: 100, height: 100)
                    )
                    canvasElements.append(newEllipse)
                    selectedElementId = newEllipse.id
                }
            }) {
                Label("Add Ellipse", systemImage: "circle")
            }
            
            Button(action: {
                // Create text element at cursor position
                if let position = currentMousePosition {
                    // Removed constraint to canvas bounds
                    let newText = CanvasElement.text(at: position)
                    canvasElements.append(newText)
                    selectedElementId = newText.id
                    isEditingText = true
                    editingText = newText.text
                }
            }) {
                Label("Add Text", systemImage: "text.cursor")
            }
            
            Divider()
            
            gridSettingsMenu
            
            Divider()
            
            viewSettingsMenu
            
            if !canvasElements.isEmpty {
                Divider()
                
                elementSelectionMenu
            }
            
            if canvasElements.count > 0 {
                Divider()
                
                Button(action: {
                    // Clear canvas (remove all elements)
                    // Show confirmation dialog (in a real app)
                    canvasElements.removeAll()
                    selectedElementId = nil
                }) {
                    Label("Clear Canvas", systemImage: "xmark.square")
                }
            }
        }
    }
    
    // Grid settings submenu
    var gridSettingsMenu: some View {
        Menu("Grid Settings") {
            Toggle(isOn: $showGrid) {
                Label("Show Grid", systemImage: "grid")
            }
            
            Toggle(isOn: $snapToGridEnabled) {
                Label("Snap to Grid", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            }
            
            Menu("Grid Size") {
                Button(action: {
                    gridSize = 10
                }) {
                    Label("Small (10px)", systemImage: gridSize == 10 ? "checkmark" : "")
                }
                
                Button(action: {
                    gridSize = 20
                }) {
                    Label("Medium (20px)", systemImage: gridSize == 20 ? "checkmark" : "")
                }
                
                Button(action: {
                    gridSize = 40
                }) {
                    Label("Large (40px)", systemImage: gridSize == 40 ? "checkmark" : "")
                }
            }
            
            Divider()
            
            Text("Keyboard Shortcuts:")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⌘G: Toggle Grid")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("⇧⌘G: Toggle Snap to Grid")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    // View settings submenu
    var viewSettingsMenu: some View {
        Menu("View") {
            Button(action: {
                // Center the view on content by resetting viewport offset
                viewportOffset = .zero
            }) {
                Label("Center Content", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .keyboardShortcut(KeyEquivalent("a"), modifiers: [.command])
            
            Button(action: {
                // Zoom in
                zoomIn()
            }) {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button(action: {
                // Zoom out
                zoomOut()
            }) {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .keyboardShortcut("-", modifiers: .command)
            
            Button(action: {
                // Reset zoom to 100%
                resetZoom()
            }) {
                Label("Reset Zoom", systemImage: "1.magnifyingglass")
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
    
    // Element selection menu items
    var elementSelectionMenu: some View {
        Group {
            Button(action: {
                // Select a tool from the quick menu
                selectedTool = .select
            }) {
                Label("Select Tool", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button(action: {
                // Select all elements (in a real app, this would select multiple elements)
                if !canvasElements.isEmpty {
                    selectedElementId = canvasElements.first?.id
                }
            }) {
                Label("Select All", systemImage: "checkmark.circle")
            }
            
            if selectedElementId != nil {
                Button(action: {
                    // Deselect all
                    selectedElementId = nil
                }) {
                    Label("Deselect All", systemImage: "rectangle.dashed")
                }
            }
        }
    }
    
    // Element context menu
    func elementContextMenu(for element: CanvasElement) -> some View {
        let canvasElements = self.canvasElements // Capture canvasElements
        
        return Group {
            // Context menu for elements
            Button(action: {
                // Duplicate the element
                if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                    var newElement = canvasElements[index]
                    newElement.id = UUID()
                    newElement.position = CGPoint(
                        x: newElement.position.x + 20,
                        y: newElement.position.y + 20
                    )
                    newElement.displayName = "Copy of \(newElement.displayName)"
                    self.canvasElements.append(newElement)
                    self.selectedElementId = newElement.id
                }
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Button(action: {
                // Delete the element
                self.canvasElements.removeAll(where: { $0.id == element.id })
                self.selectedElementId = nil
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Divider()
            
            if element.type == .text {
                textElementOptions(for: element)
            }
            
            elementColorOptions(for: element)
            elementOpacityOptions(for: element)
        }
    }
    
    // Text element options
    func textElementOptions(for element: CanvasElement) -> some View {
        return Group {
            Button(action: {
                // Edit text
                self.selectedElementId = element.id
                self.isEditingText = true
                self.editingText = element.text
            }) {
                Label("Edit Text", systemImage: "pencil")
            }
            
            Menu("Text Alignment") {
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .leading
                    }
                }) {
                    Label("Left", systemImage: "text.alignleft")
                }
                
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .center
                    }
                }) {
                    Label("Center", systemImage: "text.aligncenter")
                }
                
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].textAlignment = .trailing
                    }
                }) {
                    Label("Right", systemImage: "text.alignright")
                }
            }
        }
    }
    
    // Element color options
    func elementColorOptions(for element: CanvasElement) -> some View {
        return Menu("Color") {
            ForEach(["Red", "Blue", "Green", "Orange", "Purple", "Black"], id: \.self) { colorName in
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].color = colorForName(colorName)
                    }
                }) {
                    Label {
                        Text(colorName)
                    } icon: {
                        Circle()
                            .fill(colorForName(colorName))
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
    }
    
    // Helper function to convert color name to Color
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "black": return .black
        default: return .gray
        }
    }
    
    // Element opacity options
    func elementOpacityOptions(for element: CanvasElement) -> some View {
        return Menu("Opacity") {
            ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { opacity in
                Button(action: {
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.canvasElements[index].opacity = opacity
                    }
                }) {
                    Label("\(Int(opacity * 100))%", systemImage: "circle.fill")
                        .foregroundColor(.yellow.opacity(opacity))
                }
            }
        }
    }
} 