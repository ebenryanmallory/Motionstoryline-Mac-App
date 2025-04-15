import SwiftUI

// A reusable button for showing documentation
struct DocumentationButton: View {
    let documentationType: DocumentationService.DocumentationType
    let compact: Bool
    @EnvironmentObject private var appState: AppStateManager
    
    init(
        documentationType: DocumentationService.DocumentationType,
        compact: Bool = false
    ) {
        self.documentationType = documentationType
        self.compact = compact
    }
    
    var body: some View {
        Button(action: {
            appState.showDocumentation(documentationType)
        }) {
            if compact {
                // Just the icon
                Image(systemName: documentationType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            } else {
                // Icon and text
                Label(documentationType.title, systemImage: documentationType.iconName)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(.plain)
        .help(documentationType.helpText)
    }
} 