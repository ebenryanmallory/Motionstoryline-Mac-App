import SwiftUI
import AppKit

// Enum defining the available design tools
public enum DesignTool {
    case select, text, rectangle, ellipse
}

public struct DesignToolbar: View {
    @Binding var selectedTool: DesignTool
    
    public init(selectedTool: Binding<DesignTool>) {
        self._selectedTool = selectedTool
    }
    
    public var body: some View {
        HStack {
            // Tools
            HStack(spacing: 2) {
                ForEach([
                    (DesignTool.select, "arrow.up.left.and.arrow.down.right", "Select & Move"),
                    (DesignTool.text, "text.cursor", "Text"),
                    (DesignTool.rectangle, "rectangle", "Rectangle"),
                    (DesignTool.ellipse, "circle", "Ellipse")
                ], id: \.0) { tool, icon, label in
                    Button(action: {
                        selectedTool = tool
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                            
                            Text(label)
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(minWidth: 64, minHeight: 54)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .foregroundColor(selectedTool == tool ? .white : .primary)
                        .background(selectedTool == tool ? Color.blue : Color.clear)
                        .contentShape(Rectangle())
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(toolHelp(for: tool))
                }
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(6)
            
            // Status bar
            if selectedTool == .select {
                Text("Click to select and move elements")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else {
                HStack(spacing: 4) {
                    Text(toolStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .border(Color.gray.opacity(0.2), width: 0.5)
    }
    
    // Helper to show status text based on selected tool
    private var toolStatusText: String {
        switch selectedTool {
        case .text:
            return "Click anywhere to add text, then type and press Enter when done"
        case .rectangle:
            return "Click and drag to create a square. Hold Shift to create a rectangle with free proportions"
        case .ellipse:
            return "Click and drag to create a circle. Hold Shift to create an ellipse with free proportions"
        default:
            return ""
        }
    }
    
    // Helper to provide context-sensitive help
    private func toolHelp(for tool: DesignTool) -> String {
        switch tool {
        case .select:
            return "Selection Tool: Click to select elements, drag to move them"
        case .text:
            return "Text Tool: Add and edit text elements"
        case .rectangle:
            return "Rectangle Tool: Click and drag to create rectangles"
        case .ellipse:
            return "Ellipse Tool: Click and drag to create ellipses and circles"
        }
    }
}

// Preview with proper conditional compilation
#if !DISABLE_PREVIEWS
#Preview {
    DesignToolbar(selectedTool: .constant(.select))
} 
#endif 
