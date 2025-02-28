import SwiftUI
import AppKit

// Enum defining the available design tools
public enum DesignTool {
    case select, rectangle, ellipse, text, pen, hand
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
                    (DesignTool.rectangle, "square", "Square"),
                    (DesignTool.ellipse, "circle", "Circle"),
                    (DesignTool.text, "text.cursor", "Text"),
                    (DesignTool.pen, "pencil", "Pen"),
                    (DesignTool.hand, "hand.raised", "Hand")
                ], id: \.0) { tool, icon, tooltip in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .padding(6)
                                .frame(width: 32, height: 32)
                                .foregroundColor(selectedTool == tool ? .white : .primary)
                            
                            if let shortcut = shortcutHint(for: tool) {
                                Text(shortcut)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedTool == tool ? .white.opacity(0.8) : .secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .background(selectedTool == tool ? Color.accentColor : Color.clear)
                    .cornerRadius(4)
                    .help("\(tooltip) (\(shortcutHint(for: tool) ?? ""))")
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedTool == tool ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
                    // Make the selection tool slightly larger to indicate it's the default
                    .scaleEffect(tool == .select ? 1.05 : 1.0)
                }
            }
            .padding(2)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            // Tool status indicator
            if selectedTool == .select {
                Text("Click to select and move elements")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else if selectedTool != .hand {
                HStack(spacing: 4) {
                    Text(toolStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
                    if selectedTool == .rectangle || selectedTool == .ellipse {
                        Image(systemName: "1.circle")
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 8))
                        
                        Image(systemName: "2.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // Helper to show status text based on selected tool
    private var toolStatusText: String {
        switch selectedTool {
        case .rectangle:
            return "Click once to set first corner, then click again to create a square"
        case .ellipse:
            return "Click once to set first point, then click again to create a circle"
        case .text:
            return "Click anywhere to add text, then type and press Enter when done"
        case .pen:
            return "Click and drag to draw"
        default:
            return ""
        }
    }
    
    // Helper to show keyboard shortcuts for tools
    private func shortcutHint(for tool: DesignTool) -> String? {
        switch tool {
        case .select:
            return "V"
        case .rectangle:
            return "R"
        case .ellipse:
            return "E"
        case .text:
            return "T"
        case .pen:
            return "P"
        case .hand:
            return "H"
        }
    }
}

#Preview {
    DesignToolbar(selectedTool: .constant(.select))
} 