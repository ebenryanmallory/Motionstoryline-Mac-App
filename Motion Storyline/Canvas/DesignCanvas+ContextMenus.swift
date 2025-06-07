import SwiftUI
import Combine
import AppKit

// MARK: - DesignCanvas Context Menu Extensions
extension DesignCanvas {
    // Canvas context menu content
    var canvasContextMenu: some View {
        Group {
            // Context menu for empty canvas area
            Button(action: { [self] in
                // Create rectangle at cursor position
                if let position = self.currentMousePosition {
                    self.recordStateBeforeChange(actionName: "Create Rectangle")
                    
                    // Removed constraint to canvas bounds
                    let newRectangle = CanvasElement.rectangle(
                        at: position,
                        size: CGSize(width: 150, height: 100)
                    )
                    self.canvasElements.append(newRectangle)
                    self.handleElementSelection(newRectangle)
                    self.markDocumentAsChanged(actionName: "Create Rectangle")
                }
            }) {
                Label("Add Rectangle", systemImage: "rectangle")
            }
            
            Button(action: { [self] in
                // Create ellipse at cursor position
                if let position = self.currentMousePosition {
                    self.recordStateBeforeChange(actionName: "Create Ellipse")
                    
                    // Removed constraint to canvas bounds
                    let newEllipse = CanvasElement.ellipse(
                        at: position,
                        size: CGSize(width: 100, height: 100)
                    )
                    self.canvasElements.append(newEllipse)
                    self.handleElementSelection(newEllipse)
                    self.markDocumentAsChanged(actionName: "Create Ellipse")
                }
            }) {
                Label("Add Ellipse", systemImage: "circle")
            }
            
            Button(action: { [self] in
                // Create text element at cursor position
                if let position = self.currentMousePosition {
                    self.recordStateBeforeChange(actionName: "Create Text")
                    
                    // Removed constraint to canvas bounds
                    let newText = CanvasElement.text(at: position)
                    self.canvasElements.append(newText)
                    self.handleElementSelection(newText)
                    self.isEditingText = true
                    self.editingText = newText.text
                    self.markDocumentAsChanged(actionName: "Create Text")
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
                
                Button(action: { [self] in
                    // Clear canvas (remove all elements)
                    self.recordStateBeforeChange(actionName: "Clear Canvas")
                    
                    // Show confirmation dialog (in a real app)
                    self.canvasElements.removeAll()
                    self.selectedElementId = nil
                    self.markDocumentAsChanged(actionName: "Clear Canvas")
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
                Button(action: { [self] in
                    self.gridSize = 10
                }) {
                    Label("Small (10px)", systemImage: gridSize == 10 ? "checkmark" : "")
                }
                
                Button(action: { [self] in
                    self.gridSize = 20
                }) {
                    Label("Medium (20px)", systemImage: gridSize == 20 ? "checkmark" : "")
                }
                
                Button(action: { [self] in
                    self.gridSize = 40
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
            Button(action: { [self] in
                // Center the view on content by resetting viewport offset
                self.viewportOffset = .zero
            }) {
                Label("Center Content", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .keyboardShortcut(KeyEquivalent("a"), modifiers: [.command])
            
            Button(action: { [self] in
                // Zoom in on the canvas
                self.zoomIn()
            }) {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .keyboardShortcut("+", modifiers: .command)
            
            Button(action: { [self] in
                // Zoom out on the canvas
                self.zoomOut()
            }) {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .keyboardShortcut("-", modifiers: .command)
            
            Button(action: { [self] in
                // Reset zoom to 100%
                self.resetZoom()
            }) {
                Label("Reset Zoom", systemImage: "1.magnifyingglass")
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
    
    // Element selection menu items
    var elementSelectionMenu: some View {
        Group {
            Button(action: { [self] in
                // Select a tool from the quick menu
                self.selectedTool = .select
            }) {
                Label("Select Tool", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button(action: { [self] in
                // Select all elements (in a real app, this would select multiple elements)
                if !self.canvasElements.isEmpty, let firstElement = self.canvasElements.first {
                    self.handleElementSelection(firstElement)
                }
            }) {
                Label("Select All", systemImage: "checkmark.circle")
            }
            
            if self.selectedElementId != nil {
                Button(action: { [self] in
                    // Deselect all
                    self.selectedElementId = nil
                }) {
                    Label("Deselect All", systemImage: "rectangle.dashed")
                }
            }
        }
    }
    
    // Element context menu
    func elementContextMenu(for element: CanvasElement) -> some View {
        let canvasElements = self.canvasElements // Capture canvasElements
        
        return VStack {
            // Context menu for elements
            Button(action: { [self] in
                // Duplicate the element
                if let index = canvasElements.firstIndex(where: { $0.id == element.id }) {
                    self.recordStateBeforeChange(actionName: "Duplicate Element")
                    
                    var newElement = canvasElements[index]
                    newElement.id = UUID()
                    newElement.position = CGPoint(
                        x: newElement.position.x + 20,
                        y: newElement.position.y + 20
                    )
                    newElement.displayName = "Copy of \(newElement.displayName)"
                    self.canvasElements.append(newElement)
                    self.handleElementSelection(newElement)
                    self.markDocumentAsChanged(actionName: "Duplicate Element")
                }
            }) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            
            Button(action: { [self] in
                // Delete the element
                self.recordStateBeforeChange(actionName: "Delete Element")
                
                self.canvasElements.removeAll(where: { $0.id == element.id })
                self.selectedElementId = nil
                self.markDocumentAsChanged(actionName: "Delete Element")
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Divider()
            
            if element.type == .text {
                self.textElementOptions(for: element)
            }
            
            self.elementColorOptions(for: element)
            self.elementOpacityOptions(for: element)
        }
    }
    
    // Text element options
    func textElementOptions(for element: CanvasElement) -> some View {
        return Group {
            Button(action: { [self] in
                // Edit text
                self.handleElementSelection(element)
                self.isEditingText = true
                self.editingText = element.text
            }) {
                Label("Edit Text", systemImage: "pencil")
            }
            
            Menu("Text Alignment") {
                Button(action: { [self] in
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.recordStateBeforeChange(actionName: "Change Text Alignment")
                        self.canvasElements[index].textAlignment = .leading
                        self.markDocumentAsChanged(actionName: "Change Text Alignment")
                    }
                }) {
                    Label("Left", systemImage: "text.alignleft")
                }
                
                Button(action: { [self] in
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.recordStateBeforeChange(actionName: "Change Text Alignment")
                        self.canvasElements[index].textAlignment = .center
                        self.markDocumentAsChanged(actionName: "Change Text Alignment")
                    }
                }) {
                    Label("Center", systemImage: "text.aligncenter")
                }
                
                Button(action: { [self] in
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.recordStateBeforeChange(actionName: "Change Text Alignment")
                        self.canvasElements[index].textAlignment = .trailing
                        self.markDocumentAsChanged(actionName: "Change Text Alignment")
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
            ForEach(["Red", "Blue", "Green", "Orange", "Purple", "Black"], id: \.self) { [self] colorName in
                Button(action: { [self] in
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.recordStateBeforeChange(actionName: "Change Element Color")
                        self.canvasElements[index].color = self.colorForName(colorName)
                        self.markDocumentAsChanged(actionName: "Change Element Color")
                    }
                }) {
                    Label(colorName, systemImage: "paintpalette")
                }
                .labelStyle(IconOnlyLabelStyle())
            }
        }
    }
    
    // Helper function to convert color name to Color
    private func colorForName(_ name: String) -> Color {
        switch name.lowercased() {
        case "red": return Color(red: 1.0, green: 0.231, blue: 0.188, opacity: 1.0)
        case "blue": return Color(red: 0.2, green: 0.5, blue: 0.9, opacity: 1.0)
        case "green": return Color(red: 0.204, green: 0.780, blue: 0.349, opacity: 1.0)
        case "orange": return Color(red: 1.0, green: 0.584, blue: 0.0, opacity: 1.0)
        case "purple": return Color(red: 0.690, green: 0.322, blue: 0.871, opacity: 1.0)
        case "black": return Color(red: 0.0, green: 0.0, blue: 0.0, opacity: 1.0)
        default: return Color(white: 0.5, opacity: 1.0)
        }
    }
    
    // Element opacity options
    func elementOpacityOptions(for element: CanvasElement) -> some View {
        return Menu("Opacity") {
            ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { opacity in
                Button(action: { [self] in
                    if let index = self.canvasElements.firstIndex(where: { $0.id == element.id }) {
                        self.recordStateBeforeChange(actionName: "Change Element Opacity")
                        self.canvasElements[index].opacity = opacity
                        self.markDocumentAsChanged(actionName: "Change Element Opacity")
                    }
                }) {
                    Label("\(Int(opacity * 100))%", systemImage: "circle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.800, blue: 0.0, opacity: 1.0).opacity(opacity))
                }
            }
        }
    }
} 