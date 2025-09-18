import SwiftUI
import AppKit

struct TemplateCard: View {
    let name: String
    let type: String
    let id: String
    @State private var isHovered = false
    
    // Dynamic colors for light/dark mode adaptability
    private var cardBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    init(name: String, type: String, id: String = "") {
        self.name = name
        self.type = type
        self.id = id.isEmpty ? "\(name.lowercased())-\(type.lowercased())-template" : id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail - full width
            ZStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)

                    Text("Start with \(type)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            // Keep header clean without additional backdrop

            // Template info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)

                Text(type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.primary.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name) \(type) template")
        .accessibilityHint("Double-tap to create a new project using this template")
        .id(id)
        .accessibilityIdentifier(id)
    }
}

#if !DISABLE_PREVIEWS
#Preview {
    TemplateCard(name: "Mobile App", type: "Design", id: "mobile-app-template")
        .frame(width: 280)
        .padding()
}
#endif
